from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from voces.config import Settings, get_settings
from voces.db import get_session
from voces.deps import require_user
from voces.schemas import LoginIn, RegisterIn, TokenOut, UserOut
from voces.security import hash_password, make_token, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(
    payload: RegisterIn,
    session: Annotated[Session, Depends(get_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenOut:
    email = payload.email.lower()
    exists = session.execute(
        text("SELECT 1 FROM users WHERE email = :email"),
        {"email": email},
    ).first()
    if exists:
        raise HTTPException(status.HTTP_409_CONFLICT, "Ese email ya tiene cuenta")
    users = session.execute(text("SELECT count(*) FROM users")).scalar_one()
    role = "admin" if users == 0 else "contributor"
    user_id = session.execute(
        text(
            """
            INSERT INTO users (email, password_hash, display_name, role)
            VALUES (:email, :password_hash, :display_name, :role)
            RETURNING id
            """
        ),
        {
            "email": email,
            "password_hash": hash_password(payload.password),
            "display_name": payload.display_name.strip(),
            "role": role,
        },
    ).scalar_one()
    session.commit()
    return TokenOut(access_token=make_token(user_id, settings))


@router.post("/login", response_model=TokenOut)
def login(
    payload: LoginIn,
    session: Annotated[Session, Depends(get_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenOut:
    row = session.execute(
        text("SELECT id, password_hash FROM users WHERE email = :email"),
        {"email": payload.email.lower()},
    ).mappings().first()
    if row is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "No hay ninguna cuenta con ese email")
    if not verify_password(payload.password, row["password_hash"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "La contraseña no coincide")
    return TokenOut(access_token=make_token(row["id"], settings))


@router.get("/me", response_model=UserOut)
def me(user: Annotated[dict, Depends(require_user)]) -> UserOut:
    return UserOut(**user)
