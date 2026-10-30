"""Envío de avisos push sin Google.

Android recibe por UnifiedPush: la app da la URL de su distribuidor (ntfy u
otro) y sus claves, y aquí se manda un Web Push cifrado (RFC 8291) y firmado
con VAPID (RFC 8292). iOS recibe por APNs con la clave .p8 de la cuenta de
Apple. Sin claves configuradas, esa vía no manda nada.

`python -m voces.push claves` crea un par VAPID para `VAPID_PRIVATE_KEY`.
"""

import base64
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Protocol
from urllib.parse import urlsplit

import httpx
import jwt
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

from voces.config import Settings

log = logging.getLogger(__name__)

RECORD_SIZE = 4096


class Sender(Protocol):
    def send(self, device: dict, message: dict) -> bool:
        """Manda el aviso. Devuelve False si el dispositivo ya no existe."""


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _unb64url(data: str) -> bytes:
    return base64.urlsafe_b64decode(data + "=" * (-len(data) % 4))


def private_key_from(raw: str) -> ec.EllipticCurvePrivateKey:
    return ec.derive_private_key(int.from_bytes(_unb64url(raw), "big"), ec.SECP256R1())


def _public_bytes(key: ec.EllipticCurvePrivateKey) -> bytes:
    return key.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)


def public_key_b64(private_raw: str) -> str:
    return b64url(_public_bytes(private_key_from(private_raw)))


def encrypt(
    payload: bytes,
    p256dh: str,
    auth: str,
    *,
    salt: bytes | None = None,
    server_key: ec.EllipticCurvePrivateKey | None = None,
) -> bytes:
    """Cuerpo `aes128gcm` de un Web Push (RFC 8291), en un solo registro."""
    salt = salt or os.urandom(16)
    server_key = server_key or ec.generate_private_key(ec.SECP256R1())
    ua_public = _unb64url(p256dh)
    server_public = _public_bytes(server_key)
    shared = server_key.exchange(ec.ECDH(), ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), ua_public))
    ikm = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=_unb64url(auth),
        info=b"WebPush: info\x00" + ua_public + server_public,
    ).derive(shared)
    cek = HKDF(algorithm=hashes.SHA256(), length=16, salt=salt, info=b"Content-Encoding: aes128gcm\x00").derive(ikm)
    nonce = HKDF(algorithm=hashes.SHA256(), length=12, salt=salt, info=b"Content-Encoding: nonce\x00").derive(ikm)
    ciphertext = AESGCM(cek).encrypt(nonce, payload + b"\x02", None)
    header = salt + RECORD_SIZE.to_bytes(4, "big") + bytes([len(server_public)]) + server_public
    return header + ciphertext


def vapid_headers(endpoint: str, private_raw: str, subject: str) -> dict[str, str]:
    parts = urlsplit(endpoint)
    token = jwt.encode(
        {"aud": f"{parts.scheme}://{parts.netloc}", "exp": int(time.time()) + 12 * 3600, "sub": subject},
        private_key_from(private_raw),
        algorithm="ES256",
    )
    return {"Authorization": f"vapid t={token}, k={public_key_b64(private_raw)}"}


class WebPushSender:
    def __init__(self, settings: Settings, client: httpx.Client | None = None):
        self.settings = settings
        self.client = client or httpx.Client(timeout=10)

    def send(self, device: dict, message: dict) -> bool:
        body = encrypt(json.dumps(message, ensure_ascii=False).encode(), device["p256dh"], device["auth"])
        headers = {"Content-Encoding": "aes128gcm", "TTL": str(7 * 24 * 3600), "Urgency": "normal"}
        if self.settings.vapid_private_key:
            headers |= vapid_headers(device["endpoint"], self.settings.vapid_private_key, self.settings.vapid_subject)
        response = self.client.post(device["endpoint"], content=body, headers=headers)
        if response.status_code in (404, 410):
            return False
        if response.status_code >= 400:
            log.warning("Web Push respondió %s", response.status_code)
        return True


class ApnsSender:
    def __init__(self, settings: Settings, client: httpx.Client | None = None):
        self.settings = settings
        self.client = client or httpx.Client(http2=True, timeout=10)
        self._token: tuple[float, str] | None = None

    @property
    def configured(self) -> bool:
        s = self.settings
        return bool(s.apns_key_path and s.apns_key_id and s.apns_team_id and s.apns_topic)

    def _bearer(self) -> str:
        # Apple pide renovar el token entre 20 y 60 minutos.
        if self._token is None or time.time() - self._token[0] > 40 * 60:
            key = Path(self.settings.apns_key_path).read_text()
            token = jwt.encode(
                {"iss": self.settings.apns_team_id, "iat": int(time.time())},
                key,
                algorithm="ES256",
                headers={"kid": self.settings.apns_key_id},
            )
            self._token = (time.time(), token)
        return self._token[1]

    def send(self, device: dict, message: dict) -> bool:
        if not self.configured:
            return True
        host = "api.sandbox.push.apple.com" if self.settings.apns_sandbox else "api.push.apple.com"
        payload = {
            "aps": {"alert": {"title": message["title"], "body": message["body"]}, "sound": "default"},
            "kind": message["kind"],
            "story_id": message["story_id"],
        }
        response = self.client.post(
            f"https://{host}/3/device/{device['endpoint']}",
            json=payload,
            headers={
                "authorization": f"bearer {self._bearer()}",
                "apns-topic": self.settings.apns_topic,
                "apns-push-type": "alert",
            },
        )
        if response.status_code == 410:
            return False
        if response.status_code == 400 and "BadDeviceToken" in response.text:
            return False
        if response.status_code >= 400:
            log.warning("APNs respondió %s: %s", response.status_code, response.text)
        return True


class Dispatcher:
    """Elige la vía de cada dispositivo."""

    def __init__(self, settings: Settings):
        self.webpush = WebPushSender(settings)
        self.apns = ApnsSender(settings)

    def send(self, device: dict, message: dict) -> bool:
        sender = self.apns if device["platform"] == "apns" else self.webpush
        try:
            return sender.send(device, message)
        except Exception:
            log.exception("No se pudo mandar un aviso")
            return True


def _new_keys() -> None:
    key = ec.generate_private_key(ec.SECP256R1())
    private = b64url(key.private_numbers().private_value.to_bytes(32, "big"))
    print(f"VAPID_PRIVATE_KEY={private}")
    print(f"# Clave pública (la API la da en /api/v1/push/config): {public_key_b64(private)}")


if __name__ == "__main__" and sys.argv[1:] == ["claves"]:
    _new_keys()
