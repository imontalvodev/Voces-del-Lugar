from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


LICENSES = ("CC-BY-SA-4.0", "CC-BY-4.0", "CC0-1.0")
CATEGORIES = ("anecdota", "leyenda", "oficio", "tradicion", "evento", "otro")
PLACE_TYPES = ("barrio", "pueblo", "edificio", "paraje", "otro")


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    display_name: str = Field(min_length=1, max_length=80)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: UUID
    email: EmailStr
    display_name: str
    role: str
    preferred_lang: str


class PlaceIn(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    place_type: str = Field(default="otro")
    description: str | None = None
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)

    def check_type(self) -> None:
        if self.place_type not in PLACE_TYPES:
            raise ValueError("tipo de lugar no válido")


class StoryIn(BaseModel):
    title: str = Field(min_length=1, max_length=180)
    body: str | None = None
    transcript: str | None = None
    narrator_name: str | None = Field(default=None, max_length=160)
    narrator_relation: str | None = Field(default=None, max_length=80)
    narrator_consent: bool
    narrator_deceased: bool = False
    category: str = "anecdota"
    decade_approx: int | None = Field(default=None, ge=1800, le=2100)
    original_language: str = "es"
    license: str = "CC-BY-SA-4.0"
    place: PlaceIn


class PlaceOut(BaseModel):
    id: UUID
    name: str
    place_type: str
    description: str | None
    latitude: float
    longitude: float


class MediaOut(BaseModel):
    id: UUID
    media_type: str
    duration_seconds: int | None
    processing_status: str
    url: str


class StoryOut(BaseModel):
    id: UUID
    title: str
    body: str | None
    transcript: str | None
    narrator_name: str | None
    narrator_relation: str | None
    narrator_consent: bool
    narrator_deceased: bool
    consent_recorded_at: datetime | None
    category: str
    decade_approx: int | None
    original_language: str
    license: str
    status: str
    created_at: datetime
    published_at: datetime | None
    author_id: UUID
    place: PlaceOut
    media: list[MediaOut]
    distance_m: float | None = None
