# ADR-003: Modelo de datos con PostGIS

## Contexto

El proyecto necesita anclar historias a lugares geográficos concretos, permitir búsquedas por proximidad ("historias cerca de mí") y soportar distintos tipos de contenido narrado (texto, audio, foto — vídeo pospuesto a fase posterior). El modelo debe ser sencillo de entender para contribuidores nuevos, sin sacrificar las capacidades geoespaciales que son el núcleo del producto.

## Decisión

Usar **PostgreSQL con la extensión PostGIS**, con un esquema relacional clásico donde la tabla `places` almacena geometría nativa (`geography(Point, 4326)`) en vez de simples columnas `latitude`/`longitude` sueltas.

### Por qué `geography` y no dos columnas float

Guardar lat/lng como floats obliga a calcular distancias "a mano" con fórmulas trigonométricas (Haversine) en cada consulta, sin poder usar índices espaciales. Con `geography(Point, 4326)` y un índice **GiST**, consultas como "dame las 20 historias más cercanas a este punto" se resuelven de forma nativa y eficiente, incluso con cientos de miles de registros.

## Por qué PostgreSQL y no MySQL / MariaDB / MongoDB

**Factor decisivo: soporte geoespacial.** PostGIS es, con diferencia, la extensión geoespacial más madura y completa del ecosistema open source (tipos de dato espaciales nativos, funciones como `ST_DWithin`/`ST_Distance`/`ST_Contains`, índices GiST eficientes) y es el estándar de facto — cualquier contribuidor con experiencia en geolocalización ya lo conoce.

- **MySQL / MariaDB**: tienen soporte espacial (`ST_Distance_Sphere`, índices `SPATIAL`), pero notablemente menos completo que PostGIS — menos funciones, menos tipos de geometría avanzados, peor rendimiento en consultas complejas. Válido para "cerca de mí" básico, insuficiente si en el futuro se necesitan consultas por polígonos (ej. límites de barrio) o rutas.
- **MongoDB**: soporte geoespacial decente (`$geoNear`, índices `2dsphere`), pero el modelo de datos del proyecto es fundamentalmente relacional (historias → lugares → autores → tags → media, con necesidad de JOINs e integridad referencial). Forzar eso a documentos NoSQL añade complejidad sin ninguna ventaja real, al no existir un problema de escala masiva o esquema cambiante que lo justifique.

**Otros factores a favor de PostgreSQL:**
- Búsqueda de texto completo integrada (`tsvector`) si en el futuro se quiere buscar por contenido de las historias, sin añadir otra pieza de infraestructura
- Columnas `JSONB` indexables para flexibilidad puntual tipo NoSQL sin renunciar a lo relacional
- Buen soporte en proveedores gestionados (Supabase, Neon, Render, DigitalOcean...), sin atar el proyecto a uno concreto
- Licencia permisiva tipo MIT/BSD, sin las dudas de licenciamiento asociadas a MySQL (Oracle) — más alineado con el espíritu 100% abierto del proyecto. MariaDB no tiene ese problema de licencia, pero sigue sin PostGIS

**Cuándo NoSQL tendría sentido**: si el proyecto evolucionara hacia historias con esquema muy variable campo a campo, o volumen de escritura masivo sin relaciones. No es el caso aquí: las historias comparten estructura clara y las relaciones son el núcleo del modelo.

## Esquema propuesto

