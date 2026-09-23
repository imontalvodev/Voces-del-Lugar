from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_DEV_SECRET = "dev-only-change-me"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    voces_env: str = "development"
    database_url: str = "postgresql+psycopg://voces:voces@localhost:5433/voces"
    jwt_secret: str = _DEV_SECRET
    jwt_ttl_days: int = 7
    media_root: Path = Path("./data/media")
    max_audio_bytes: int = 25 * 1024 * 1024
    cors_origins: str = "*"

    def check_production(self) -> None:
        if self.voces_env != "production":
            return
        if self.jwt_secret == _DEV_SECRET or len(self.jwt_secret) < 32:
            raise ValueError("El secreto JWT de producción no vale")
        origins = [item.strip() for item in self.cors_origins.split(",") if item.strip()]
        if not origins or "*" in origins:
            raise ValueError("CORS de producción no vale")


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    settings.check_production()
    return settings
