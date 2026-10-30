import base64

import jwt
from cryptography.hazmat.primitives.asymmetric import ec

from voces.push import encrypt, private_key_from, public_key_b64, vapid_headers


def _b64(data: str) -> bytes:
    return base64.urlsafe_b64decode(data + "=" * (-len(data) % 4))


def test_cifra_igual_que_el_ejemplo_del_rfc_8291():
    body = encrypt(
        b"When I grow up, I want to be a watermelon",
        p256dh="BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
        auth="BTBZMqHH6r4Tts7J_aSIgg",
        salt=_b64("DGv6ra1nlYgDCS1FRnbzlw"),
        server_key=private_key_from("yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw"),
    )
    assert body == _b64(
        "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN"
    )


def test_la_firma_vapid_va_al_origen_del_destino():
    key = ec.generate_private_key(ec.SECP256R1())
    raw = key.private_numbers().private_value.to_bytes(32, "big")
    private = base64.urlsafe_b64encode(raw).rstrip(b"=").decode()
    headers = vapid_headers("https://ntfy.example/upAbc?up=1", private, "mailto:hola@voces.example")
    scheme, _, rest = headers["Authorization"].partition(" ")
    parts = dict(item.strip().split("=", 1) for item in rest.split(","))
    assert scheme == "vapid"
    assert parts["k"] == public_key_b64(private)
    claims = jwt.decode(parts["t"], key.public_key(), algorithms=["ES256"], audience="https://ntfy.example")
    assert claims["sub"] == "mailto:hola@voces.example"
