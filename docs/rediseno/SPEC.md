# Resumen del diseño «Placa y registro»

Está extraído de `bundle.html`. Si este resumen y el diseño no coinciden, gana el diseño. El código completo para Flutter está en la sección **Handoff Flutter** de `bundle.html`.

## La idea

Mezcla dos propuestas:

- **«Cal y añil»** aporta la luz, el color, la tipografía legible y las placas de azulejo del mapa.
- **«Registro»** aporta la ficha con pestaña y número, los datos escritos a máquina y los sellos.

El lugar se señala con placas y la historia se guarda como ficha.

Reglas de la mezcla:

- Una sola tipografía de lectura. La de máquina nunca va en párrafos.
- Mayúsculas solo dentro de los sellos.
- Radios casi rectos: 2 en fichas y campos, 4 en botones y placas.
- Nada de sombras difusas ni blur: sombras sólidas de 2 a 6 px.
- Cada estado lleva texto e icono, no solo color.
- Modo claro por defecto, porque es el que mejor lee una persona mayor de día. El oscuro sigue la preferencia del sistema.

## Color: `VdlColors` (ThemeExtension)

| Token | Nombre | Uso | Claro | Oscuro |
|---|---|---|---|---|
| `cal` | Cal | Fondo de la app | `#F5F6F3` | `#11141C` |
| `azulejo` | Azulejo | Superficies: fichas, hojas, campos | `#FFFFFF` | `#1A1F2B` |
| `ficha` | Ficha | Superficie hundida: reproductor, licencia | `#F7F8F4` | `#161A24` |
| `tinta` | Tinta | Texto y bordes fuertes | `#1B1F2A` | `#E9EBF2` |
| `piedra` | Piedra | Texto secundario | `#5A6070` | `#A9B0C2` |
| `filete` | Filete | Líneas decorativas, deshabilitado | `#C9CDD6` | `#343B4D` |
| `anil` | Añil | Acción principal, enlaces, selección | `#2638A8` | `#9DAAF2` |
| `anilHondo` | Añil hondo | Pulsado, foco, títulos de lugar | `#18246E` | `#C3CBF7` |
| `anilVelo` | Velo añil | Fondo de lo seleccionado | `#E6E9F7` | `#252C45` |
| `ocre` | Ocre puerta | Recuento en placas, sitio nuevo, anillo de foco | `#E0A22B` | `#F0B847` |
| `ocreTinta` | Ocre tinta | Texto «En revisión», avisos | `#8A5A00` | `#F0B847` |
| `carmin` | Carmín de sello | Sellos de permiso, peligro, error, grabar | `#A3203A` | `#F08A9A` |
| `verde` | Verde contraventana | Éxito, «Publicada» | `#2F6B4F` | `#7CC4A0` |
| `sombraBoton` | Sombra de placa | Sombra sólida desplazada de los botones | `#18246E` | `#05070B` |

Correspondencia con `ColorScheme`:

| `ColorScheme` | Token |
|---|---|
| `primary` | `anil` |
| `secondary` | `ocre` |
| `error` | `carmin` |
| `surface` | `azulejo` |
| `onSurface` | `tinta` |
| `surfaceContainerHighest` | `ficha` |
| `outline` | `tinta` |
| `outlineVariant` | `filete` |

`onPrimary` y `onError` son blanco en claro y `cal` en oscuro.

Contrastes comprobados en el diseño (claro y oscuro):

| Par | Claro | Oscuro |
|---|---|---|
| Tinta / Cal | 15,2 | 15,5 |
| Piedra / Azulejo | 6,3 | 7,6 |
| Añil / Cal | 8,8 | 8,3 |
| Sobre añil / Añil | 9,5 | 8,3 |
| Sobre ocre / Ocre | 7,4 | 10,2 |
| Ocre tinta / Cal | 5,5 | 9,1 |
| Carmín / Azulejo | 7,4 | 6,9 |
| Verde / Azulejo | 6,3 | 8,1 |

## Tipografía

**Atkinson Hyperlegible Next** (400, 700 y 800) es la letra de todo lo que se lee. **Courier Prime** (400 y 700) es solo para datos: lugar, época, tiempos y el «Nº». Las dos van empaquetadas en `assets`.

