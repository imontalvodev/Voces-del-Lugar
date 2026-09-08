# ADR-002: Lenguaje/framework de backend y framework de frontend

## Contexto

El backend debe exponer una API que soporte consultas geoespaciales sobre PostGIS (ver ADR-003), y la subida/gestión de archivos multimedia (fotos, audio, y vídeo en fase posterior) hacia almacenamiento tipo R2. El frontend debe cubrir apps Android/iOS y web, con captura de cámara/audio y visualización de mapas.

El proyecto es open source, sin ánimo de lucro, y prioriza sostenibilidad a largo plazo con equipo voluntario (ver VISION.md). Esto pesa tanto como el rendimiento técnico puro: el tamaño del pool de contribuidores potenciales y el coste de mantenimiento con equipo pequeño son criterios de decisión, no solo velocidad o footprint de recursos.

## Decisión: backend

**Python + FastAPI.**

### Alternativas consideradas

- **Go**: mejor footprint de memoria/CPU (hosting más barato) y mejor concurrencia nativa (goroutines) para subidas de media, pero pool de contribuidores voluntarios notablemente menor que Python/JS, y ecosistema de librerías para procesado de imagen/audio/vídeo más limitado (se apoya en llamadas a `ffmpeg` en vez de librerías nativas ricas).
- **Node.js**: hubiera permitido compartir tipos TypeScript con un frontend React Native (ver nota de `shared/` en ADR-004), pero soporte PostGIS menos maduro que Python/Go, y tareas CPU-bound (procesado de media) bloquean el event loop igual que en Python sin arquitectura de colas.
- **Python + FastAPI (elegido)**: ecosistema geoespacial más maduro del open source (GeoAlchemy2, Shapely — mismo lenguaje que el ecosistema QGIS), librerías ricas para media (Pillow, ffmpeg-python), y crítico para el roadmap: Fase 2 de VISION.md contempla transcripción automática, terreno donde Python (Whisper y similares) no tiene comparación real en otros lenguajes. Mayor pool de contribuidores voluntarios que Go, alineado con el valor de apertura/crecimiento comunitario.

**Mitigación del contra conocido (GIL)**: tareas CPU-bound de procesado de media (resize, transcodificado) se delegan a una cola de trabajo en background (Celery/RQ/arq), no se ejecutan en el proceso de la API — arquitectura ya prevista por `processing_status` en la tabla `media_assets` (ADR-003).

## Decisión: frontend

**Flutter.**

### Alternativas consideradas

- **React Native + Next.js**: su ventaja decisiva era compartir TypeScript con un backend Node — al elegir Python como backend, esa sinergia desaparece y el eje de comparación cambia. Expo baja la barrera de entrada a colaboradores nuevos, y JS/TS tiene mayor pool de desarrolladores que Dart. Requiere mantener dos bases de código (mobile RN + web Next.js) salvo uso de react-native-web.
- **Flutter (elegido)**: un único código fuente compila a Android, iOS y Web, simplificando el monorepo a una sola carpeta `apps/flutter/` (ver nota condicional ya prevista en ADR-004). Motor de renderizado propio (Skia/Impeller) da rendimiento más consistente para el caso de uso central de la app (cámara + GPS + mapa simultáneos). Plugins maduros y bien mantenidos para exactamente lo que necesita el proyecto: `camera`, `record`/`flutter_sound`, `geolocator`, `flutter_map`/`maplibre_gl` (mapas basados en OpenStreetMap, sin coste ni dependencia de Google Maps).

**Contra aceptado conscientemente**: pool de contribuidores voluntarios con experiencia Dart es menor que JS — riesgo real frente al valor de "apertura"/crecimiento comunitario de VISION.md. Se acepta porque, con backend ya fijado en Python, ningún frontend comparte lenguaje con el backend de todos modos, así que el criterio decisivo pasa a ser menor superficie de mantenimiento a largo plazo con equipo pequeño, no compartición de tipos.

## Consecuencias

- Backend: Python 3.x + FastAPI, con Alembic para migraciones (ya anticipado como opción en ADR-003), y cola de trabajo (a definir: Celery/RQ/arq) para procesado asíncrono de media.
- Frontend: Flutter único para mobile (Android/iOS) y web, con mapas vía `flutter_map` o `maplibre_gl` sobre tiles OpenStreetMap/MapLibre, evitando coste y dependencia de proveedores de mapas comerciales.
- La estructura de monorepo de ADR-004 pasa de la rama condicional "si se elige Flutter" a definitiva: `apps/mobile` y `apps/web` se consolidan en `apps/flutter/`, y la carpeta `shared/` deja de ser necesaria (no hay tipos que compartir entre Python y Dart). **Pendiente**: actualizar ADR-004 para reflejar esto como decisión final, no como rama condicional.
- Cualquier proveedor de hosting/despliegue debe soportar un servicio Python ASGI (Uvicorn/Gunicorn) para el backend.
