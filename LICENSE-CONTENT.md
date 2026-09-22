# Licencia del contenido

Esta licencia aplica al **contenido generado por usuarios** del proyecto (historias, transcripciones, fotos, audio, vídeo subidos por narradores o recopiladores). No aplica al código fuente, que se rige por [`LICENSE.md`](./LICENSE.md) (MIT).

El razonamiento está en [`docs/ADR-005-licencias.md`](./docs/ADR-005-licencias.md).

## Licencia por defecto: CC BY-SA 4.0

**Reconocimiento-CompartirIgual 4.0 Internacional**
(Attribution-ShareAlike 4.0 International)

Texto legal completo (vinculante): <https://creativecommons.org/licenses/by-sa/4.0/legalcode>

Resumen no vinculante (deed): <https://creativecommons.org/licenses/by-sa/4.0/>

### Usted es libre de:

- **Compartir** — copiar y redistribuir el material en cualquier medio o formato
- **Adaptar** — remezclar, transformar y crear a partir del material
- para cualquier finalidad, incluida la comercial

El licenciante no puede revocar estas libertades en tanto usted siga los términos de la licencia.

### Bajo los siguientes términos:

- **Reconocimiento (Attribution)** — Debe reconocer adecuadamente la autoría (narrador o familia, según corresponda), proporcionar un enlace a la licencia e indicar si se han realizado cambios. Puede hacerlo de cualquier manera razonable, pero no de forma que sugiera que el licenciante o el narrador respalda el uso que hace.
- **CompartirIgual (ShareAlike)** — Si remezcla, transforma o crea a partir del material, debe difundir sus contribuciones bajo la misma licencia que el original.
- **No hay restricciones adicionales** — No puede aplicar términos legales ni medidas tecnológicas que restrinjan legalmente a otras personas hacer cualquier uso permitido por la licencia.

## Licencias abiertas permitidas por historia

El campo `license` de la tabla `stories` (ver [`docs/ADR-003-modelo-datos-postgis.md`](./docs/ADR-003-modelo-datos-postgis.md)) guarda la licencia de esa historia. El valor por defecto es `CC-BY-SA-4.0`. Las únicas alternativas que el proyecto acepta son también licencias abiertas:

| Valor en `stories.license` | Licencia |
|---|---|
| `CC-BY-SA-4.0` | CC BY-SA 4.0 (por defecto) |
| `CC-BY-4.0` | CC BY 4.0 |
| `CC0-1.0` | CC0 1.0, dominio público |

No se aceptan licencias con cláusula no comercial (NC) ni licencias privativas: el archivo es open source y el contenido también tiene que poder reutilizarse en libertad.

## El proyecto es gratuito

La instancia del proyecto no cobra por leer ni por publicar, no lleva publicidad y no vende datos de quienes participan. Eso es una regla del producto, descrita en [`docs/VISION.md`](./docs/VISION.md). No se codifica como restricción de la licencia: una licencia open source no puede prohibir el uso comercial por parte de terceros.

## Consentimiento

Antes de publicar una historia, quien la sube confirma que el narrador —o la familia, si el narrador ha fallecido— acepta publicarla bajo la licencia elegida. Esos datos se guardan en la historia (`narrator_consent`, `narrator_deceased`, `consent_recorded_at`).

---

*Aviso: este texto no constituye asesoría legal. Resume las licencias enlazadas; el texto vinculante es el de cada licencia.*
