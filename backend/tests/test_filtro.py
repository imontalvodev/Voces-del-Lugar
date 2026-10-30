import pytest
from fastapi.testclient import TestClient

from conftest import auth, register, story
from voces.moderation import hold_reason, junk_reason


@pytest.mark.parametrize(
    ("title", "body", "fragment"),
    [
        ("x", "Aquí se juntaban al anochecer.", "título"),
        ("La fuente", "aaaaaaaaaaa", "historia"),
        ("La fuente", "sdfghjkl qwrtzx", "historia"),
        ("La fuente", "jajajajajajajajajajajajajajajajaja", "historia"),
        ("La fuente", "!!!! ???? 12345 ##### .... ;;;;", "historia"),
        ("Holaaaaaa", None, "título"),
    ],
)
def test_la_basura_obvia_no_pasa(title, body, fragment):
    assert fragment in junk_reason(title, body, "José")


@pytest.mark.parametrize(
    ("title", "body"),
    [
        ("La fuente", "Aquí se juntaban al anochecer."),
        ("Yo", None),
        ("El 18 de julio de 1936", "Mi abuela tenía 12 años. ¡Qué miedo pasó!"),
        ("La riada", "Llovió y llovió... El agua llegó hasta la tercera casa."),
        ("Ja, ja", "Se reía: jajaja, decía, ¡qué cosas!"),
    ],
)
def test_lo_normal_pasa(title, body):
    assert junk_reason(title, body, "José") is None
    assert hold_reason(title, body, "José") is None


@pytest.mark.parametrize(
    ("body", "reason"),
    [
        ("Más fotos en https://ejemplo.com/fotos", "link"),
        ("Pásate por www.tienda.es", "link"),
        ("Visita vocesbaratas.com ya", "link"),
        ("Escríbeme a ana@correo.es", "contact"),
        ("Llama al 600 123 456", "contact"),
        ("El alcalde era un gilipollas", "language"),
        ("Qué cabrón era el tío", "language"),
    ],
)
def test_lo_dudoso_se_queda_en_revision(body, reason):
    assert junk_reason("La fuente", body, None) is None
    assert hold_reason("La fuente", body, None) == reason


def test_las_palabras_dentro_de_otras_no_cuentan():
    assert hold_reason("La disputa", "Los computadores y el caputo de la sierra.", None) is None


def test_si_pasa_el_filtro_se_publica_sola(auto_client: TestClient):
    token = register(auto_client, "ana@example.com")
    created = auto_client.post("/api/v1/stories", json=story(), headers=auth(token))
    assert created.status_code == 201, created.text
    assert created.json()["status"] == "published"
    assert created.json()["published_at"] is not None
    assert created.json()["review_reason"] is None
    on_map = auto_client.get("/api/v1/stories/map", params={"west": -4, "south": 40, "east": -3, "north": 41})
    assert [item["title"] for item in on_map.json()] == ["La esquina"]


def test_la_basura_se_rechaza_al_guardar(auto_client: TestClient):
    token = register(auto_client, "ana@example.com")
    payload = story()
    payload["body"] = "asdasdasdasdasdasdasdasdasdasd"
    created = auto_client.post("/api/v1/stories", json=payload, headers=auth(token))
    assert created.status_code == 422
    assert created.json()["detail"] == "La historia no se entiende. Revisa el texto antes de guardarla."


def test_lo_dudoso_espera_al_admin_y_dice_por_que(auto_client: TestClient):
    admin = register(auto_client, "admin@example.com")
    token = register(auto_client, "ana@example.com")
    payload = story()
    payload["body"] = "Más en https://ejemplo.com"
    created = auto_client.post("/api/v1/stories", json=payload, headers=auth(token))
    assert created.json()["status"] == "pending_review"
    assert created.json()["review_reason"] == "link"
    queue = auto_client.get("/api/v1/stories/review", headers=auth(admin)).json()
    assert [(item["id"], item["review_reason"]) for item in queue] == [(created.json()["id"], "link")]

    published = auto_client.post(f"/api/v1/stories/{created.json()['id']}/publish", headers=auth(admin))
    assert published.json()["status"] == "published"
    assert published.json()["review_reason"] is None


