# API del MVP

Base: `/api/v1`. Esquema interactivo: `/docs` cuando la API está en marcha.

| Método | Ruta | Quién | Qué hace |
|---|---|---|---|
| POST | `/auth/register` | cualquiera | Crea la cuenta. La primera de la base queda `admin`. |
| POST | `/auth/login` | cualquiera | Devuelve un JWT. |
| GET | `/auth/me` | cuenta | Perfil y rol. |
| GET | `/stories/map?west&south&east&north` | cualquiera | Historias `published` dentro del recuadro. |
| GET | `/stories/nearby?lat&lng&radius_m` | cualquiera | Historias `published` a menos de `radius_m` metros (máximo 50000). |
| GET | `/geocode?q=` | cualquiera | Hasta 5 lugares (nombre, latitud, longitud) para centrar el mapa. `q` tiene al menos 2 letras. |
| GET | `/stories/mine` | cuenta | Historias de quien llama, en cualquier estado. |
| GET | `/stories/review` | `curator` o `admin` | Historias `pending_review` listas para mirar (no las que esperan su audio), de la más antigua a la más nueva. |
| GET | `/stories/{id}` | cualquiera si está publicada; si no, solo su autor o un moderador | Detalle, lugar, media y licencia. |
| POST | `/stories` | cuenta | Crea lugar e historia. Pasa por el filtro (ver abajo): `422` si es basura, `published` si pasa y tiene texto, `pending_review` si no. `narrator_consent` tiene que ser `true`. |
| PATCH | `/stories/{id}` | autor, solo en `pending_review` | Corrige título, texto, nombre y parentesco. `422` si lo corregido es basura. |
| POST | `/stories/{id}/audio` | autor | Adjunta un audio (`multipart`, campo `file`). Si la historia lo esperaba, se publica (o pasa a revisión sin publicación automática). Una publicada sin audio admite uno. |
| POST | `/stories/{id}/publish` | `curator` o `admin` | Publica si hay texto o audio. |
| POST | `/stories/{id}/reject` | `curator` o `admin` | Marca `rejected`. |
| POST | `/stories/{id}/unpublish` | `curator` o `admin` | Vuelve a `pending_review` con motivo `unpublished` y desaparece del mapa. |
| GET | `/media/{id}` | igual que el detalle de la historia | El archivo. |
| GET | `/push/config` | cualquiera | `vapid_public_key` para registrar UnifiedPush, o `null`. |
| PUT | `/push/devices` | cuenta | Guarda este dispositivo: `platform` `webpush` (UnifiedPush: `endpoint` https público, `p256dh`, `auth`) o `apns` (`endpoint` = token). Si ya era de otra cuenta, pasa a esta. `204`. |
| DELETE | `/push/devices?endpoint=` | cuenta | Lo quita, por ejemplo al cerrar sesión. `204`. |
| GET, PATCH | `/push/prefs` | cuenta | `notify_own` (lo mío se publica o se rechaza) y `notify_review` (hay algo por revisar; solo llega a `curator` y `admin`). Los dos empiezan en `true`. |
| GET, POST | `/push/places` | cuenta | Sitios vigilados: `name`, `latitude`, `longitude`, `radius_m` (200 a 20000, 2000 por defecto). Hasta 20. |
| DELETE | `/push/places/{id}` | cuenta | Deja de vigilar ese sitio. `204`. |

Licencias aceptadas en el cuerpo: `CC-BY-SA-4.0` (por defecto), `CC-BY-4.0`, `CC0-1.0`.

## Historia en las respuestas

Todas las rutas que devuelven historias (`map`, `nearby`, `mine`, `review`, el detalle y las acciones de moderación) usan la misma forma. Campos que conviene conocer:

| Campo | Qué es |
|---|---|
| `number` | Número de ficha, correlativo y único. La app lo pinta como «Nº 0142». Las historias anteriores a este campo se numeraron por fecha de creación. |
| `author_name` | Nombre visible (`display_name`) de la cuenta que subió la historia, junto a `author_id`. La ficha lo enseña como «Recogida por». |
| `review_reason` | Por qué sigue en `pending_review`, o `null`. `awaiting_media`: espera su audio. `link`, `contact`, `language`, `many`: el filtro la apartó por un enlace, un email o teléfono, palabras malsonantes o demasiadas seguidas. `unpublished`: la retiró un moderador. La app pone las palabras. |

## Filtro y publicación automática

No hay moderadores a tiempo completo. Al guardar o corregir, el título, el texto y el nombre de quien la cuenta pasan por `voces/moderation.py`:

- **Basura obvia** (letras repetidas, palabras sin vocales, casi sin letras, título vacío): `422` con un mensaje para quien escribe, y no se guarda.
- **Dudosa** (enlaces, email o teléfono, palabras malsonantes, más de 5 historias en una hora): queda en `pending_review` con su `review_reason` hasta que la mire el admin.
- **Lo demás** se publica al momento. Si solo lleva audio, se publica cuando llega el audio; el audio no se puede leer y pasa tal cual.

`AUTO_PUBLISH=false` vuelve a la revisión a mano de todo: el filtro de basura sigue y nada se publica solo.

## Avisos push

Sin Google: Android recibe por UnifiedPush (la app necesita un distribuidor, como ntfy) y iOS por APNs. Cada aviso lleva `kind`, `story_id`, `title` y `body`; por UnifiedPush va como JSON cifrado (RFC 8291) y firmado con VAPID si hay `VAPID_PRIVATE_KEY`.

| `kind` | A quién | Cuándo |
|---|---|---|
| `published` | autor con `notify_own` | Un moderador publica su historia. Si se publica sola no hace falta: lo ve al guardar. |
| `rejected` | autor con `notify_own` | Un moderador la rechaza. |
| `review` | `curator` y `admin` con `notify_review`, menos el autor | Una historia queda en revisión lista para mirar. |
| `nearby` | quien vigila un sitio a menos de `radius_m`, menos el autor | Se publica una historia, a mano o sola. |

Los avisos salen después de responder. Si el servicio responde `404` o `410` (o APNs dice `BadDeviceToken`), el dispositivo se borra.
