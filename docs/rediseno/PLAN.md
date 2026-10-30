# Plan del rediseño

Las fases van en orden. Las tareas de backend (B) se pueden hacer en paralelo con las primeras de frontend. Cada tarea termina con tests en verde y un commit.

Ramas: el frontend va en `mejoras-front` y el backend en `back` (ver `README.md`).

Tiempos orientativos de trabajo del agente: unos 6 días para las fases B y 0 a 2, y de 2 a 3 días más para la fase 3.

---

## Fase B: backend (rama `back`), medio día

El diseño enseña datos que la API todavía no da.

### B1. Número de ficha

- **Qué:** cada historia tiene un número correlativo que se ve como «Nº 0142» en tarjetas, fichas y la cola de moderación.
- **Cómo:**
  - Nueva columna `number`, entera, única, no nula y generada por secuencia.
  - Migración de Alembic que numere las historias existentes por fecha de creación.
  - Se expone como `number` en todas las respuestas de historia.
- **Aceptación:**
  - Las historias nuevas reciben el siguiente número.
  - Las existentes quedan numeradas por antigüedad.
  - `pytest` cubre las dos cosas.
  - `docs/api/mvp.md` queda actualizado.

### B2. Quién la recogió

- **Qué:** la ficha muestra «Recogida por: Lucía Ortega», que es el `display_name` de la cuenta que subió la historia.
- **Cómo:** añadir `author_name` a la respuesta de historia, junto a `author_id`.
- **Aceptación:**
  - El campo aparece en el detalle, en `mine`, en `review` y en `map`.
  - Hay test.
  - El contrato está actualizado.

### B3. Motivo al rechazar (opcional, pregunta antes)

- **Qué:** el diálogo de rechazo deja escribir un motivo, y quien subió la historia lo ve en su cuenta.
- **Cómo:**
  - `POST /stories/{id}/reject` acepta `{ "reason": "..." }` opcional.
  - Se guarda en `rejection_reason` y solo lo ven el autor y los moderadores.
- **Aceptación:** tests de que se guarda y de quién puede verlo.

Fuera de esta fase, sin pedirlo antes: avisos push y enlaces universales. Necesitan dominio, cuentas de Apple y Google, y servidor.

---

## Fase 0: base visual (rama `mejoras-front`), 1 día

### 0.1 Tema

- `lib/theme/vdl_colors.dart` y `lib/theme/vdl_theme.dart`, copiados de la sección Handoff Flutter del diseño.
- `MaterialApp` con `theme`, `darkTheme` y `themeMode: system`.
- **Aceptación:** test de que los colores claro y oscuro coinciden con la tabla de `SPEC.md`.

### 0.2 Fuentes

- Atkinson Hyperlegible Next (400, 700, 800) y Courier Prime (400, 700), empaquetadas como `.ttf` en `assets`.
- Quitar Instrument Serif y Bricolage Grotesque.
- **Aceptación:** test de que no se pide nada por red. Ya existe uno parecido en `widget_test.dart`.

### 0.3 Tamaño de letra

- Preferencia guardada (Normal 1.0, Grande 1.2 o Muy grande 1.4), multiplicada por el tamaño del sistema con `MediaQuery.textScaler`.
- **Aceptación:** test.

### 0.4 Quitar lo viejo

- Fuera `Sky` con el shader, `VoiceTerrain`, `dusk_tiles`, `BlurGate`, `RecentActivity`, `Glass` y `flutter_animate`, si deja de usarse.
- Fuera sus tests.
- **Aceptación:** `flutter analyze` sin avisos.

### 0.5 Piezas comunes

En `lib/ui/`, cada una con sus tests de widget:

