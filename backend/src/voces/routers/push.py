import ipaddress
import re
from typing import Annotated, Literal
from urllib.parse import urlsplit
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from voces.config import Settings, get_settings
from voces.db import get_session
from voces.deps import require_user
from voces.push import Dispatcher, Sender, public_key_b64

router = APIRouter(prefix="/push", tags=["push"])

MAX_PLACES = 20
_APNS_TOKEN = re.compile(r"[0-9a-fA-F]{64,200}")
_dispatcher: Dispatcher | None = None


def get_sender(settings: Annotated[Settings, Depends(get_settings)]) -> Sender:
    global _dispatcher
    if _dispatcher is None:
        _dispatcher = Dispatcher(settings)
    return _dispatcher


class DeviceIn(BaseModel):
    platform: Literal["webpush", "apns"]
    endpoint: str = Field(min_length=1, max_length=2048)
    p256dh: str | None = Field(default=None, max_length=200)
    auth: str | None = Field(default=None, max_length=100)


class PrefsOut(BaseModel):
    notify_own: bool
    notify_review: bool


class PrefsPatch(BaseModel):
    notify_own: bool | None = None
    notify_review: bool | None = None


class WatchedIn(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    radius_m: int = Field(default=2000, ge=200, le=20000)


class WatchedOut(BaseModel):
    id: UUID
    name: str
    latitude: float
    longitude: float
    radius_m: int


@router.get("/config")
def config(settings: Annotated[Settings, Depends(get_settings)]) -> dict:
    key = settings.vapid_private_key
    return {"vapid_public_key": public_key_b64(key) if key else None}


@router.put("/devices", status_code=status.HTTP_204_NO_CONTENT)
def add_device(
    payload: DeviceIn,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> Response:
    _check_device(payload)
    # Un dispositivo es de quien tiene la sesión abierta en él ahora.
    session.execute(
        text(
            """
            INSERT INTO push_devices (user_id, platform, endpoint, p256dh, auth)
            VALUES (:user_id, :platform, :endpoint, :p256dh, :auth)
            ON CONFLICT (endpoint) DO UPDATE
            SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform,
                p256dh = EXCLUDED.p256dh, auth = EXCLUDED.auth
            """
        ),
        {"user_id": user["id"], **payload.model_dump()},
    )
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/devices", status_code=status.HTTP_204_NO_CONTENT)
def remove_device(
    endpoint: str,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> Response:
    session.execute(
        text("DELETE FROM push_devices WHERE endpoint = :endpoint AND user_id = :user_id"),
        {"endpoint": endpoint, "user_id": user["id"]},
    )
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/prefs", response_model=PrefsOut)
def prefs(
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> PrefsOut:
    return _prefs(session, user["id"])


@router.patch("/prefs", response_model=PrefsOut)
def change_prefs(
    payload: PrefsPatch,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> PrefsOut:
    changes = {key: value for key, value in payload.model_dump().items() if value is not None}
    if changes:
        assignments = ", ".join(f"{column} = :{column}" for column in changes)
        session.execute(text(f"UPDATE users SET {assignments} WHERE id = :id"), {**changes, "id": user["id"]})
        session.commit()
    return _prefs(session, user["id"])


@router.get("/places", response_model=list[WatchedOut])
def places(
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> list[WatchedOut]:
    rows = session.execute(
        text(
            """
            SELECT id, name, radius_m,
                   ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude
            FROM watched_places WHERE user_id = :user_id
            ORDER BY created_at
            """
        ),
        {"user_id": user["id"]},
    ).mappings()
    return [WatchedOut(**row) for row in rows]


@router.post("/places", response_model=WatchedOut, status_code=status.HTTP_201_CREATED)
def watch_place(
    payload: WatchedIn,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> WatchedOut:
    count = session.execute(
        text("SELECT count(*) FROM watched_places WHERE user_id = :user_id"),
        {"user_id": user["id"]},
    ).scalar_one()
    if count >= MAX_PLACES:
        raise HTTPException(status.HTTP_409_CONFLICT, f"Puedes vigilar hasta {MAX_PLACES} sitios")
    watched_id = session.execute(
        text(
            """
            INSERT INTO watched_places (user_id, name, location, radius_m)
            VALUES (
                :user_id, :name,
                ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
                :radius_m
            )
            RETURNING id
            """
        ),
        {"user_id": user["id"], **payload.model_dump(), "name": payload.name.strip()},
    ).scalar_one()
    session.commit()
    return WatchedOut(id=watched_id, **payload.model_dump() | {"name": payload.name.strip()})


@router.delete("/places/{place_id}", status_code=status.HTTP_204_NO_CONTENT)
def unwatch_place(
    place_id: UUID,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> Response:
    deleted = session.execute(
        text("DELETE FROM watched_places WHERE id = :id AND user_id = :user_id"),
        {"id": place_id, "user_id": user["id"]},
    ).rowcount
    session.commit()
    if not deleted:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No está ese sitio")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _prefs(session: Session, user_id: UUID) -> PrefsOut:
    row = session.execute(
        text("SELECT notify_own, notify_review FROM users WHERE id = :id"),
        {"id": user_id},
    ).mappings().one()
    return PrefsOut(**row)


def _check_device(payload: DeviceIn) -> None:
    if payload.platform == "apns":
        if not _APNS_TOKEN.fullmatch(payload.endpoint):
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "El token de APNs no vale")
        return
    if not payload.p256dh or not payload.auth:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Faltan las claves del Web Push")
    # La API manda a esta URL: nada que no sea https público.
    parts = urlsplit(payload.endpoint)
    host = (parts.hostname or "").lower()
    if parts.scheme != "https" or not host or host == "localhost" or host.endswith(".localhost") or _private_ip(host):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "La dirección del aviso tiene que ser https pública")


def _private_ip(host: str) -> bool:
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return False
    return not address.is_global