def test_la_de_solo_audio_se_publica_cuando_llega_el_audio(auto_client: TestClient):
    admin = register(auto_client, "admin@example.com")
    token = register(auto_client, "ana@example.com")
    payload = story()
    payload["body"] = ""
    created = auto_client.post("/api/v1/stories", json=payload, headers=auth(token)).json()
    assert created["status"] == "pending_review"
    assert created["review_reason"] == "awaiting_media"
    assert auto_client.get("/api/v1/stories/review", headers=auth(admin)).json() == []

    audio = auto_client.post(
        f"/api/v1/stories/{created['id']}/audio",
        headers=auth(token),
        files={"file": ("voz.m4a", b"....ftypM4A", "audio/mp4")},
    )
    assert audio.status_code == 201, audio.text
    assert audio.json()["status"] == "published"
    assert audio.json()["review_reason"] is None


def test_sin_publicacion_automatica_el_audio_la_deja_lista_para_revisar(client: TestClient):
    admin = register(client, "admin@example.com")
    token = register(client, "ana@example.com")
    payload = story()
    payload["body"] = None
    created = client.post("/api/v1/stories", json=payload, headers=auth(token)).json()
    client.post(
        f"/api/v1/stories/{created['id']}/audio",
        headers=auth(token),
        files={"file": ("voz.m4a", b"....ftypM4A", "audio/mp4")},
    )
    queue = client.get("/api/v1/stories/review", headers=auth(admin)).json()
    assert [(item["id"], item["review_reason"]) for item in queue] == [(created["id"], None)]


def test_el_audio_de_una_escrita_ya_publicada_se_puede_anadir(auto_client: TestClient):
    token = register(auto_client, "ana@example.com")
    created = auto_client.post("/api/v1/stories", json=story(), headers=auth(token)).json()
    assert created["status"] == "published"
    first = auto_client.post(
        f"/api/v1/stories/{created['id']}/audio",
        headers=auth(token),
        files={"file": ("voz.m4a", b"....ftypM4A", "audio/mp4")},
    )
    assert first.status_code == 201, first.text
    second = auto_client.post(
        f"/api/v1/stories/{created['id']}/audio",
        headers=auth(token),
        files={"file": ("otra.m4a", b"....ftypM4A", "audio/mp4")},
    )
    assert second.status_code == 409


def test_muchas_seguidas_esperan_al_admin(auto_client: TestClient):
    token = register(auto_client, "ana@example.com")
    statuses = [
        auto_client.post("/api/v1/stories", json=story(f"Historia {n}"), headers=auth(token)).json()
        for n in ("una", "dos", "tres", "cuatro", "cinco", "seis")
    ]
    assert [s["status"] for s in statuses[:5]] == ["published"] * 5
    assert (statuses[5]["status"], statuses[5]["review_reason"]) == ("pending_review", "many")


def test_corregir_con_basura_no_se_deja(client: TestClient):
    token = register(client, "ana@example.com")
    created = client.post("/api/v1/stories", json=story(), headers=auth(token)).json()
    patched = client.patch(
        f"/api/v1/stories/{created['id']}",
        json={"title": "zzzzzzzz"},
        headers=auth(token),
    )
    assert patched.status_code == 422
    assert "título" in patched.json()["detail"]


def test_retirar_la_marca_como_retirada(client: TestClient):
    admin = register(client, "admin@example.com")
    created = client.post("/api/v1/stories", json=story(), headers=auth(admin)).json()
    client.post(f"/api/v1/stories/{created['id']}/publish", headers=auth(admin))
    withdrawn = client.post(f"/api/v1/stories/{created['id']}/unpublish", headers=auth(admin)).json()
    assert withdrawn["review_reason"] == "unpublished"
