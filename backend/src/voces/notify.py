"""Quién recibe cada aviso y con qué palabras.

Corre después de responder, con su propia sesión: si algo falla, la
historia ya está guardada.
"""

from uuid import UUID

from sqlalchemy import bindparam, text
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Session

from voces.db import session_scope
from voces.push import Sender
from voces.stories import fetch_story


def published(sender: Sender, story_id: UUID, *, by_moderator: bool) -> None:
    with session_scope() as session:
        story = fetch_story(session, story_id)
        if story is None or story["status"] != "published":
            return
        # Si se publicó sola, quien la escribió lo vio al guardarla.
        if by_moderator:
            own = _users(session, "id = :author AND notify_own", author=story["author_id"])
            _send(session, sender, own, _message(story, "published", "Tu historia ya está en el mapa", "se ha publicado."))
        watchers = session.execute(
            text(
                """
                SELECT DISTINCT ON (w.user_id) w.user_id, w.name
                FROM watched_places w
                JOIN places p ON p.id = :place_id
                WHERE w.user_id <> :author
                  AND ST_DWithin(w.location, p.location, w.radius_m)
                ORDER BY w.user_id, ST_Distance(w.location, p.location)
                """
            ),
            {"place_id": story["place_id"], "author": story["author_id"]},
        ).mappings()
        for watcher in list(watchers):
            message = _message(story, "nearby", f"Una historia nueva en {watcher['name']}", "")
            message["body"] = f"«{story['title']}», en {story['place_name']}."
            _send(session, sender, [watcher["user_id"]], message)


def rejected(sender: Sender, story_id: UUID) -> None:
    with session_scope() as session:
        story = fetch_story(session, story_id)
        if story is None:
            return
        own = _users(session, "id = :author AND notify_own", author=story["author_id"])
        message = _message(story, "rejected", "Tu historia no se ha publicado", "no ha pasado la revisión.")
        _send(session, sender, own, message)


def needs_review(sender: Sender, story_id: UUID) -> None:
    with session_scope() as session:
        story = fetch_story(session, story_id)
        if story is None or story["status"] != "pending_review":
            return
        moderators = _users(
            session,
            "role IN ('curator', 'admin') AND notify_review AND id <> :author",
            author=story["author_id"],
        )
        message = _message(story, "review", "Hay una historia por revisar", "")
        message["body"] = f"«{story['title']}», de {story['author_name']}."
        _send(session, sender, moderators, message)


def _message(story: dict, kind: str, title: str, tail: str) -> dict:
    return {"kind": kind, "story_id": str(story["id"]), "title": title, "body": f"«{story['title']}» {tail}"}


def _users(session: Session, where: str, **params) -> list[UUID]:
    return list(session.execute(text(f"SELECT id FROM users WHERE {where}"), params).scalars())


def _send(session: Session, sender: Sender, user_ids: list[UUID], message: dict) -> None:
    if not user_ids:
        return
    devices = session.execute(
        text(
            """
            SELECT id, platform, endpoint, p256dh, auth
            FROM push_devices WHERE user_id = ANY(:ids)
            ORDER BY created_at
            """
        ).bindparams(bindparam("ids", type_=ARRAY(PGUUID(as_uuid=True)))),
        {"ids": user_ids},
    ).mappings()
    gone = [device["id"] for device in list(devices) if not sender.send(dict(device), message)]
    if gone:
        session.execute(
            text("DELETE FROM push_devices WHERE id = ANY(:ids)").bindparams(
                bindparam("ids", type_=ARRAY(PGUUID(as_uuid=True)))
            ),
            {"ids": gone},
        )
        session.commit()