| Token | Tamaño | Interlineado | Peso | `TextTheme` | Uso |
|---|---|---|---|---|---|
| display | 44 (32 en móvil) | 1.12 | 800 | `displaySmall` | Titular de la portada |
| titulo | 34 (28 en móvil) | 1.12 | 800 | `headlineMedium` | Título de pantalla y de ficha |
| seccion | 23 | 1.2 | 800 | `titleLarge` | Encabezado de sección, diálogo |
| tarjeta | 21 (19 compacta) | 1.2 | 800 | `titleMedium` | Título en tarjeta |
| lectura | 19 | 1.65 | 400 | `bodyLarge` | Texto de una historia |
| cuerpo | 18 | 1.5 | 400 | `bodyMedium` | Texto general |
| apoyo | 16 | 1.5 | 400 | `bodySmall` | Ayudas y metadatos secundarios; es el mínimo |
| boton | 18 | — | 800 | `labelLarge` | Botón grande |
| datos | ver diseño | — | — | Courier Prime | «Nº 0142 · Años 50 · 4:12» |
| sello | 15 | — | — | Courier Prime, mayúsculas | Solo dentro de los sellos |

Tamaño de letra: se respeta el del sistema y se multiplica por el ajuste propio (Normal 1.0, Grande 1.2, Muy grande 1.4):

```dart
MediaQuery(
  data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * prefs.escala)),
  child: app,
)
```

## Medidas de los componentes

| Componente | Medidas |
|---|---|
| Botón grande / medio | Alto 56 / 48. Padding horizontal 22 / 16. Radio 4. Borde 2. Sombra sólida desplazada 2,2. Al pulsar se hunde 2 px y pierde la sombra. Sin onda (`NoSplash`). |
| Botón reproducir | 64 px. Barra con zona táctil de 48. Saltos de ±10 s y velocidad. |
| Botón grabar | 96 × 96. Círculo carmín. Borde de 4 azulejo más 2 carmín. |
| Campo | Alto mínimo 52. Borde de 2 tinta. Foco con borde de 3 añil hondo. Radio 2. |
| Casilla | 28 × 28 dentro de una zona táctil de 48. Radio 2. |
| Chip de tipo | Icono y nombre. El seleccionado lleva relleno añil y una marca ✓. |
| Ficha | Borde de 1,5 tinta. Radio 2. Sombra 3,3. Pestaña «Nº» de 15 px sobre el borde. |
| Sello | Borde de 2 (discontinuo en revisión y en retirada). Girado −3°, estático. Courier 15 en mayúsculas. |
| Placa del mapa | Alto 36 más una cola de 13. Texto 14, peso 800. Recuento en un círculo ocre de 22. La seleccionada se invierte. Zona táctil de al menos 48. |
| Hoja inferior | Radio superior 10. Borde superior de 2 añil. Tres alturas: plegada de 76, vista previa, y lista al 78 %. |
| Barra inferior | Alto 68 más la zona segura (34 en iPhone, 24 en Android con gestos). Icono 26. Etiqueta 15. Marca superior de 5 px en la pestaña activa. |
| Diálogo | Ancho máximo 480. Borde 2. Sombra 6,6. Velo sólido al 62 %. |
| Notificación breve | Alto mínimo 60. Dura 6 s. Acción subrayada. |
| Movimiento | 200 ms al subir la hoja y al cambiar de paso. Cero con movimiento reducido. |

## Mapa

- Paquetes `flutter_map` y `latlong2`, con teselas raster de OpenStreetMap. La atribución tiene que verse siempre.
- Fase 1: `ColorFiltered` sobre el `TileLayer`, con una matriz que pasa a gris y tiñe un poco de añil (claro) y otra para oscuro. Las matrices exactas están en el handoff. Sin `BackdropFilter`.
- Las manzanas rayadas de los dibujos del diseño son solo ilustración. No hace falta reproducirlas con datos vectoriales.
- Hay una placa por lugar, con el nombre y el número de historias. El sitio nuevo, al tocar un sitio vacío, es un alfiler ocre con un círculo discontinuo.

