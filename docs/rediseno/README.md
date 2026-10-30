# Rediseño «Placa y registro»: guía para el agente

Este documento es el punto de entrada para el agente de Claude Code que va a aplicar el nuevo diseño de la app. Léelo entero antes de tocar nada.

Documentos de esta carpeta:

| Fichero | Para qué |
|---|---|
| `README.md` | Este documento: contexto, ramas, entorno y reglas |
| `PLAN.md` | Fases y tareas con sus criterios de aceptación, en orden |
| `SPEC.md` | Resumen del diseño: tokens, tipografía, medidas, navegación, rutas, permisos y paquetes |
| `PROMPT.md` | El prompt con el que se arranca la sesión del agente |
| `bundle.html` | El diseño completo hecho con Claude Design. Es la fuente de verdad. |

## Qué es el proyecto

Voces del Lugar es un archivo colectivo y libre de historia oral local anclado al mapa: la gente graba o escribe lo que le contaron sus mayores sobre un sitio y cualquiera lo descubre después en el mapa. Lee `docs/VISION.md` antes de empezar. Dos valores mandan sobre cualquier decisión de interfaz:

- **Personas por encima de la tecnología.** Tiene que poder usarlo alguien de 75 años con poca soltura digital.
- **Respeto y consentimiento.** Quien narra decide qué se publica; si ha fallecido, da el permiso la familia.

## Qué hay que hacer

Sustituir la identidad visual actual («crepúsculo»: cielo con shader, paisaje 3D, farolas, paneles de cristal, Instrument Serif y Bricolage Grotesque) por el sistema **«Placa y registro»** que está en `bundle.html`.

El rediseño incluye:

- un tema claro por defecto y otro oscuro;
- el tamaño de letra propio de la app;
- las 11 pantallas con sus estados;
- el comportamiento nativo en Android e iOS (permisos, compartir, grabar con el móvil bloqueado…);
- unos pocos cambios de backend.

**Prioridad de plataformas:** las apps de Android e iOS van primero. La web es secundaria y sirve para quien quiera ver el archivo desde casa. Todo sale del mismo código Flutter, en `apps/flutter/`.

El plan detallado está en `PLAN.md`.

## Ramas: dónde va cada cosa

| Trabajo | Rama | Notas |
|---|---|---|
| Frontend Flutter (`apps/flutter/`) | `mejoras-front` | Ya contiene el despliegue para el homelab y las mejoras de rendimiento y de enlaces. Trabaja encima. |
| Backend (`backend/`) | `back` | Hoy tiene el mismo contenido que `develop`. |
| Estos documentos | `develop` | Si tienes que actualizarlos, hazlo en `develop`. |

En la práctica conviene tener un worktree por rama:

```bash
git fetch origin
git worktree add ../vdl-front mejoras-front   # frontend
git worktree add ../vdl-back back             # backend
# los documentos se leen desde la copia en develop, o con:
git show origin/develop:docs/rediseno/SPEC.md
```

Reglas de git:

- Nunca hagas push a `main` ni fusiones nada en `main`.
- Nunca reescribas historia publicada: nada de `push --force`, ni rebase de lo que ya está subido.
- Nunca uses `git stash` sin más. Si necesitas apartar trabajo, haz un commit temporal.
- No cambies la configuración de git.
- Los commits siguen Conventional Commits, en español y en imperativo, por ejemplo `feat: placas de azulejo como marcadores del mapa`. El cuerpo explica el porqué cuando no es obvio. Haz commits pequeños: uno por pieza o por pantalla.
- Termina cada commit con la línea de atribución `Co-Authored-By` que te indique tu entorno.
- Sube cada rama cuando una fase quede verde. Los PR, solo si el usuario los pide: `mejoras-front` va a `front` y `back` va a `develop`.
- Las dos ramas suelen ir a la vez: el frontend usará campos nuevos que todavía no existen en `back`. Haz el frontend tolerante a que falten; si `number` no viene, no se pinta el «Nº».

## Entorno

En la máquina tienes el repositorio, Flutter y Android Studio con emulador.

Backend y base de datos, desde el worktree de `back`:

```bash
docker compose up -d db                       # PostGIS en el puerto 5433
python3 -m venv .venv && .venv/bin/pip install -r backend/requirements-dev.txt
cd backend && ../.venv/bin/alembic upgrade head
../.venv/bin/uvicorn voces.main:app --reload --app-dir src --host 0.0.0.0 --port 8001
```

- Usa Python solo desde `.venv/bin/...`, nunca el del sistema.
- La primera cuenta que se registra es administradora y puede publicar. Crea unas cuantas historias de ejemplo con el contenido de `bundle.html` («La noche que se heló la fuente», «El último herrero de la calle Ancha», etc.). Así las pantallas se ven con datos reales.

App en el emulador de Android, desde el worktree de `mejoras-front`:

```bash
cd apps/flutter
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE=http://10.0.2.2:8001
```

`10.0.2.2` es el ordenador visto desde el emulador. En web: `flutter run -d chrome --dart-define=API_BASE=http://localhost:8001`.

Comprobaciones antes de cada commit:

```bash
cd apps/flutter && flutter analyze && flutter test
cd backend && ../.venv/bin/pytest            # necesita la base levantada
```

## Cómo leer `bundle.html`

Es una página React ya compilada en un único fichero de unos 440 KB. Las pantallas y los componentes están dentro del JavaScript; el HTML de fuera no dice nada. Hay tres formas de leerla:

