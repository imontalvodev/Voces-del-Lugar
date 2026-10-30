import os

os.environ["DATABASE_URL"] = "postgresql+psycopg://voces:voces@localhost:5433/voces_test"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["MEDIA_ROOT"] = "/tmp/voces-test-media"
# Las pruebas de siempre miran la cola a mano; las del filtro la encienden.
os.environ["AUTO_PUBLISH"] = "false"

from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text

from voces.config import Settings, get_settings
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


@pytest.fixture
def auto_client():
    """Cliente con la publicación automática encendida, como en producción."""
    app.dependency_overrides[get_settings] = lambda: Settings(auto_publish=True)
    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.pop(get_settings, None)


def register(client: TestClient, email: str, name: str = "Ana") -> str:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "una-clave-larga", "display_name": name},
    )
    assert response.status_code == 201, response.text
    return response.json()["access_token"]


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def story(title: str = "La esquina") -> dict:
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
