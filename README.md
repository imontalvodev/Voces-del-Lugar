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

Sin `API_BASE`, la app web busca la API en el puerto 8001 de la misma máquina que la sirve. Para abrirla desde otro equipo de la red basta con escuchar en todas las interfaces y entrar por la IP:

```bash
cd backend && ../.venv/bin/uvicorn voces.main:app --app-dir src --host 0.0.0.0 --port 8001
cd apps/flutter && flutter build web --release && python3 -m http.server 8080 --bind 0.0.0.0 --directory build/web
```

Fuera de `localhost` y sin HTTPS el navegador no da la posición ni el micrófono: el mapa se abre igual y la historia se puede escribir o adjuntar un audio.

`docker compose up` levanta también la API. Contrato en [`docs/api/mvp.md`](./docs/api/mvp.md). La primera cuenta que se registra es administradora y puede publicar.

## Estado del proyecto

Fase 1 — MVP: cuenta, historia con texto o audio, consentimiento, moderación y mapa. Aún no hay cola de procesado de media ni fotos.

Ver fases completas en [`docs/VISION.md`](./docs/VISION.md#fases-de-alcance-a-alto-nivel).

## Servir en público

Hace falta un dominio apuntando a la máquina. En el entorno del compose, sin commitearlo:

```bash
export POSTGRES_PASSWORD='una-clave-larga'
export JWT_SECRET='otra-clave-de-al-menos-32-caracteres'
export VOCES_DOMAIN='voces.example'
docker compose -f docker-compose.prod.yml up -d --build
```

Copia de la base y de los audios:

```bash
docker compose -f docker-compose.prod.yml exec -T db pg_dump -U voces voces > voces.sql
docker compose -f docker-compose.prod.yml exec -T api tar -C /data -czf - media > voces-media.tgz
```

La app web se construye con `--dart-define=API_BASE=https://voces.example`.

## Licencias

El proyecto es open source y gratuito. Razonamiento en [`docs/ADR-005-licencias.md`](./docs/ADR-005-licencias.md).

- **Código**: [MIT](./LICENSE.md), licencia OSI. Usar, copiar y modificar el software es gratis.
- **Contenido de usuarios** (historias, audio, fotos, vídeo): [CC BY-SA 4.0](./LICENSE-CONTENT.md) por defecto. Cada historia puede elegir otra licencia abierta (`CC-BY-4.0` o `CC0-1.0`).

Gratuito significa que esta instancia no cobra, no lleva publicidad y no vende datos. La licencia MIT no prohíbe que un tercero reutilice el código: esa prohibición impediría llamarlo open source.

## Contribuir

Ver [`CONTRIBUTING.md`](./CONTRIBUTING.md) para el flujo de trabajo, convenciones de commits y estado del proyecto.

## Licencia

Ver la sección [Licencias](#licencias) arriba.
