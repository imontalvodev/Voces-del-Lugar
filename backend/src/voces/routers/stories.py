from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from voces.db import get_session
from voces.deps import optional_user_id, require_user
from voces.deps import load_user
from voces.schemas import StoryIn, StoryOut
from voces.stories import (
    assert_publishable,
    can_read,
    create_story,
    fetch_map,
    fetch_mine,
    fetch_nearby,
    fetch_story,
    stories_out,
    to_story,
    media_for,
)

router = APIRouter(prefix="/stories", tags=["stories"])


@router.get("/map", response_model=list[StoryOut])
def map_stories(
    west: float,
    south: float,
    east: float,
    north: float,
    session: Annotated[Session, Depends(get_session)],
) -> list[StoryOut]:
    if west >= east or south >= north:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "El recuadro no es válido")
    return stories_out(session, fetch_map(session, west, south, east, north))


@router.get("/nearby", response_model=list[StoryOut])
def nearby_stories(
    lat: float,
    lng: float,
    session: Annotated[Session, Depends(get_session)],
    radius_m: float = 5000,
) -> list[StoryOut]:
    if not -90 <= lat <= 90 or not -180 <= lng <= 180:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Coordenadas no válidas")
    if not 1 <= radius_m <= 50000:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "El radio tiene que estar entre 1 y 50000 m")
    return stories_out(session, fetch_nearby(session, lat, lng, radius_m))


@router.get("/mine", response_model=list[StoryOut])
def mine(
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> list[StoryOut]:
    return stories_out(session, fetch_mine(session, user["id"]))


@router.get("/{story_id}", response_model=StoryOut)
def detail(
    story_id: UUID,
    session: Annotated[Session, Depends(get_session)],
    user_id: Annotated[UUID | None, Depends(optional_user_id)],
) -> StoryOut:
    row = fetch_story(session, story_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No está esa historia")
    user = load_user(session, user_id) if user_id else None
    if not can_read(row, user):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No está esa historia")
    return to_story(row, media_for(session, [row["id"]]).get(row["id"], []))


@router.post("", response_model=StoryOut, status_code=status.HTTP_201_CREATED)
def create(
    payload: StoryIn,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> StoryOut:
    story_id = create_story(session, user["id"], payload)
    row = fetch_story(session, story_id)
    return to_story(row, [])


@router.post("/{story_id}/publish", response_model=StoryOut)
def publish(
    story_id: UUID,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> StoryOut:
    _require_moderator(user)
    row = _require_story(session, story_id)
    assert_publishable(session, row)
    session.execute(
        text(
            """
            UPDATE stories
            SET status = 'published', published_at = now()
            WHERE id = :id
            """
        ),
        {"id": story_id},
    )
    session.commit()
    return to_story(fetch_story(session, story_id), media_for(session, [story_id]).get(story_id, []))


@router.post("/{story_id}/reject", response_model=StoryOut)
def reject(
    story_id: UUID,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
) -> StoryOut:
    _require_moderator(user)
    row = _require_story(session, story_id)
    if row["status"] != "pending_review":
        raise HTTPException(status.HTTP_409_CONFLICT, "Solo se rechaza una historia en revisión")
    session.execute(
        text("UPDATE stories SET status = 'rejected' WHERE id = :id"),
        {"id": story_id},
    )
    session.commit()
    return to_story(fetch_story(session, story_id), media_for(session, [story_id]).get(story_id, []))


def _require_moderator(user: dict) -> None:
    if user["role"] not in ("curator", "admin"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Solo un moderador puede publicar o rechazar")


def _require_story(session: Session, story_id: UUID) -> dict:
    row = fetch_story(session, story_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No está esa historia")
    return row