1. **Recomendada: abrirla en un navegador.**
   - Hay dos herramientas posibles: `agent-browser`, si está instalado, o el skill `claude-in-chrome`. Abre `file://<ruta>/docs/rediseno/bundle.html` a 1440 px de ancho.
   - Arriba hay un índice con las secciones: La mezcla, Android e iOS, Tokens, Componentes, Pantallas, Flujos, Navegación y Handoff Flutter.
   - También arriba hay dos interruptores, Claro/Oscuro y Aa/Aa+/Aa++.
   - En **Pantallas** hay un selector «iPhone y Android / Web de escritorio». Debajo, una pestaña por pantalla (Bienvenida, Inicio, Mapa, Ficha de historia, Contar · 1 Sitio, Contar · 2 Historia, Contar · 3 Quién, Contar · 4 Permiso, Contar · Hecho, Cuenta y Moderación) y, para cada una, botones con sus estados. Cada estado se ve en iPhone (393×852) y en Android (412×915) a la vez.
   - Haz capturas de cada pantalla y de cada estado antes de implementarlos, y compara con ellas al terminar.
2. **Handoff Flutter:** esa sección trae código listo para usar: `VdlColors` (ThemeExtension), `vdlTheme()` (ThemeData), los puntos de ruptura, el filtro de color del mapa, `pubspec`, `Info.plist`, `AndroidManifest` y la tabla de medidas de cada componente. Cópialo desde la página renderizada; no lo reconstruyas de memoria.
3. **Sin navegador:** los textos y el código están como cadenas en el `<script type="module">`. Sácalos con un script de Python que busque literales con caracteres españoles y plantillas que empiecen por `// lib/` o `# pubspec`.

`SPEC.md` resume lo esencial, pero si hay contradicción entre los dos, gana `bundle.html`.

## Estado actual del frontend

Todo está en `apps/flutter/lib/`:

- `main.dart`:
  - `usePathUrlStrategy()`, para que las URLs no lleven `#`;
  - las fuentes van empaquetadas (`useBundledFonts()`);
  - `onGenerateRoute: vocesRoute`, para entrar directo a `/historia/<id>`.
- `shell.dart`: las secciones (inicio, mapa, cuenta), con un dock flotante y el cielo de fondo.
- `pages/`: `home_page`, `map_page`, `story_page`, `compose_page` (asistente de 4 pasos) y `account_page` (cuenta, mis historias y cola de moderación).
- `ui/`:
  - Se va: `sky.dart` con `shaders/dusk.frag`, `voice_terrain.dart`, `dusk_tiles.dart`, `blur_gate.dart`, `recent_activity.dart` y la parte de cristal de `kit.dart`.
  - Se rehacen: `tokens.dart`, `kit.dart`, `story_card.dart` y `audio.dart`.
- `api.dart`: el cliente de la API (`VocesApi`, `StoryPin`, `Account`). `links.dart`: los enlaces `/historia/<id>` y la página «Esta historia no está». `story_format.dart`: las etiquetas de tipo, época y licencia.
- `test/`: 55 tests. Muchos dependen de la interfaz actual y habrá que reescribirlos. Los de `api_test.dart`, `links_test.dart` y `locate_test.dart` deberían seguir valiendo casi enteros.

La lógica que ya funciona se conserva y solo cambia la interfaz:

- la API;
- los enlaces;
- grabar, adjuntar y subir el audio, con reintento sin duplicar;
- la búsqueda de lugares;
- la moderación.

El contrato de la API está en `docs/api/mvp.md`.

## Reglas de diseño que no se negocian

- Nada de `BackdropFilter`, blur ni sombras difusas. Las sombras son `BoxShadow` con `blurRadius: 0`, desplazadas entre 2 y 6 px.
- Nada de animaciones continuas ni `Ticker` permanentes. El medidor de voz se repinta solo cuando llega un nivel nuevo del micrófono, unas 10 veces por segundo.
- Una sola tipografía para leer (Atkinson Hyperlegible Next). Courier Prime solo para datos, nunca en párrafos. Mayúsculas solo dentro de los sellos.
- Cada estado lleva texto e icono, nunca solo color. Zona táctil de 48 px como mínimo. Contraste AA como mínimo.
- Se respeta el tamaño de letra del sistema y, además, el ajuste propio: Normal 1.0, Grande 1.2, Muy grande 1.4.
- Se respeta `MediaQuery.disableAnimationsOf`.
- Nada que solo funcione con un gesto: todo lo que se arrastra (la hoja, el mapa) tiene también un botón.
- Las fuentes van empaquetadas en `assets`, nunca descargadas por red.
- Español neutro, tuteo y frases cortas. Nunca voseo («vos», «tenés»…). Los botones dicen lo que hacen. Los mensajes de moderación son exactamente «Publicada. Ya está en el mapa.» y «Rechazada. No llegará al mapa.».
- Sin métricas sociales, sin analítica de terceros y sin servicios de Google obligatorios.

## Cómo trabajar

1. Sigue `PLAN.md` en orden y empieza cada fase leyendo su sección en `bundle.html`.
2. Primero el test, después el código: para cada comportamiento nuevo, un test de widget o unitario que falle antes de implementarlo.
3. Comprueba lo visual en el emulador y compáralo con las capturas del diseño, en claro y en oscuro y con Aa++.
4. Al terminar cada fase:
   - deja verdes `flutter analyze` y `flutter test` (y `pytest` si has tocado el backend);
   - sube la rama;
   - resume al usuario qué has hecho, qué queda y qué no has podido probar. Por ejemplo, en el emulador no se puede probar de verdad grabar con el móvil bloqueado ni una llamada entrante.
5. Si algo del diseño choca con la API o es inviable en Flutter, no lo improvises: apúntalo y pregunta.
