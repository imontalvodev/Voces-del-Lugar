import os

from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text

from conftest import ROOT, register as _register, story as _story


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


def test_solo_un_moderador_lista_la_revision(client: TestClient):
    admin = _register(client, "ana@example.com")
    other = _register(client, "luis@example.com")
    headers = {"Authorization": f"Bearer {other}"}
    created = client.post("/api/v1/stories", json=_story("En cola"), headers=headers)
    assert created.status_code == 201

    forbidden = client.get("/api/v1/stories/review", headers=headers)
    assert forbidden.status_code == 403

    queue = client.get("/api/v1/stories/review", headers={"Authorization": f"Bearer {admin}"})
    assert queue.status_code == 200
    assert [item["title"] for item in queue.json()] == ["En cola"]
    assert queue.json()[0]["status"] == "pending_review"


def test_el_autor_corrige_solo_mientras_esta_en_revision(client: TestClient):
    token = _register(client, "ana@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    created = client.post("/api/v1/stories", json=_story(), headers=headers)
    story_id = created.json()["id"]

    patched = client.patch(
        f"/api/v1/stories/{story_id}",
        json={"title": "La fuente", "body": "Iban a por agua."},
        headers=headers,
    )
    assert patched.status_code == 200, patched.text
    assert patched.json()["title"] == "La fuente"
    assert patched.json()["body"] == "Iban a por agua."

    client.post(f"/api/v1/stories/{story_id}/publish", headers=headers)
    locked = client.patch(
        f"/api/v1/stories/{story_id}",
        json={"title": "Otro"},
        headers=headers,
    )
    assert locked.status_code == 409
    assert locked.json()["detail"] == "Solo se corrige una historia en revisión"


def test_retirar_esconde_la_historia_del_mapa(client: TestClient):
    admin = _register(client, "ana@example.com")
    other = _register(client, "luis@example.com")
    admin_headers = {"Authorization": f"Bearer {admin}"}
    created = client.post("/api/v1/stories", json=_story(), headers=admin_headers)
    story_id = created.json()["id"]
    client.post(f"/api/v1/stories/{story_id}/publish", headers=admin_headers)

    forbidden = client.post(
        f"/api/v1/stories/{story_id}/unpublish",
        headers={"Authorization": f"Bearer {other}"},
    )
    assert forbidden.status_code == 403

    withdrawn = client.post(f"/api/v1/stories/{story_id}/unpublish", headers=admin_headers)
    assert withdrawn.status_code == 200, withdrawn.text
    assert withdrawn.json()["status"] == "pending_review"
    assert withdrawn.json()["published_at"] is None

    on_map = client.get("/api/v1/stories/map", params={"west": -4, "south": 40, "east": -3, "north": 41})
    assert on_map.json() == []


def test_el_mismo_sitio_no_crea_otro_lugar(client: TestClient):
    token = _register(client, "ana@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    first = client.post("/api/v1/stories", json=_story("La fuente"), headers=headers)
    second_payload = _story("El cántaro")
    second_payload["place"]["name"] = "  esquina de la plaza "
    second = client.post("/api/v1/stories", json=second_payload, headers=headers)
    assert first.json()["place"]["id"] == second.json()["place"]["id"]

    other = _story("Otra esquina")
    other["place"]["name"] = "El lavadero"
    third = client.post("/api/v1/stories", json=other, headers=headers)
    assert third.json()["place"]["id"] != first.json()["place"]["id"]


def test_cada_historia_nueva_recibe_el_siguiente_numero(client: TestClient):
    token = _register(client, "ana@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    first = client.post("/api/v1/stories", json=_story("La fuente"), headers=headers).json()
    second = client.post("/api/v1/stories", json=_story("El cántaro"), headers=headers).json()
    assert second["number"] == first["number"] + 1

    client.post(f"/api/v1/stories/{first['id']}/publish", headers=headers)
    detail = client.get(f"/api/v1/stories/{first['id']}").json()
    mine = client.get("/api/v1/stories/mine", headers=headers).json()
    review = client.get("/api/v1/stories/review", headers=headers).json()
    on_map = client.get("/api/v1/stories/map", params={"west": -4, "south": 40, "east": -3, "north": 41}).json()
    assert detail["number"] == first["number"]
    assert {item["title"]: item["number"] for item in mine} == {
        "La fuente": first["number"],
        "El cántaro": second["number"],
    }
    assert [item["number"] for item in review] == [second["number"]]
    assert [item["number"] for item in on_map] == [first["number"]]


def test_la_migracion_numera_las_historias_por_antiguedad(client: TestClient):
    token = _register(client, "ana@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    ids = [
        client.post("/api/v1/stories", json=_story(title), headers=headers).json()["id"]
        for title in ("Tercera", "Primera", "Segunda")
    ]
    config = Config(str(ROOT / "alembic.ini"))
    command.downgrade(config, "001")
    engine = create_engine(os.environ["DATABASE_URL"])
    try:
        with engine.begin() as conn:
            for days, story_id in zip((1, 3, 2), ids):
                conn.execute(
                    text("UPDATE stories SET created_at = now() - make_interval(days => :days) WHERE id = :id"),
                    {"days": days, "id": story_id},
                )
    finally:
        engine.dispose()
        command.upgrade(config, "head")

    numbers = {
        item["title"]: item["number"]
        for item in client.get("/api/v1/stories/mine", headers=headers).json()
    }
    assert numbers == {"Primera": 1, "Segunda": 2, "Tercera": 3}
    nueva = client.post("/api/v1/stories", json=_story("Cuarta"), headers=headers).json()
    assert nueva["number"] == 4


def test_la_historia_dice_quien_la_recogio(client: TestClient):
    admin = _register(client, "lucia@example.com", "Lucía Ortega")
    other = _register(client, "luis@example.com", "Luis")
    admin_headers = {"Authorization": f"Bearer {admin}"}
    other_headers = {"Authorization": f"Bearer {other}"}
    published = client.post("/api/v1/stories", json=_story("La fuente"), headers=admin_headers).json()
    pending = client.post("/api/v1/stories", json=_story("El cántaro"), headers=other_headers).json()
    assert published["author_name"] == "Lucía Ortega"
    client.post(f"/api/v1/stories/{published['id']}/publish", headers=admin_headers)

    detail = client.get(f"/api/v1/stories/{published['id']}").json()
    mine = client.get("/api/v1/stories/mine", headers=other_headers).json()
    review = client.get("/api/v1/stories/review", headers=admin_headers).json()
    on_map = client.get("/api/v1/stories/map", params={"west": -4, "south": 40, "east": -3, "north": 41}).json()
    assert detail["author_name"] == "Lucía Ortega"
    assert detail["author_id"] == published["author_id"]
    assert [item["author_name"] for item in mine] == ["Luis"]
    assert [(item["id"], item["author_name"]) for item in review] == [(pending["id"], "Luis")]
    assert [item["author_name"] for item in on_map] == ["Lucía Ortega"]


def test_el_mapa_del_mundo_entero_ve_las_historias(client: TestClient):
    token = _register(client, "ana@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    story_id = client.post("/api/v1/stories", json=_story(), headers=headers).json()["id"]
    client.post(f"/api/v1/stories/{story_id}/publish", headers=headers)

    for box in ("west=-180&south=-85&east=180&north=85", "west=-400&south=-95&east=400&north=95"):
        response = client.get(f"/api/v1/stories/map?{box}")
        assert response.status_code == 200, response.text
        assert [s["id"] for s in response.json()] == [story_id]
