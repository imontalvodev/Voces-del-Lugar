# ADR-004: Estructura del monorepo

## Contexto

El proyecto tiene varias piezas que se despliegan por separado (backend, apps móviles, web) pero que evolucionan juntas y comparten personas contribuyendo. El framework de frontend (Flutter) y el lenguaje de backend (Python + FastAPI) ya están cerrados (ver ADR-002), así que la estructura refleja esa decisión.

## Decisión

Usar un **monorepo único**, con una carpeta por "pieza desplegable" y una carpeta compartida para lo transversal (docs, ADRs, scripts).

### Por qué monorepo y no multi-repo

- Con pocos colaboradores al principio, un cambio que afecta a backend y frontend a la vez (ej. añadir un campo nuevo a una historia) se revisa en un único PR, no coordinando dos repos
- Un `README` y una `CONTRIBUTING.md` únicos — un contribuidor nuevo no tiene que descubrir que existen "varios repos del proyecto"
- Los ADRs y la documentación de arquitectura viven junto al código que describen, no se desincronizan con el tiempo
- Issues y proyecto de GitHub centralizados — más fácil ver todo el estado del proyecto de un vistazo

La desventaja habitual del monorepo (necesitar tooling especializado tipo Bazel/Nx para builds a gran escala) no aplica aquí: el proyecto es pequeño y no hace falta esa complejidad todavía.

## Estructura propuesta

```
Voces-del-Lugar/
├── README.md
├── CONTRIBUTING.md
├── LICENSE.md                 # MIT (código)
├── LICENSE-CONTENT.md         # CC BY-SA 4.0 (historias)
├── docker-compose.yml         # Postgres 16 + PostGIS 3.4 y la API
│
├── docs/
│   ├── VISION.md
│   ├── ADR-002-backend-lenguaje.md
│   ├── ADR-003-modelo-datos-postgis.md
│   ├── ADR-004-monorepo.md
│   ├── ADR-005-licencias.md
│   ├── ADR-006-auth-y-mvp.md
│   └── api/                   # Contrato del MVP; OpenAPI vive en /docs de la API
│
├── backend/
│   ├── src/
│   ├── migrations/
│   ├── tests/
│   └── README.md
│
├── apps/
│   └── flutter/               # Android, iOS y web
│
└── .github/
    └── workflows/
```

La visión no es un ADR: vive en `docs/VISION.md`. No hay `ADR-001`.

## Decisión de frontend (Flutter)

Con Flutter elegido en ADR-002, `apps/mobile` y `apps/web` se fusionan en una única carpeta `apps/flutter/`, ya que Flutter compila a Android, iOS y Web desde la misma base de código. La carpeta `shared/` (tipos/contratos compartidos entre apps) no hace falta: no hay tipos que compartir entre el backend Python y un frontend Dart.

## CI/CD

Un único pipeline en `.github/workflows/`, con jobs separados por carpeta afectada (para no ejecutar tests de frontend en un PR que solo toca el backend, y viceversa) usando path filters de GitHub Actions.

## Consecuencias

- Cualquier colaborador nuevo clona un solo repo y con `docker-compose up` tiene el entorno completo
- El backend y el frontend pueden evolucionar en paralelo sin fricción de coordinación entre repos
- Si el proyecto creciera mucho y necesitara separar releases independientes de cada app, se puede migrar a multi-repo más adelante sin perder el historial (usando `git subtree split` o similar) — no es una decisión irreversible
