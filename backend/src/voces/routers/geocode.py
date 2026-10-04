import httpx
from fastapi import APIRouter, HTTPException, status

from voces.geocode import search_places
from voces.schemas import PlaceHit

router = APIRouter(prefix="/geocode", tags=["geocode"])


@router.get("", response_model=list[PlaceHit])
def geocode(q: str) -> list[PlaceHit]:
    try:
        with httpx.Client(timeout=5.0) as client:
            return search_places(q, client)
    except ValueError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(exc)) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "No se ha podido buscar el lugar") from exc
