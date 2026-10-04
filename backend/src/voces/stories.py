from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import bindparam, text
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Session

from voces.schemas import CATEGORIES, LICENSES, StoryIn, StoryOut, StoryPatch

STORY_COLUMNS = """
    s.id, s.title, s.body, s.transcript, s.narrator_name, s.narrator_relation,
    s.narrator_consent, s.narrator_deceased, s.consent_recorded_at,
    s.category, s.decade_approx, s.original_language, s.license, s.status,
    s.created_at, s.published_at, s.author_id,
    p.id AS place_id, p.name AS place_name, p.place_type, p.description AS place_description,
    ST_Y(p.location::geometry) AS latitude,
    ST_X(p.location::geometry) AS longitude
"""


def validate_story(payload: StoryIn) -> None:
    payload.place.check_type()
    if payload.category not in CATEGORIES:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Categoría no válida")
    if payload.license not in LICENSES:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Licencia no válida")
    if not payload.narrator_consent:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Hace falta el consentimiento del narrador o de su familia",
        )


def create_story(session: Session, author_id: UUID, payload: StoryIn) -> UUID:
    validate_story(payload)
    place = payload.place
    existing = session.execute(
        text(
            """
            SELECT id
            FROM places
            WHERE lower(btrim(name)) = lower(btrim(:name))
              AND ST_DWithin(
                    location,
                    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                    30
                  )
            LIMIT 1
            """
        ),
        {"name": place.name, "lng": place.longitude, "lat": place.latitude},
    ).scalar()
    if existing is not None:
        place_id = existing
    else:
        place_id = session.execute(
            text(
                """
                INSERT INTO places (name, place_type, description, location, created_by)
                VALUES (
                    :name, :place_type, :description,
                    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                    :created_by
                )
                RETURNING id
                """
            ),
            {
                "name": place.name.strip(),
                "place_type": place.place_type,
                "description": place.description,
                "lng": place.longitude,
                "lat": place.latitude,
                "created_by": author_id,
            },
        ).scalar_one()
    story_id = session.execute(
        text(
            """
            INSERT INTO stories (
                place_id, author_id, narrator_name, narrator_relation, title, body,
                transcript, narrator_consent, narrator_deceased, consent_recorded_at,
                category, decade_approx, original_language, license, status
            )
            VALUES (
                :place_id, :author_id, :narrator_name, :narrator_relation, :title, :body,
                :transcript, true, :narrator_deceased, now(),
                :category, :decade_approx, :original_language, :license, 'pending_review'
            )
            RETURNING id
            """
        ),
        {
            "place_id": place_id,
            "author_id": author_id,
            "narrator_name": payload.narrator_name,
            "narrator_relation": payload.narrator_relation,
            "title": payload.title,
            "body": _blank_to_none(payload.body),
            "transcript": _blank_to_none(payload.transcript),
            "narrator_deceased": payload.narrator_deceased,
            "category": payload.category,
            "decade_approx": payload.decade_approx,
            "original_language": payload.original_language,
            "license": payload.license,
        },
    ).scalar_one()
    session.commit()
    return story_id


def fetch_story(session: Session, story_id: UUID) -> dict | None:
    row = session.execute(
        text(
            f"""
            SELECT {STORY_COLUMNS}
            FROM stories s
            JOIN places p ON p.id = s.place_id
            WHERE s.id = :id
            """
        ),
        {"id": story_id},
    ).mappings().first()
    return dict(row) if row else None


def fetch_map(
    session: Session, west: float, south: float, east: float, north: float, limit: int = 200
) -> list[dict]:
    # Recuadro plano en grados: como geografía, uno de más de 180° de ancho
    # se interpreta por el otro lado del globo y no devuelve nada.
    rows = session.execute(
        text(
            f"""
            SELECT {STORY_COLUMNS}
            FROM stories s
            JOIN places p ON p.id = s.place_id
            WHERE s.status = 'published'
              AND ST_Intersects(
                    p.location::geometry,
                    ST_MakeEnvelope(:west, :south, :east, :north, 4326)
                  )
            ORDER BY s.published_at DESC
            LIMIT :limit
            """
        ),
        {
            "west": max(west, -180.0),
            "south": max(south, -90.0),
            "east": min(east, 180.0),
            "north": min(north, 90.0),
            "limit": limit,
        },
    ).mappings()
    return [dict(row) for row in rows]


def fetch_nearby(session: Session, lat: float, lng: float, radius_m: float) -> list[dict]:
    rows = session.execute(
        text(
            f"""
            SELECT {STORY_COLUMNS},
                   ST_Distance(p.location, ST_MakePoint(:lng, :lat)::geography) AS distance_m
            FROM stories s
            JOIN places p ON p.id = s.place_id
            WHERE s.status = 'published'
              AND ST_DWithin(p.location, ST_MakePoint(:lng, :lat)::geography, :radius)
            ORDER BY distance_m
            LIMIT 20
            """
        ),
        {"lat": lat, "lng": lng, "radius": radius_m},
    ).mappings()
    return [dict(row) for row in rows]


