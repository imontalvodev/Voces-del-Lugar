from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_el_compose_publico_no_abre_la_base_ni_la_api():
    text = (ROOT / "docker-compose.prod.yml").read_text()
    assert "5432" not in text
    assert "8001" not in text
    assert "caddy" in text
    assert "VOCES_ENV" in text
    caddy = (ROOT / "deploy" / "Caddyfile").read_text()
    assert "reverse_proxy api:8000" in caddy
