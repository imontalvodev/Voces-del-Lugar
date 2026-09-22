# API

FastAPI y PostgreSQL 16 + PostGIS 3.4. El intérprete es el `.venv` de la raíz del repositorio.

```bash
docker compose up -d db
.venv/bin/pip install -r backend/requirements-dev.txt
cd backend
../.venv/bin/alembic upgrade head
../.venv/bin/uvicorn voces.main:app --reload --app-dir src --port 8001
```

La API queda en `http://localhost:8001` y el esquema en `http://localhost:8001/docs`. En esta máquina el 5432 y el 8000 ya están ocupados, así que Postgres se publica en el 5433.

`docker compose up` también levanta la API (servicio `api`) con la misma base.

Tests (hace falta el Postgres del compose):

```bash
cd backend && ../.venv/bin/pytest
```

Contrato: [`docs/api/mvp.md`](../docs/api/mvp.md).
