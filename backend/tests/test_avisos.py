import pytest
from fastapi.testclient import TestClient

from conftest import auth, register, story
from voces.config import Settings, get_settings
from voces.main import app
from voces.routers.push import get_sender

KEYS = {
    "p256dh": "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
    "auth": "BTBZMqHH6r4Tts7J_aSIgg",
}


class FakeSender:
    def __init__(self):
        self.sent: list[tuple[str, dict]] = []
        self.gone: set[str] = set()

    def send(self, device: dict, message: dict) -> bool:
        if device["endpoint"] in self.gone:
            return False
        self.sent.append((device["endpoint"], message))
        return True

    def to(self, endpoint: str) -> list[dict]:
        return [message for target, message in self.sent if target == endpoint]


@pytest.fixture
def sender():
    fake = FakeSender()
    app.dependency_overrides[get_sender] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_sender, None)


def _device(client: TestClient, token: str, name: str) -> str:
    endpoint = f"https://ntfy.example/up{name}?up=1"
    response = client.put(
        "/api/v1/push/devices",
        json={"platform": "webpush", "endpoint": endpoint, **KEYS},
        headers=auth(token),
    )
    assert response.status_code == 204, response.text
    return endpoint


def _story_at(title: str, lat: float, lng: float, body: str = "Aquí se juntaban al anochecer.") -> dict:
    payload = story(title)
    payload["body"] = body
    payload["place"].update(name=f"Sitio de {title}", latitude=lat, longitude=lng)
    return payload


@pytest.mark.parametrize(
    ("device", "detail"),
    [
        ({"platform": "webpush", "endpoint": "https://ntfy.example/up1"}, "claves"),
        ({"platform": "webpush", "endpoint": "http://ntfy.example/up1", **KEYS}, "https"),
        ({"platform": "webpush", "endpoint": "https://localhost/up1", **KEYS}, "https"),
        ({"platform": "webpush", "endpoint": "https://192.168.1.4/up1", **KEYS}, "https"),
        ({"platform": "apns", "endpoint": "no-es-un-token"}, "token"),
    ],
)
def test_un_dispositivo_mal_dado_no_se_guarda(client: TestClient, device, detail):
    token = register(client, "ana@example.com")
    response = client.put("/api/v1/push/devices", json=device, headers=auth(token))
    assert response.status_code == 422
    assert detail in response.json()["detail"]


def test_el_mismo_dispositivo_pasa_a_la_cuenta_que_entra(client: TestClient, sender: FakeSender):
    admin = register(client, "admin@example.com")
    ana = register(client, "ana@example.com")
    luis = register(client, "luis@example.com")
    endpoint = _device(client, ana, "movil")
    _device(client, luis, "movil")
    created = client.post("/api/v1/stories", json=story(), headers=auth(ana)).json()
    client.post(f"/api/v1/stories/{created['id']}/publish", headers=auth(admin))
    assert sender.to(endpoint) == []


def test_la_config_da_la_clave_publica(client: TestClient):
    assert client.get("/api/v1/push/config").json() == {"vapid_public_key": None}
    private = "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw"
    app.dependency_overrides[get_settings] = lambda: Settings(vapid_private_key=private)
    try:
        config = client.get("/api/v1/push/config").json()
    finally:
        app.dependency_overrides.pop(get_settings, None)
    assert config["vapid_public_key"].startswith("BP4z9KsN6nGRTbVYI")


def test_el_autor_sabe_cuando_se_publica_o_se_rechaza(client: TestClient, sender: FakeSender):
    admin = register(client, "admin@example.com")
    ana = register(client, "ana@example.com")
    endpoint = _device(client, ana, "ana")
    first = client.post("/api/v1/stories", json=story("La fuente"), headers=auth(ana)).json()
    second = client.post("/api/v1/stories", json=story("El cántaro"), headers=auth(ana)).json()

    client.post(f"/api/v1/stories/{first['id']}/publish", headers=auth(admin))
    client.post(f"/api/v1/stories/{second['id']}/reject", headers=auth(admin))
    assert sender.to(endpoint) == [
        {
            "kind": "published",
            "story_id": first["id"],
            "title": "Tu historia ya está en el mapa",
            "body": "«La fuente» se ha publicado.",
        },
        {
            "kind": "rejected",
            "story_id": second["id"],
            "title": "Tu historia no se ha publicado",
            "body": "«El cántaro» no ha pasado la revisión.",
        },
    ]


def test_quien_no_quiere_avisos_de_lo_suyo_no_los_recibe(client: TestClient, sender: FakeSender):
    admin = register(client, "admin@example.com")
    ana = register(client, "ana@example.com")
    endpoint = _device(client, ana, "ana")
    prefs = client.patch("/api/v1/push/prefs", json={"notify_own": False}, headers=auth(ana))
    assert prefs.json() == {"notify_own": False, "notify_review": True}
    assert client.get("/api/v1/push/prefs", headers=auth(ana)).json()["notify_own"] is False
    created = client.post("/api/v1/stories", json=story(), headers=auth(ana)).json()
    client.post(f"/api/v1/stories/{created['id']}/publish", headers=auth(admin))
    assert sender.to(endpoint) == []


