from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from voces.config import get_settings
from voces.routers import auth, geocode, media, stories

app = FastAPI(title="Voces del Lugar", version="0.1.0")
settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=[item.strip() for item in settings.cors_origins.split(",") if item.strip()],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router, prefix="/api/v1")
app.include_router(stories.router, prefix="/api/v1")
app.include_router(geocode.router, prefix="/api/v1")
app.include_router(media.router, prefix="/api/v1")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
