from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import text
from sqlalchemy.orm import Session

from voces.config import Settings, get_settings
from voces.db import get_session
from voces.security import read_token

bearer = HTTPBearer(auto_error=False)


def current_user_id(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> UUID:
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Hace falta entrar")
    return read_token(credentials.credentials, settings)


def optional_user_id(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> UUID | None:
    if credentials is None:
        return None
    return read_token(credentials.credentials, settings)


def load_user(session: Session, user_id: UUID) -> dict:
    row = session.execute(
        text(
            """
            SELECT id, email, display_name, role, preferred_lang
            FROM users WHERE id = :id
            """
        ),
        {"id": user_id},
    ).mappings().first()
    if row is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "La cuenta ya no existe")
    return dict(row)


def require_user(
    session: Annotated[Session, Depends(get_session)],
    user_id: Annotated[UUID, Depends(current_user_id)],
) -> dict:
    return load_user(session, user_id)
