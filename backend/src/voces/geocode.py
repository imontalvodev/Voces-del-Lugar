import httpx

from voces.schemas import PlaceHit

_NOMINATIM = "https://nominatim.openstreetmap.org/search"
_USER_AGENT = "VocesDelLugar/0.1 (https://github.com/imontalvodev/Voces-del-Lugar)"


def search_places(query: str, client: httpx.Client) -> list[PlaceHit]:
    text = query.strip()
    if len(text) < 2:
        raise ValueError("Escribe al menos dos letras")
    response = client.get(
        _NOMINATIM,
        params={"q": text, "format": "jsonv2", "limit": "5", "accept-language": "es"},
        headers={"User-Agent": _USER_AGENT},
    )
    response.raise_for_status()
    hits: list[PlaceHit] = []
    for row in response.json()[:5]:
        hits.append(
            PlaceHit(
                label=row["display_name"],
                latitude=float(row["lat"]),
                longitude=float(row["lon"]),
            )
        )
    return hits
