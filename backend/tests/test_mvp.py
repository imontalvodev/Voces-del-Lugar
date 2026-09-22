import os

os.environ["DATABASE_URL"] = "postgresql+psycopg://voces:voces@localhost:5433/voces_test"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["MEDIA_ROOT"] = "/tmp/voces-test-media"

from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text

from voces.config import get_settings
from voces.db import reset_engine
from voces.main import app

ROOT = Path(__file__).resolve().parents[1]


def _prepare_database() -> None:
    admin = create_engine(
        "postgresql+psycopg://voces:voces@localhost:5433/postgres",
        isolation_level="AUTOCOMMIT",
    )
    with admin.connect() as conn:
        exists = conn.execute(text("SELECT 1 FROM pg_database WHERE datname = 'voces_test'")).scalar()
        if not exists:
            conn.execute(text("CREATE DATABASE voces_test"))
    admin.dispose()
    get_settings.cache_clear()
    reset_engine()
    command.upgrade(Config(str(ROOT / "alembic.ini")), "head")


@pytest.fixture(scope="session", autouse=True)
def database():
    try:
        _prepare_database()
    except Exception as exc:
        pytest.skip(f"Postgres no está disponible: {exc}")
    yield


@pytest.fixture(autouse=True)
def clean_rows():
    yield
    engine = create_engine(os.environ["DATABASE_URL"])
    with engine.begin() as conn:
        conn.execute(
            text(
                "TRUNCATE story_tags, tags, media_assets, stories, places, users RESTART IDENTITY CASCADE"
            )
        )
    engine.dispose()


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def _register(client: TestClient, email: str, name: str = "Ana") -> str:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "una-clave-larga", "display_name": name},
    )
    assert response.status_code == 201, response.text
    return response.json()["access_token"]


def _story(title: str = "La esquina") -> dict:
    return {
        "title": title,
        "body": "Aquí se juntaban al anochecer.",
        "narrator_name": "José",
        "narrator_relation": "abuelo",
        "narrator_consent": True,
        "narrator_deceased": True,
        "license": "CC-BY-SA-4.0",
        "category": "anecdota",
        "place": {
            "name": "Esquina de la plaza",
            "place_type": "barrio",
            "latitude": 40.41,
            "longitude": -3.70,
        },
    }


def test_primera_cuenta_es_admin_y_la_segunda_no(client: TestClient):
    admin = _register(client, "ana@example.com", "Ana")
    other = _register(client, "luis@example.com", "Luis")
    admin_me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {admin}"})
    other_me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {other}"})
    assert admin_me.json()["role"] == "admin"
    assert other_me.json()["role"] == "contributor"


def test_sin_consentimiento_no_se_crea(client: TestClient):
    token = _register(client, "ana@example.com")
    payload = _story()
    payload["narrator_consent"] = False
    response = client.post(
        "/api/v1/stories",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


def test_licencia_no_abierta_se_rechaza(client: TestClient):
    token = _register(client, "ana@example.com")
    payload = _story()
    payload["license"] = "CC-BY-NC-SA-4.0"
    response = client.post(
        "/api/v1/stories",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


def test_historia_en_el_mapa_tras_publicar_y_audio(client: TestClient):
    token = _register(client, "ana@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    created = client.post("/api/v1/stories", json=_story(), headers=headers)
    assert created.status_code == 201, created.text
    story = created.json()
    assert story["status"] == "pending_review"
    assert story["narrator_deceased"] is True
    assert story["license"] == "CC-BY-SA-4.0"

    hidden = client.get("/api/v1/stories/map", params={"west": -4, "south": 40, "east": -3, "north": 41})
    assert hidden.json() == []

    audio = client.post(
        f"/api/v1/stories/{story['id']}/audio",
        headers=headers,
        files={"file": ("voz.wav", b"RIFF....WAVE", "audio/wav")},
    )
    assert audio.status_code == 201, audio.text
    assert audio.json()["media"][0]["processing_status"] == "done"

    published = client.post(f"/api/v1/stories/{story['id']}/publish", headers=headers)
    assert published.status_code == 200, published.text
    assert published.json()["status"] == "published"

    on_map = client.get("/api/v1/stories/map", params={"west": -4, "south": 40, "east": -3, "north": 41})
    assert [item["title"] for item in on_map.json()] == ["La esquina"]

    nearby = client.get("/api/v1/stories/nearby", params={"lat": 40.41, "lng": -3.70, "radius_m": 5000})
    assert nearby.json()[0]["distance_m"] < 50

    media_id = published.json()["media"][0]["id"]
    downloaded = client.get(f"/api/v1/media/{media_id}")
    assert downloaded.status_code == 200
    assert downloaded.content.startswith(b"RIFF")


def test_un_contribuidor_no_publica(client: TestClient):
    _register(client, "ana@example.com")
    token = _register(client, "luis@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    created = client.post("/api/v1/stories", json=_story("Otra"), headers=headers)
    story_id = created.json()["id"]
    response = client.post(f"/api/v1/stories/{story_id}/publish", headers=headers)
    assert response.status_code == 403
