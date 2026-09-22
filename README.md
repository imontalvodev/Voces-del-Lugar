# Voces del Lugar

> Nombre de trabajo — pendiente de decidir nombre definitivo.

Un archivo colectivo, libre y abierto de historia oral local, anclado geográficamente. Cualquier persona puede registrar las historias y anécdotas que la gente mayor de su entorno asocia a lugares concretos, y cualquier otra persona puede descubrirlas en un mapa, mucho después de que quien las contó ya no esté.

Ver [`docs/VISION.md`](./docs/VISION.md) para la visión completa del proyecto.

## A quién sirve

- **Narradores**: personas mayores (o de mediana edad) que tienen recuerdos e historias de un lugar
- **Recopiladores**: normalmente familiares que graban o transcriben esas historias y las suben
- **Descubridores**: cualquier persona curiosa, vecino, investigador local o turista
- **Comunidades locales**: asociaciones de vecinos, cronistas locales, colegios

## Stack técnico

| Pieza | Tecnología | Decisión |
|---|---|---|
| Backend | Python + FastAPI | [`docs/ADR-002-backend-lenguaje.md`](./docs/ADR-002-backend-lenguaje.md) |
| Frontend (mobile + web) | Flutter | [`docs/ADR-002-backend-lenguaje.md`](./docs/ADR-002-backend-lenguaje.md) |
| Base de datos | PostgreSQL + PostGIS | [`docs/ADR-003-modelo-datos-postgis.md`](./docs/ADR-003-modelo-datos-postgis.md) |
| Estructura de repo | Monorepo | [`docs/ADR-004-monorepo.md`](./docs/ADR-004-monorepo.md) |

Todas las decisiones de arquitectura se documentan como ADRs (Architecture Decision Records) en [`docs/`](./docs/), explicando no solo qué se decidió sino por qué.

## Arrancar en local

Hace falta Docker. Las librerías de Python van al `.venv` de la raíz, no al sistema. Flutter solo para la app (`flutter` en el `PATH`; en esta máquina el SDK puede estar en `~/flutter`).

```bash
docker compose up -d db
.venv/bin/pip install -r backend/requirements-dev.txt
cd backend && ../.venv/bin/alembic upgrade head && ../.venv/bin/uvicorn voces.main:app --reload --app-dir src --port 8001
```

En otra terminal, la app web:

```bash
cd apps/flutter
flutter run -d web-server --web-port 8080 --dart-define=API_BASE=http://localhost:8001
```

`docker compose up` levanta también la API. Contrato en [`docs/api/mvp.md`](./docs/api/mvp.md). La primera cuenta que se registra es administradora y puede publicar.

## Estado del proyecto

Fase 1 — MVP: cuenta, historia con texto o audio, consentimiento, moderación y mapa. Aún no hay cola de procesado de media ni fotos.

Ver fases completas en [`docs/VISION.md`](./docs/VISION.md#fases-de-alcance-a-alto-nivel).

## Licencias

El proyecto es open source y gratuito. Razonamiento en [`docs/ADR-005-licencias.md`](./docs/ADR-005-licencias.md).

- **Código**: [MIT](./LICENSE.md), licencia OSI. Usar, copiar y modificar el software es gratis.
- **Contenido de usuarios** (historias, audio, fotos, vídeo): [CC BY-SA 4.0](./LICENSE-CONTENT.md) por defecto. Cada historia puede elegir otra licencia abierta (`CC-BY-4.0` o `CC0-1.0`).

Gratuito significa que esta instancia no cobra, no lleva publicidad y no vende datos. La licencia MIT no prohíbe que un tercero reutilice el código: esa prohibición impediría llamarlo open source.

## Contribuir

Ver [`CONTRIBUTING.md`](./CONTRIBUTING.md) para el flujo de trabajo, convenciones de commits y estado del proyecto.

## Licencia

Ver la sección [Licencias](#licencias) arriba.
