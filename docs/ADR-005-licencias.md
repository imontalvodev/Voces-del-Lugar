# ADR-005: Licencias de código y contenido

- Estado: aceptado (revisado el 2026-09-22)
- Sustituye la decisión anterior de PolyForm Noncommercial + CC BY-NC-SA

## Contexto

El proyecto necesita dos licencias: una para el código y otra para las historias que suben los usuarios. Quien sube una historia a menudo no es quien la narró.

El proyecto es **open source** (definición OSI) y **gratuito**: cualquiera puede usar la instancia sin pagar. Una versión anterior de este ADR exigía que ningún fork pudiera ser comercial y, por eso, elegía PolyForm Noncommercial y CC BY-NC-SA. Esa restricción de campo de uso es incompatible con la Open Source Definition. Se retira.

"Gratuito" queda como regla del producto (no se cobra, no hay publicidad, no se venden datos), no como cláusula de la licencia. La licencia tiene que permitir que otra persona reutilice el código, también con fin comercial; si no, el proyecto no puede llamarse open source.

## Decisión: licencia de código

**MIT.**

### Alternativas consideradas

| Licencia | Pros | Contras |
|---|---|---|
| MIT (elegida) | OSI; texto corto; máxima facilidad para colaboradores voluntarios; el software se puede usar, copiar y modificar gratis | Un tercero puede ofrecer un fork de pago sin devolver los cambios |
| AGPL-3.0 | OSI; obliga a publicar el código también cuando el fork se ofrece como servicio web | Menos colaboradores potenciales; más fricción para integraciones |
| PolyForm Noncommercial | Prohíbe el uso comercial | No es open source. Descartada al fijar el proyecto como OSI |
| Apache-2.0 | OSI, con cláusula de patentes explícita | Más texto del que este proyecto necesita ahora |

**Razón**: MIT cumple "open source y gratuito" con la menor barrera para un equipo voluntario. El copyleft de red (AGPL) se puede reconsiderar si aparece un fork que cierre el código de un servicio; no se adopta de antemano.

## Decisión: licencia de contenido

**CC BY-SA 4.0 por defecto**, configurable por historia dentro de un conjunto cerrado de licencias abiertas.

Valores aceptados en `stories.license`:

- `CC-BY-SA-4.0` (por defecto)
- `CC-BY-4.0`
- `CC0-1.0`

### Alternativas consideradas

| Licencia | Pros | Contras |
|---|---|---|
| CC BY-SA 4.0 (elegida por defecto) | Abierta, atribución al narrador o a la familia, las obras derivadas siguen igual de abiertas. Estándar en patrimonio cultural | Impide mezclar la historia en una obra privativa |
| CC BY 4.0 | Abierta y más fácil de combinar | Una adaptación puede cerrarse |
| CC0 | Máxima reutilización | El narrador pierde la atribución obligatoria |
| CC BY-NC-SA 4.0 | Bloquea explotación comercial | No es una licencia abierta (cláusula NC). Descartada |

## Consentimiento

Quien sube la historia confirma, en el formulario, que el narrador ha dado permiso para publicarla bajo la licencia elegida. Si el narrador ha fallecido, el permiso corresponde a la familia y se marca así.

Eso se guarda en la historia, no solo en la interfaz:

- `narrator_consent` (tiene que ser verdadero para crear la historia)
- `narrator_deceased`
- `consent_recorded_at`

## Consecuencias

- El código es open source OSI. El README y la visión pueden decirlo sin matiz.
- El contenido publicado es reutilizable con atribución y, por defecto, compartir igual.
- La instancia del proyecto sigue siendo gratuita por decisión de producto.
- PolyForm y cualquier licencia NC dejan de usarse. El aviso de copyright apunta a `https://github.com/imontalvodev/Voces-del-Lugar`.
