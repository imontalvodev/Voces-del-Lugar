import httpx
import pytest

from voces.geocode import search_places
from voces.schemas import PlaceHit


def test_search_places_reads_nominatim_json():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["q"] == "Cáceres"
        assert request.url.params["limit"] == "5"
        assert request.url.params["accept-language"] == "es"
        assert request.headers["user-agent"] == (
            "VocesDelLugar/0.1 (https://github.com/imontalvodev/Voces-del-Lugar)"
        )
        return httpx.Response(
            200,
            json=[{"display_name": "Cáceres, España", "lat": "39.475", "lon": "-6.372"}],
        )

    client = httpx.Client(transport=httpx.MockTransport(handler))
    hits = search_places("Cáceres", client)
    assert hits == [PlaceHit(label="Cáceres, España", latitude=39.475, longitude=-6.372)]


def test_search_places_rejects_one_letter():
    client = httpx.Client(transport=httpx.MockTransport(lambda request: httpx.Response(500)))
    with pytest.raises(ValueError, match="dos letras"):
        search_places(" a ", client)
