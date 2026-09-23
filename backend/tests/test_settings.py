import pytest

from voces.config import get_settings


def test_produccion_rechaza_el_secreto_de_desarrollo(monkeypatch):
    monkeypatch.setenv("VOCES_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "dev-only-change-me")
    monkeypatch.setenv("CORS_ORIGINS", "https://voces.example")
    get_settings.cache_clear()
    with pytest.raises(ValueError, match="secreto JWT"):
        get_settings()
    get_settings.cache_clear()


def test_produccion_rechaza_cors_abierto(monkeypatch):
    monkeypatch.setenv("VOCES_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "x" * 32)
    monkeypatch.setenv("CORS_ORIGINS", "*")
    get_settings.cache_clear()
    with pytest.raises(ValueError, match="CORS"):
        get_settings()
    get_settings.cache_clear()
