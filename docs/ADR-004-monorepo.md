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
historias-lugares/
├── README.md                  # Qué es el proyecto, cómo arrancar en 5 minutos
├── VISION.md                  # Documento de visión y alcance
├── CONTRIBUTING.md            # Cómo levantar el entorno, convenciones, cómo proponer cambios
├── LICENSE                    # Licencia del código (pendiente, ver ADR de licencias)
├── docker-compose.yml         # Postgres+PostGIS y demás servicios locales, un comando para arrancar todo
│
├── docs/
│   ├── adr/                   # Todos los Architecture Decision Records
│   │   ├── ADR-001-vision-alcance.md
│   │   ├── ADR-002-backend-lenguaje.md
│   │   ├── ADR-003-modelo-datos-postgis.md
│   │   └── ADR-004-monorepo.md
│   └── api/                   # Documentación de la API (o se autogenera desde el código)
│
├── backend/
│   ├── src/                   # Código de la API (estructura interna depende del lenguaje elegido)
│   ├── migrations/            # Migraciones versionadas de base de datos
│   ├── tests/
│   └── README.md              # Cómo levantar y testear SOLO el backend
│
├── apps/
│   └── flutter/                 # App única: Android, iOS y Web desde la misma base de código
│       └── README.md
│
├── infra/
│   ├── deploy/                 # Configuración de despliegue (Render/Fly.io, etc.)
│   └── scripts/                # Scripts de utilidad (seed de datos de prueba, etc.)
│
└── .github/
    ├── workflows/               # CI: tests de backend, tests de apps, lint
    └── ISSUE_TEMPLATE/
```

## Decisión de frontend (Flutter)

Con Flutter elegido en ADR-002, `apps/mobile` y `apps/web` se fusionan en una única carpeta `apps/flutter/`, ya que Flutter compila a Android, iOS y Web desde la misma base de código. La carpeta `shared/` (tipos/contratos compartidos entre apps) no hace falta: no hay tipos que compartir entre el backend Python y un frontend Dart.

## CI/CD

Un único pipeline en `.github/workflows/`, con jobs separados por carpeta afectada (para no ejecutar tests de frontend en un PR que solo toca el backend, y viceversa) usando path filters de GitHub Actions.

## Consecuencias

- Cualquier colaborador nuevo clona un solo repo y con `docker-compose up` tiene el entorno completo
- El backend y el frontend pueden evolucionar en paralelo sin fricción de coordinación entre repos
- Si el proyecto creciera mucho y necesitara separar releases independientes de cada app, se puede migrar a multi-repo más adelante sin perder el historial (usando `git subtree split` o similar) — no es una decisión irreversible