- Botón placa en tres variantes: principal, secundario y peligro. Grande de 56 px y medio de 48 px. Al pulsarlo se hunde 2 px y pierde la sombra. Cuando está deshabilitado o cargando, conserva el texto.
- Enlace discreto.
- Campo con la etiqueta siempre visible, la ayuda debajo y el error con icono y texto.
- Chip de tipo con icono y nombre. El seleccionado lleva relleno añil y una marca.
- Sello de estado: En revisión, Publicada, Rechazada, Retirada y Permiso de la familia.
- Casilla y opción de licencia.
- Ficha de historia con pestaña «Nº», datos a máquina y sello opcional. Toda la ficha es un único botón.
- Aviso con borde lateral de color, icono y título.
- Notificación breve de 6 s con acción.
- Diálogo de confirmación sobre un velo sólido.
- Bloques de carga fijos, sin brillo animado, y estado vacío que siempre ofrece algo que hacer.
- Barra inferior de 68 px más la zona segura, con marca superior en la pestaña activa.

Las medidas de cada pieza están en `SPEC.md`.

---

## Fase 1: pantallas (rama `mejoras-front`), 3 días

Un commit por pantalla.

- **Antes de cada pantalla:** captura de todos sus estados en el diseño, en iPhone y en Android.
- **Al terminar cada una:** compararla en el emulador, en claro y en oscuro y con Aa++.

1. **Navegación.**
   - Shell con 4 secciones: Inicio, Mapa, Contar y Cuenta.
   - La disposición cambia según el ancho:
     - menos de 600 px: barra inferior;
     - de 600 a 1023 px: `NavigationRail`;
     - 1024 px o más: barra superior y panel lateral de 460 px.
   - Rutas según la tabla de `SPEC.md`. `/historia/<id>` ya existe en `links.dart`; hay que extender ese mecanismo.
   - El botón Atrás de Android y el deslizar de iOS funcionan en todas las pantallas.
   - En el asistente, Atrás vuelve al paso anterior. En el paso 1 pregunta «¿Salir sin guardar?».
2. **Bienvenida.**
   - Solo en el primer arranque.
   - Selector «¿Cómo lees mejor?» con vista previa del texto.
   - «Empezar».
3. **Inicio.**
   - Marca, titular y las acciones «Dejar una historia» y «Abrir el mapa».
   - «Lo último que se ha publicado», con chips de tipo y fichas.
4. **Mapa.**
   - Teselas de OpenStreetMap con `ColorFiltered`: las matrices claro y oscuro están en el handoff. La atribución tiene que verse siempre.
   - Placas por lugar, con nombre y recuento. La seleccionada se ve invertida.
   - Búsqueda de lugar, botón «Aquí», zoom con + y −.
   - Hoja inferior con tres alturas (plegada de 76 px, vista previa y lista al 78 %) y alternativa con botón a arrastrarla.
   - Los estados del diseño:
     - sitio seleccionado, explorando, historias en esta vista;
     - buscando un lugar, toca un sitio vacío, aquí todavía no hay historias;
     - cargando;
     - antes de pedir la ubicación, permiso de ubicación del sistema, ubicación denegada;
     - sin conexión.
5. **Ficha de historia.**
   - Tabla de datos: Lugar, Tipo, Época, Contada por y Recogida por (B2).
   - Reproductor: botón de 64 px, barra, saltos de ±10 s y velocidad.
   - «Lo que cuenta».
   - Sello de permiso de la familia si el narrador ha fallecido.
   - Botones «Compartir» y «Copiar enlace».
   - Acciones de autor (corregir) y de moderador.
   - «Esta historia no está».
6. **Contar, 4 pasos.**
   - Barra de pasos con sus nombres.
   - Botones fijos abajo que dicen el siguiente paso.
   - Borrador guardado en cada paso: con `shared_preferences` en esta fase, con `drift` en la fase 3.
   - Los pasos:
     - **Sitio.**
     - **Historia:** pestañas Grabar, Escribir y Subir audio. El grabador tiene los estados lista, grabando, en pausa, terminada y sin micrófono, con botón carmín de 96 px y medidor de voz. Después vienen título, tipo y época.
     - **Quién:** nombre, parentesco y «ya ha fallecido».
     - **Permiso:** casilla obligatoria y licencia en lenguaje llano.
   - Si no hay sesión al guardar, pide entrar y continúa sin perder nada.
7. **Contar · Hecho.**
   - «Gracias. Tu historia está guardada.».
   - «Ver lo que he dejado» y «Contar otra historia».
