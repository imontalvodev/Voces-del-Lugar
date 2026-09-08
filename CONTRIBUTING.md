# Contribuir a Voces del Lugar

Gracias por el interés en colaborar. Este documento explica cómo proponer cambios, qué convenciones seguimos y qué esperar del proceso de revisión.

Antes de nada, lee [`docs/VISION.md`](./docs/VISION.md) para entender qué es el proyecto y qué valores guían las decisiones — en particular, "las personas por encima de la tecnología" y "sostenibilidad antes que crecimiento rápido" condicionan casi todas las decisiones técnicas de aquí en adelante.

## Estado actual del proyecto

El proyecto está en **Fase 0 — Fundamentos**: visión, arquitectura y ADRs. Todavía no hay código de aplicación (`backend/` y `apps/flutter/` no existen aún, ver [`docs/ADR-004-monorepo.md`](./docs/ADR-004-monorepo.md) para la estructura prevista). Las instrucciones de entorno local (`docker-compose.yml`, cómo levantar backend/frontend) se documentarán aquí en cuanto exista ese código.

## Stack técnico

- **Backend**: Python + FastAPI — [`docs/ADR-002-backend-lenguaje.md`](./docs/ADR-002-backend-lenguaje.md)
- **Frontend** (mobile + web): Flutter — mismo ADR-002
- **Base de datos**: PostgreSQL + PostGIS — [`docs/ADR-003-modelo-datos-postgis.md`](./docs/ADR-003-modelo-datos-postgis.md)
- **Estructura**: monorepo — [`docs/ADR-004-monorepo.md`](./docs/ADR-004-monorepo.md)

## Flujo de trabajo

1. Abre un issue antes de empezar un cambio grande, para discutir el enfoque antes de invertir tiempo.
2. Crea una rama a partir de `main` (`feat/nombre-corto`, `fix/nombre-corto`, `docs/nombre-corto`...).
3. Haz commits siguiendo [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`. Mensaje en imperativo, explica el *por qué* si no es obvio.
4. Abre un Pull Request contra `main`.
5. `main` está protegida: no se permite push directo (aplica también a administradores), y todo PR necesita **al menos 1 aprobación** antes de mergear. Cuando exista CI (ver más abajo), también deberá pasar en verde.
6. Si tu cambio afecta a una decisión de arquitectura (elección de librería, cambio de esquema, cambio de convención), añade o actualiza un ADR en `docs/` en el mismo PR — no lo dejes para después.

## Integración continua (CI)

Aún no está montada (Fase 0). El plan ya está decidido y documentado internamente: lint de Markdown ahora, y jobs de backend (`pytest` + PostGIS) y frontend (`flutter analyze`/`flutter test`) activados por `paths:` en cuanto exista código en `backend/` o `apps/flutter/` respectivamente. Se añadirá como status check obligatorio a la protección de `main` en cuanto exista.

## Licencias de tu contribución

- El código que aportes se licencia bajo [`LICENSE.md`](./LICENSE.md) (PolyForm Noncommercial 1.0.0) — al abrir un PR aceptas que tu contribución se distribuya bajo esos términos.
- Si tu cambio afecta al modelo de contenido de usuarios (historias, media), revisa [`LICENSE-CONTENT.md`](./LICENSE-CONTENT.md) y [`docs/ADR-005-licencias.md`](./docs/ADR-005-licencias.md) — el requisito no negociable del proyecto es que **ningún fork o uso pueda ser comercial**.

## Reportar bugs o proponer funcionalidades

Usa los issues de GitHub. Para bugs: pasos para reproducir, comportamiento esperado vs observado. Para propuestas de funcionalidad: qué problema resuelve y a qué perfil de usuario sirve (narrador, recopilador, descubridor, comunidad — ver `docs/VISION.md`).

## Código de conducta

Pendiente de redactar un `CODE_OF_CONDUCT.md` formal. Mientras tanto: trato respetuoso, foco en el contenido técnico de la discusión, cero tolerancia a acoso o descalificaciones personales.
