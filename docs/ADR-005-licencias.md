# ADR-005: Licencias de código y contenido

## Contexto

El proyecto es open source y sin ánimo de lucro. Necesita dos licencias distintas: una para el código (backend, apps) y otra para el contenido generado por los usuarios (las historias), que además involucra a terceros (narradores) que no son quienes suben el contenido.

## Requisito explícito: ningún fork o copia puede ser comercial

Se estableció como requisito no negociable que cualquier fork o copia del proyecto debe seguir siendo código abierto **y sin ánimo de lucro**, sin excepción.

**Nota legal importante**: la Open Source Definition (OSI) prohíbe explícitamente restringir licencias por "campo de uso" — ninguna licencia OSI-aprobada (MIT, GPL, AGPL...) puede prohibir el uso comercial. Esto significa que, para cumplir el requisito, el proyecto sale deliberadamente del terreno "open source" en sentido estricto y usa una licencia "source-available" con restricción de uso no comercial. Esta sección no constituye asesoría legal — para el texto definitivo se recomienda revisión por alguien con formación legal.

## Decisión: licencia de código

**PolyForm Noncommercial 1.0.0.**

### Alternativas consideradas

| Licencia | Pros | Contras |
|---|---|---|
| MIT | Máxima simplicidad y adopción | Permite forks comerciales — incompatible con el requisito |
| AGPLv3 | Open source real (OSI); obliga a compartir código incluso en uso como servicio web | No impide el uso comercial en sí, solo obliga a compartir el código del fork — no cumple el requisito de "sin ánimo de lucro" |
| PolyForm Noncommercial 1.0.0 | Prohíbe explícitamente cualquier uso comercial, incluidos forks; texto bien redactado por una organización dedicada a licencias, evita ambigüedades de una cláusula custom | No es "open source" en sentido OSI estricto — puede desanimar a colaboradores que solo contribuyen a proyectos OSI-aprobados; se pierde la etiqueta formal "open source" (se usa "código abierto" en sentido coloquial) |
| AGPL + Commons Clause | Alternativa combinando copyleft con prohibición de venta | Combinar cláusulas custom sobre una licencia base añade más riesgo de ambigüedad legal que una licencia ya redactada para este propósito específico |

**Razón**: PolyForm Noncommercial traduce fielmente el requisito ("cualquier fork debe seguir siendo sin ánimo de lucro") a un texto legal reconocido, sin necesidad de redactar cláusulas propias.

## Decisión: licencia de contenido (las historias)

**CC-BY-NC-SA 4.0 por defecto, configurable por historia** (campo `license` en la tabla `stories`, ver ADR-003).

### Alternativas consideradas

| Licencia | Pros | Contras |
|---|---|---|
| CC0 (dominio público) | Máxima apertura y reutilización | El narrador pierde el derecho a ser atribuido; además permitiría uso comercial — incompatible con el requisito |
| CC-BY-SA 4.0 | Mantiene atribución; estándar en patrimonio cultural abierto | Permite uso comercial de terceros — incompatible con el requisito |
| CC-BY-NC-SA 4.0 | Mantiene atribución al narrador/familia; bloquea explotación comercial no autorizada (ej. agencias turísticas); coherente con el requisito de "sin ánimo de lucro" en cualquier reutilización | Reduce reutilización potencial frente a CC-BY-SA; complica combinar con otro contenido abierto en proyectos externos que no acepten NC |

**Razón**: es la que cumple el requisito explícito de bloquear explotación comercial, manteniendo la atribución al narrador/familia.

## Consentimiento (no es una licencia, pero es igual de importante)

Dado que quien sube la historia no siempre es quien la narra (ej. un nieto sube la historia de su abuelo), el flujo de subida debe incluir:
- Confirmación explícita de que el narrador ha dado su permiso para publicar bajo licencia abierta
- Un campo para indicar si el narrador ya ha fallecido, en cuyo caso el consentimiento pasa a corresponder a la familia

Esto se implementa en la capa de aplicación (formulario de subida + validación), no requiere cambios en el esquema de base de datos más allá de los ya previstos.

## Consecuencias

- Ni el código ni el contenido pueden usarse comercialmente por terceros, en ningún fork o copia, cumpliendo el requisito explícito del proyecto
- El proyecto deja de poder llamarse "open source" en sentido OSI estricto; se usa "código abierto" en sentido coloquial. Esto puede reducir el interés de colaboradores que solo contribuyen a proyectos OSI-aprobados
- El contenido mantiene atribución obligatoria al narrador/familia, protegiendo su identidad sin permitir explotación comercial no autorizada
- Queda pendiente definir el texto exacto del formulario de consentimiento (tarea de producto, no de arquitectura)
- Se recomienda revisión legal del texto final de ambas licencias antes de publicar el proyecto