## Navegación

| Ancho | Disposición |
|---|---|
| Menos de 600 px (móvil) | Barra inferior con Inicio, Mapa, Contar y Cuenta. La moderación se abre desde Cuenta. |
| 600 a 1023 px (tableta) | `NavigationRail` a la izquierda con las 4 secciones, más «Por revisar» para moderadores. El mapa ocupa el resto y la lista va en una hoja. Funciona en vertical y en horizontal. |
| 1024 px o más (web de escritorio, secundaria) | Barra superior con la marca, las secciones y «Contar una historia». Mapa y lista lado a lado, con un panel de 460 px. |

Volver:

- En iOS, con la flecha ‹ y deslizando desde el borde.
- En Android, con la flecha ←, el gesto o el botón Atrás, incluido el atrás predictivo.
- En el asistente, Atrás va al paso anterior. En el paso 1 pregunta «¿Salir sin guardar?».

## Rutas

| Ruta | Pantalla | Sección | Acceso |
|---|---|---|---|
| (primer arranque) | Bienvenida y tamaño de letra | — | Solo la primera vez |
| `/` | Inicio | Inicio | Todos |
| `/mapa` | Mapa, en el centro guardado o en la ubicación | Mapa | Todos |
| `/mapa?lugar=<id>` | Mapa con la vista previa abierta | Mapa | Todos |
| `/historia/<id>` | Ficha. Si no existe: «Esta historia no está» | Mapa | Todos |
| `/contar/sitio`, `/contar/historia`, `/contar/quien`, `/contar/permiso` | Asistente de 4 pasos, con borrador en el dispositivo | Contar | Con cuenta; si no hay sesión, pide entrar al guardar |
| `/contar/hecho` | Confirmación «En revisión» | Contar | Con cuenta |
| `/cuenta` | Rol y «Lo que has dejado» | Cuenta | Con cuenta |
| `/entrar`, `/crear-cuenta` | Acceso | Cuenta | Sin sesión |
| `/revisar`, `/revisar/<id>` | Cola y revisión | Cuenta | `curator` y `admin` |

## Pantallas del diseño

Hay 11, cada una con varios estados. Míralas todas en `bundle.html`, en la sección Pantallas.

1. Bienvenida
2. Inicio
3. Mapa (11 estados)
4. Ficha de historia
5. Contar · 1 Sitio
6. Contar · 2 Historia
7. Contar · 3 Quién
8. Contar · 4 Permiso
9. Contar · Hecho
10. Cuenta
11. Moderación

## Android e iOS

| Aspecto | iOS | Android | Decisión |
|---|---|---|---|
| Navegación principal | Barra inferior propia | Barra inferior propia | La misma en las dos |
| Compartir | Hoja de compartir de iOS | Hoja de compartir de Android | Botón «Compartir» con título y enlace. «Copiar enlace» como segunda opción. |
| Grabar con el móvil bloqueado | Audio en segundo plano | Servicio en primer plano con notificación fija | Nunca se corta al bloquear. Pausar y Terminar también desde fuera de la app. |
| Llamada entrante | Interrupción de la sesión de audio | Pérdida del foco de audio | Se pausa sola, guarda lo grabado y lo dice. |
| Escuchar | Controles en la pantalla de bloqueo | Notificación multimedia | Título y narrador, saltos de 10 s. Sigue sonando con la pantalla apagada. |
| Ubicación | Aproximada por defecto | Solo `ACCESS_COARSE_LOCATION` | Para «Ir a donde estoy» basta la aproximada. El sitio exacto se marca tocando el mapa. |
| Tamaño de letra | Dynamic Type | Tamaño de fuente del sistema | Se respeta y se suma el ajuste propio. |
| Desplazamiento | Rebote | Estiramiento | La física de cada plataforma (Flutter lo hace solo). |
| Vibración | Taptic | Háptica | Breve al empezar y al terminar de grabar, y al publicar. Nunca en bucle. |
| Subir un audio | Selector de Archivos | Selector de documentos | Sin pedir permiso de fotos ni de almacenamiento. |

Permisos:

| Permiso | Cuándo se pide | Si se deniega |
|---|---|---|
| Micrófono | Al pulsar grabar por primera vez, tras una pantalla propia que lo explica | Ruta exacta de Ajustes, botón «Abrir Ajustes» y alternativa «Escribirla en su lugar» |
| Ubicación aproximada | Al pulsar «Aquí» o «Ir a donde estoy». Nunca al abrir la app | Aviso con «Abrir Ajustes». Se puede buscar el pueblo o el barrio |
| Avisos (fuera de alcance) | En «Gracias», después de guardar la primera historia | Nada; el estado se ve en Cuenta |

Paquetes propuestos por el diseño (ninguno obliga a usar servicios de Google):

```
flutter_map + latlong2        # mapa OSM
record                        # grabar (m4a/AAC, 64 kbps mono: ~0,5 MB por minuto)
audio_session                 # interrupciones: llamadas, otros audios
just_audio + audio_service    # escuchar y controles en la pantalla de bloqueo
permission_handler            # permisos + openAppSettings()
geolocator                    # ubicación aproximada
share_plus                    # hoja de compartir del sistema
app_links                     # Universal Links / App Links (fuera de alcance por ahora)
drift                         # borradores y cola de subida (fase 3)
background_downloader         # subidas en segundo plano (fase 3)
file_picker                   # elegir un audio existente (sin permisos)
flutter_local_notifications   # notificación de grabación (Android)
unifiedpush                   # avisos sin Google (fuera de alcance por ahora)
```

Ya están en el proyecto: `flutter_map`, `record`, `just_audio`, `geolocator`, `file_picker` y `shared_preferences`.

En `Info.plist`, los textos de micrófono y de ubicación salen del diseño:

- `NSMicrophoneUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSLocationDefaultAccuracyReduced`
- `UIBackgroundModes` con `audio`

En `AndroidManifest.xml`:

- `INTERNET`
- `RECORD_AUDIO`
- `ACCESS_COARSE_LOCATION`
- `POST_NOTIFICATIONS`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_MICROPHONE`
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK`

Comprueba la lista exacta en el handoff.

Icono: una placa de azulejo con las barras de una voz y el punto ocre del recuento («un lugar que habla»), sin letras, para que se lea a 29 px. Versiones para iOS en claro, oscuro y teñido, y para Android adaptativo, normal y monocromo. Pantalla de arranque: fondo cal e icono centrado, sin animación.

## Textos clave (literales)

- Portada: «Las historias de cada sitio, contadas por quien las vivió.» / «Graba o escribe lo que pasó, márcalo en el mapa y quedará guardado para quien venga después.»
- Bienvenida: «¿Cómo lees mejor?» / «Puedes cambiarlo cuando quieras en Cuenta.» / «Empezar».
- Antes de pedir el micrófono: «Para grabar, la app necesita el micrófono» / «Solo se usa mientras grabas. Ahora tu móvil te lo preguntará: pulsa «Permitir».».
- Antes de pedir la ubicación: «Para llevarte a donde estás» / «Basta con saber más o menos dónde estás. Ahora tu móvil te lo preguntará.».
- Llamada entrante: «Se ha pausado por una llamada. Lo grabado está a salvo: pulsa «Seguir» cuando quieras.».
- Permiso: «Quien la cuenta me ha dado permiso para publicarla» / «Es obligatorio. Sin permiso, la historia no se puede guardar.».
- Hecho: «Gracias. Tu historia está guardada.» / «Ahora la revisa una persona del equipo. Cuando la publique, aparecerá en el mapa. Mientras tanto, puedes corregirla desde tu cuenta.».
- Sesión: «Tu sesión ha caducado» / «Entra otra vez. Lo que estabas haciendo sigue guardado.».
- Acceso: «El email o la contraseña no coinciden» / «Revísalos y vuelve a intentarlo.».
- Moderación: «¿Publicar en el mapa?» / «Sí, publicar en el mapa» / «Publicada. Ya está en el mapa.» / «¿Rechazar esta historia?» / «Sí, rechazar» / «Rechazada. No llegará al mapa.» / «¿Retirar del mapa?» / «Retirada. Ya no está en el mapa.».

El resto de textos de cada estado se copian del diseño tal cual.