def fetch_mine(session: Session, author_id: UUID) -> list[dict]:
    rows = session.execute(
        text(
            f"""
            SELECT {STORY_COLUMNS}
            FROM stories s
            JOIN places p ON p.id = s.place_id
            WHERE s.author_id = :author_id
            ORDER BY s.created_at DESC
            """
        ),
        {"author_id": author_id},
    ).mappings()
    return [dict(row) for row in rows]


def update_story(session: Session, story_id: UUID, author_id: UUID, patch: StoryPatch) -> None:
    row = fetch_story(session, story_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No está esa historia")
    if row["author_id"] != author_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Solo quien la escribió puede corregirla")
    if row["status"] != "pending_review":
        raise HTTPException(status.HTTP_409_CONFLICT, "Solo se corrige una historia en revisión")
    changes = patch.model_dump(exclude_unset=True)
    if "title" in changes:
        title = _blank_to_none(changes["title"])
        if title is None:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "La historia necesita un título")
        changes["title"] = title
    for column in ("body", "narrator_name", "narrator_relation"):
        if column in changes:
            changes[column] = _blank_to_none(changes[column])
    if not changes:
        return
    assignments = ", ".join(f"{column} = :{column}" for column in changes)
    session.execute(
        text(f"UPDATE stories SET {assignments} WHERE id = :id"),
        {**changes, "id": story_id},
    )
    session.commit()


def fetch_review(session: Session) -> list[dict]:
    rows = session.execute(
        text(
            f"""
            SELECT {STORY_COLUMNS}
            FROM stories s
            JOIN places p ON p.id = s.place_id
            WHERE s.status = 'pending_review'
            ORDER BY s.created_at
            """
        )
    ).mappings()
    return [dict(row) for row in rows]


def media_for(session: Session, story_ids: list[UUID]) -> dict[UUID, list[dict]]:
    if not story_ids:
        return {}
    rows = session.execute(
        text(
            """
            SELECT id, story_id, media_type, duration_seconds, processing_status
            FROM media_assets
            WHERE story_id = ANY(:ids)
            ORDER BY created_at
            """
        ).bindparams(bindparam("ids", type_=ARRAY(PGUUID(as_uuid=True)))),
        {"ids": story_ids},
    ).mappings()
    grouped: dict[UUID, list[dict]] = {}
    for row in rows:
        grouped.setdefault(row["story_id"], []).append(dict(row))
    return grouped


def to_story(row: dict, media: list[dict]) -> StoryOut:
    return StoryOut(
        id=row["id"],
        title=row["title"],
        body=row["body"],
        transcript=row["transcript"],
        narrator_name=row["narrator_name"],
        narrator_relation=row["narrator_relation"],
        narrator_consent=row["narrator_consent"],
        narrator_deceased=row["narrator_deceased"],
        consent_recorded_at=row["consent_recorded_at"],
        category=row["category"],
        decade_approx=row["decade_approx"],
        original_language=row["original_language"],
        license=row["license"],
        status=row["status"],
        created_at=row["created_at"],
        published_at=row["published_at"],
        author_id=row["author_id"],
        place={
            "id": row["place_id"],
            "name": row["place_name"],
            "place_type": row["place_type"],
            "description": row["place_description"],
            "latitude": row["latitude"],
            "longitude": row["longitude"],
        },
        media=[
            {
                "id": item["id"],
                "media_type": item["media_type"],
                "duration_seconds": item["duration_seconds"],
                "processing_status": item["processing_status"],
                "url": f"/api/v1/media/{item['id']}",
            }
            for item in media
        ],
        distance_m=row.get("distance_m"),
    )


def stories_out(session: Session, rows: list[dict]) -> list[StoryOut]:
    grouped = media_for(session, [row["id"] for row in rows])
    return [to_story(row, grouped.get(row["id"], [])) for row in rows]


def can_read(row: dict, user: dict | None) -> bool:
    if row["status"] == "published":
        return True
    if user is None:
        return False
    return user["id"] == row["author_id"] or user["role"] in ("curator", "admin")


def assert_publishable(session: Session, row: dict) -> None:
    if row["status"] != "pending_review":
        raise HTTPException(status.HTTP_409_CONFLICT, "Solo se publica una historia en revisión")
    has_body = bool(row["body"] and row["body"].strip())
    has_audio = session.execute(
        text(
            """
            SELECT 1 FROM media_assets
            WHERE story_id = :id AND media_type = 'audio'
            """
        ),
        {"id": row["id"]},
    ).first()
    if not has_body and not has_audio:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Hace falta el texto de la historia o un audio",
        )


def _blank_to_none(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None
