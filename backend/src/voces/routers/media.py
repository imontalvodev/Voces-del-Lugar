from pathlib import Path
from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from voces.config import Settings, get_settings
from voces.db import get_session
from voces.deps import load_user, optional_user_id, require_user
from voces.stories import can_read, fetch_story, media_for, to_story

router = APIRouter(tags=["media"])

AUDIO_TYPES = {
    "audio/mpeg",
    "audio/mp4",
    "audio/aac",
    "audio/wav",
    "audio/x-wav",
    "audio/webm",
    "audio/ogg",
    "application/octet-stream",
}


@router.post("/stories/{story_id}/audio", status_code=status.HTTP_201_CREATED)
def upload_audio(
    story_id: UUID,
    file: UploadFile,
    user: Annotated[dict, Depends(require_user)],
    session: Annotated[Session, Depends(get_session)],
    settings: Annotated[Settings, Depends(get_settings)],
):
    row = fetch_story(session, story_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No está esa historia")
    if row["author_id"] != user["id"]:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Solo quien subió la historia puede añadir el audio")
    if row["status"] not in ("draft", "pending_review"):
        raise HTTPException(status.HTTP_409_CONFLICT, "Esta historia ya no admite audio")
    content_type = (file.content_type or "").split(";")[0].strip().lower()
    if content_type not in AUDIO_TYPES:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "El archivo tiene que ser un audio")
    payload = file.file.read(settings.max_audio_bytes + 1)
    if not payload:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "El audio está vacío")
    if len(payload) > settings.max_audio_bytes:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "El audio pasa de 25 MB")

    media_id = uuid4()
    suffix = _suffix(file.filename, content_type)
    storage_key = f"{story_id}/{media_id}{suffix}"
    destination = Path(settings.media_root) / storage_key
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    session.execute(
        text(
            """
            INSERT INTO media_assets (id, story_id, media_type, storage_key, processing_status)
            VALUES (:id, :story_id, 'audio', :storage_key, 'done')
            """
        ),
        {"id": media_id, "story_id": story_id, "storage_key": storage_key},
    )
    session.commit()
    return to_story(fetch_story(session, story_id), media_for(session, [story_id]).get(story_id, []))


@router.get("/media/{media_id}")
def download(
    media_id: UUID,
    session: Annotated[Session, Depends(get_session)],
    settings: Annotated[Settings, Depends(get_settings)],
    user_id: Annotated[UUID | None, Depends(optional_user_id)],
):
    asset = session.execute(
        text(
            """
            SELECT id, story_id, storage_key
            FROM media_assets WHERE id = :id
            """
        ),
        {"id": media_id},
    ).mappings().first()
    if asset is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No está ese archivo")
    story = fetch_story(session, asset["story_id"])
    user = load_user(session, user_id) if user_id else None
    if story is None or not can_read(story, user):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No está ese archivo")
    path = Path(settings.media_root) / asset["storage_key"]
    if not path.is_file():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "El archivo no está en el disco")
    return FileResponse(path)


def _suffix(filename: str | None, content_type: str) -> str:
    if filename and "." in filename:
        ext = filename.rsplit(".", 1)[-1].lower()
        if ext in {"mp3", "m4a", "aac", "wav", "webm", "ogg", "mp4"}:
            return f".{ext}"
    return {
        "audio/mpeg": ".mp3",
        "audio/mp4": ".m4a",
        "audio/aac": ".aac",
        "audio/wav": ".wav",
        "audio/x-wav": ".wav",
        "audio/webm": ".webm",
        "audio/ogg": ".ogg",
    }.get(content_type, ".bin")
