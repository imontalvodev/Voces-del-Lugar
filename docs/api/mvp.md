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
| GET | `/stories/review` | `curator` o `admin` | Historias `pending_review`, de la más antigua a la más nueva. |
| GET | `/stories/{id}` | cualquiera si está publicada; si no, solo su autor o un moderador | Detalle, lugar, media y licencia. |
| POST | `/stories` | cuenta | Crea lugar y historia en `pending_review`. `narrator_consent` tiene que ser `true`. |
| PATCH | `/stories/{id}` | autor, solo en `pending_review` | Corrige título, texto, nombre y parentesco. |
| POST | `/stories/{id}/audio` | autor | Adjunta un audio (`multipart`, campo `file`). |
| POST | `/stories/{id}/publish` | `curator` o `admin` | Publica si hay texto o audio. |
| POST | `/stories/{id}/reject` | `curator` o `admin` | Marca `rejected`. |
| GET | `/media/{id}` | igual que el detalle de la historia | El archivo. |

Licencias aceptadas en el cuerpo: `CC-BY-SA-4.0` (por defecto), `CC-BY-4.0`, `CC0-1.0`.