8. **Cuenta.**
   - Entrar y crear cuenta, con los errores exactos del diseño y «Tu sesión ha caducado».
   - Rol y «Lo que has dejado», con sellos.
   - Ajuste de tamaño de letra.
   - Entrada a «Por revisar» para moderadores.
9. **Moderación.**
   - Cola de la más antigua a la más nueva, con orden, Nº y fecha.
   - Revisión con «Publicar en el mapa», «Rechazar» y «Volver a la cola».
   - Diálogos de confirmación; el motivo, si se hace B3.
   - Retirar del mapa.

Al final de la fase, reescribe los tests de pantallas. Como mínimo:

- navegación y rutas;
- el asistente completo con un cliente de API simulado;
- moderar;
- cada estado vacío y de error.

---

## Fase 2: comportamiento nativo (rama `mejoras-front`), 2 días

Los paquetes, `Info.plist` y `AndroidManifest` están en la sección Handoff Flutter del diseño (resumen en `SPEC.md`).

1. **Permisos con explicación previa.**
   - El micrófono se pide al pulsar grabar por primera vez y la ubicación al pulsar «Aquí».
   - Antes de cada uno, una pantalla propia que lo explica.
   - Si se deniega: la ruta exacta de Ajustes, el botón «Abrir Ajustes» y una alternativa («Escribirla en su lugar» o buscar el pueblo).
   - Paquete: `permission_handler`.
2. **Compartir.** Hoja del sistema con el título y el enlace `/historia/<id>`, con `share_plus`. «Copiar enlace» queda como segunda opción.
3. **Escuchar.**
   - Controles en la pantalla de bloqueo y en la notificación multimedia (`just_audio` con `audio_service`).
   - Sigue sonando con la pantalla apagada.
4. **Grabar con el móvil bloqueado.**
   - En Android, servicio en primer plano con notificación fija y botones Pausar y Terminar. En iOS, audio en segundo plano.
   - Si entra una llamada, se pausa sola y avisa: «Se ha pausado por una llamada…» (`audio_session`).
   - Formato m4a/AAC, 64 kbps, mono.
5. **Vibración breve** al empezar y al terminar de grabar y al publicar, con `HapticFeedback`.
6. **Icono y pantalla de arranque.**
   - Icono: una placa de azulejo con las barras de una voz y el punto ocre. Versiones claro, oscuro, teñido y monocromo adaptativo.
   - Pantalla de arranque: fondo cal e icono centrado, sin animación.
7. **Accesibilidad.**
   - `Semantics` en placas, sellos y pasos, por ejemplo «Paso 2 de 4: Historia».
   - `liveRegion` en el estado de la grabación.
   - Orden de foco lógico.

Lo que no se pueda probar de verdad en el emulador (grabar con el móvil bloqueado, una llamada entrante, el tamaño de letra del sistema) se deja anotado en el resumen, para probarlo en un móvil real.

---

## Fase 3: sin conexión (rama `mejoras-front`), 2 a 3 días

Pregunta antes de empezarla.

1. **Borrador en el dispositivo con `drift`.** Si se cierra la app a medias, al volver aparece «Tienes una historia a medias», con «Seguir» o «Borrarla».
2. **Cola de subida.**
   - Sin conexión se puede guardar igual: la historia queda «Pendiente de subir».
   - Se sube en segundo plano cuando hay red, con preferencia por wifi si el audio pasa de 20 MB. Paquete: `background_downloader`.
   - El progreso se ve en Cuenta.
3. **Caché.** Lo ya escuchado queda en caché, y las teselas de las zonas visitadas también.

---

## Fuera de alcance (no hacer sin pedirlo)

- Avisos push: UnifiedPush en Android y APNs en iOS, y la pantalla «¿Te avisamos cuando se publique?».
- Enlaces universales y App Links: necesitan el dominio `vocesdellugar.org` y sus ficheros de verificación.
- Versión para F-Droid, capturas de tienda y publicación en las tiendas.
- Fotos, transcripción automática, comentarios y varios idiomas.