def test_el_admin_sabe_que_hay_algo_por_revisar(auto_client: TestClient, sender: FakeSender):
    admin = register(auto_client, "admin@example.com")
    ana = register(auto_client, "ana@example.com", "Ana")
    admin_device = _device(auto_client, admin, "admin")
    ana_device = _device(auto_client, ana, "ana")

    auto_client.post("/api/v1/stories", json=story("Limpia"), headers=auth(ana))
    dudosa = story("Con enlace")
    dudosa["body"] = "Más en https://ejemplo.com"
    created = auto_client.post("/api/v1/stories", json=dudosa, headers=auth(ana)).json()
    assert sender.to(admin_device) == [
        {
            "kind": "review",
            "story_id": created["id"],
            "title": "Hay una historia por revisar",
            "body": "«Con enlace», de Ana.",
        }
    ]
    assert sender.to(ana_device) == []

    auto_client.patch("/api/v1/push/prefs", json={"notify_review": False}, headers=auth(admin))
    auto_client.post("/api/v1/stories", json=dudosa, headers=auth(ana))
    assert len(sender.to(admin_device)) == 1


def test_la_de_solo_audio_avisa_al_admin_cuando_llega_el_audio(client: TestClient, sender: FakeSender):
    admin = register(client, "admin@example.com")
    ana = register(client, "ana@example.com")
    admin_device = _device(client, admin, "admin")
    payload = story("Solo voz")
    payload["body"] = None
    created = client.post("/api/v1/stories", json=payload, headers=auth(ana)).json()
    assert sender.to(admin_device) == []
    client.post(
        f"/api/v1/stories/{created['id']}/audio",
        headers=auth(ana),
        files={"file": ("voz.m4a", b"....ftypM4A", "audio/mp4")},
    )
    assert [m["kind"] for m in sender.to(admin_device)] == ["review"]


def test_quien_vigila_un_sitio_sabe_de_lo_nuevo_cerca(auto_client: TestClient, sender: FakeSender):
    register(auto_client, "admin@example.com")
    ana = register(auto_client, "ana@example.com")
    luis = register(auto_client, "luis@example.com")
    ana_device = _device(auto_client, ana, "ana")
    luis_device = _device(auto_client, luis, "luis")
    for token in (ana, luis):
        watched = auto_client.post(
            "/api/v1/push/places",
            json={"name": "Mi pueblo", "latitude": 40.41, "longitude": -3.70, "radius_m": 2000},
            headers=auth(token),
        )
        assert watched.status_code == 201, watched.text

    near = auto_client.post("/api/v1/stories", json=_story_at("Cerca", 40.415, -3.70), headers=auth(ana)).json()
    auto_client.post("/api/v1/stories", json=_story_at("Lejos", 41.5, -2.0), headers=auth(ana))
    assert sender.to(luis_device) == [
        {
            "kind": "nearby",
            "story_id": near["id"],
            "title": "Una historia nueva en Mi pueblo",
            "body": "«Cerca», en Sitio de Cerca.",
        }
    ]
    assert sender.to(ana_device) == []


def test_los_sitios_vigilados_se_ven_y_se_quitan(client: TestClient):
    ana = register(client, "ana@example.com")
    luis = register(client, "luis@example.com")
    created = client.post(
        "/api/v1/push/places",
        json={"name": "Mi pueblo", "latitude": 40.41, "longitude": -3.70},
        headers=auth(ana),
    ).json()
    assert created["radius_m"] == 2000
    listed = client.get("/api/v1/push/places", headers=auth(ana)).json()
    assert [(p["name"], p["latitude"], p["longitude"]) for p in listed] == [("Mi pueblo", 40.41, -3.70)]
    assert client.delete(f"/api/v1/push/places/{created['id']}", headers=auth(luis)).status_code == 404
    assert client.delete(f"/api/v1/push/places/{created['id']}", headers=auth(ana)).status_code == 204
    assert client.get("/api/v1/push/places", headers=auth(ana)).json() == []


def test_el_dispositivo_que_ya_no_existe_se_olvida(client: TestClient, sender: FakeSender):
    admin = register(client, "admin@example.com")
    ana = register(client, "ana@example.com")
    endpoint = _device(client, ana, "vieja")
    sender.gone.add(endpoint)
    first = client.post("/api/v1/stories", json=story("Una"), headers=auth(ana)).json()
    client.post(f"/api/v1/stories/{first['id']}/publish", headers=auth(admin))
    sender.gone.clear()
    second = client.post("/api/v1/stories", json=story("Otra"), headers=auth(ana)).json()
    client.post(f"/api/v1/stories/{second['id']}/publish", headers=auth(admin))
    assert sender.to(endpoint) == []


def test_al_salir_se_quita_el_dispositivo(client: TestClient, sender: FakeSender):
    admin = register(client, "admin@example.com")
    ana = register(client, "ana@example.com")
    endpoint = _device(client, ana, "ana")
    removed = client.delete("/api/v1/push/devices", params={"endpoint": endpoint}, headers=auth(ana))
    assert removed.status_code == 204
    created = client.post("/api/v1/stories", json=story(), headers=auth(ana)).json()
    client.post(f"/api/v1/stories/{created['id']}/publish", headers=auth(admin))
    assert sender.to(endpoint) == []
