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

## Estado del proyecto

Fase 0 — Fundamentos: visión, arquitectura y ADRs en marcha. Aún no hay código de aplicación.

Ver fases completas en [`docs/VISION.md`](./docs/VISION.md#fases-de-alcance-a-alto-nivel).

## Licencias

Este proyecto usa dos licencias distintas, con un requisito no negociable: **ningún fork o copia puede ser comercial**. Razonamiento completo en [`docs/ADR-005-licencias.md`](./docs/ADR-005-licencias.md).

- **Código**: [PolyForm Noncommercial 1.0.0](./LICENSE.md)
- **Contenido de usuarios** (historias, audio, fotos, vídeo): [CC BY-NC-SA 4.0](./LICENSE-CONTENT.md), configurable por historia

Al no ser licencias OSI-aprobadas para uso comercial, el proyecto no es "open source" en sentido OSI estricto — se usa "código abierto" en sentido coloquial.

## Contribuir

Ver [`CONTRIBUTING.md`](./CONTRIBUTING.md) para el flujo de trabajo, convenciones de commits y estado del proyecto.

## Licencia

Ver la sección [Licencias](#licencias) arriba.