```sql
-- Extensión necesaria (una sola vez por base de datos)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Usuarios
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT UNIQUE NOT NULL,
    display_name    TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT 'contributor'
                    CHECK (role IN ('contributor', 'curator', 'admin')),
    preferred_lang  TEXT DEFAULT 'es',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lugares
CREATE TABLE places (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    place_type      TEXT NOT NULL
                    CHECK (place_type IN ('barrio', 'pueblo', 'edificio', 'paraje', 'otro')),
    description     TEXT,
    location        GEOGRAPHY(Point, 4326) NOT NULL,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice espacial: imprescindible para consultas de proximidad eficientes
CREATE INDEX idx_places_location ON places USING GIST (location);

-- Historias
CREATE TABLE stories (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    place_id            UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    author_id           UUID NOT NULL REFERENCES users(id),
    narrator_name       TEXT,              -- puede diferir del autor (ej. "mi abuelo José")
    narrator_relation   TEXT,              -- ej. "abuelo", "vecino", opcional
    title               TEXT NOT NULL,
    transcript          TEXT,              -- transcripción manual, opcional
    category            TEXT NOT NULL
                        CHECK (category IN ('anecdota', 'leyenda', 'oficio', 'tradicion', 'evento', 'otro')),
    decade_approx       INTEGER,           -- ej. 1970, para ubicar temporalmente la historia
    original_language   TEXT DEFAULT 'es',
    license             TEXT NOT NULL DEFAULT 'CC-BY-SA-4.0',
    status              TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'pending_review', 'published', 'rejected')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at        TIMESTAMPTZ
);

CREATE INDEX idx_stories_place ON stories(place_id);
CREATE INDEX idx_stories_status ON stories(status);

-- Archivos multimedia asociados a una historia
CREATE TABLE media_assets (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id            UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    media_type          TEXT NOT NULL CHECK (media_type IN ('audio', 'photo')),  -- 'video' se añade en fase posterior
    storage_key         TEXT NOT NULL,     -- ruta/key en el bucket R2, no la URL completa
    duration_seconds    INTEGER,           -- solo aplica a audio
    processing_status   TEXT NOT NULL DEFAULT 'pending'
                        CHECK (processing_status IN ('pending', 'processing', 'done', 'failed')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_media_story ON media_assets(story_id);

-- Etiquetas libres
CREATE TABLE tags (
    id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name    TEXT UNIQUE NOT NULL
);

CREATE TABLE story_tags (
    story_id    UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    tag_id      UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (story_id, tag_id)
);
```

## Consultas típicas que este modelo resuelve bien

**Historias publicadas cerca de un punto (radio de 5km), ordenadas por distancia:**
```sql
SELECT s.id, s.title, p.name AS place_name,
       ST_Distance(p.location, ST_MakePoint(:lng, :lat)::geography) AS distance_m
FROM stories s
JOIN places p ON p.id = s.place_id
WHERE s.status = 'published'
  AND ST_DWithin(p.location, ST_MakePoint(:lng, :lat)::geography, 5000)
ORDER BY distance_m
LIMIT 20;
```

**Historias pendientes de moderación:**
```sql
SELECT * FROM stories WHERE status = 'pending_review' ORDER BY created_at;
```

## Decisiones de diseño relevantes

1. **`storage_key` en vez de URL completa** en `media_assets` — desacopla el modelo de datos del proveedor de storage concreto (R2, S3, etc.). La URL final se construye en la capa de aplicación, no se guarda hardcodeada.

2. **`license` por historia, no global** — cada narrador puede en teoría elegir su licencia, aunque el valor por defecto sea `CC-BY-SA-4.0`. Esto es importante porque algunas familias podrían querer condiciones distintas (ej. no uso comercial de terceros, aunque el proyecto en sí no lucre).

3. **`status` con estado de moderación explícito** — nada se publica automáticamente. Aunque al principio la moderación sea manual y la haga una sola persona, el modelo ya contempla el flujo correcto desde el día 1.

4. **Sin tabla de "video" activa todavía** — el `CHECK` en `media_type` deliberadamente no incluye `'video'` aún, como recordatorio en el propio esquema de que esa fase no ha empezado. Se añade con una migración simple cuando toque.

5. **UUIDs como claves primarias** — mejor que IDs autoincrementales para un proyecto distribuido/open source: evita colisiones si en algún momento hay múltiples entornos (desarrollo local de cada contribuidor) y no revela volumen de datos por la URL.

## Migraciones

Se gestionan con una herramienta de migraciones versionadas desde el primer commit (independientemente del lenguaje de backend elegido: Alembic si es Python, golang-migrate si es Go, etc.), nunca modificando el esquema a mano en producción.

## Consecuencias

- Cualquier lenguaje/framework de backend que se elija en el ADR-002 debe tener soporte maduro de PostGIS (todos los candidatos evaluados lo tienen)
- Las consultas de proximidad quedan resueltas de forma eficiente sin lógica geoespacial manual en la aplicación
- El modelo queda listo para fase de vídeo sin necesidad de rediseño, solo una migración aditiva
