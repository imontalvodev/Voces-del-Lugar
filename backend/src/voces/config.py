from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://voces:voces@localhost:5433/voces"
    jwt_secret: str = "dev-only-change-me"
    jwt_ttl_days: int = 7
    media_root: Path = Path("./data/media")
    max_audio_bytes: int = 25 * 1024 * 1024


@lru_cache
def get_settings() -> Settings:
    return Settings()
