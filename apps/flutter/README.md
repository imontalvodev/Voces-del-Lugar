# App

Flutter 3, un solo código para Android, iOS y web. El mapa usa `flutter_map` y teselas de OpenStreetMap.

```bash
flutter run -d web-server --web-port 8080 --dart-define=API_BASE=http://localhost:8001
```

La API tiene que estar en marcha. La app tiene tres secciones: inicio, mapa y cuenta. Quien no tiene cuenta puede leer; para dejar una historia hay que entrar. El punto es el sitio que se pincha en el mapa.

## Interfaz

La estética es un crepúsculo: la hora en que se sale a la puerta a contar. Todo lo visual vive en `lib/ui/`.

- `sky.dart` y `shaders/dusk.frag`: el cielo de fondo es un shader GLSL (nubes, estrellas, halo que sigue al puntero). Si el dispositivo no lo compila queda un degradado.
- `voice_terrain.dart`: el paisaje 3D de la portada y de cada ficha. Cada fila es una onda de voz proyectada en perspectiva; cada historia levanta un cerro con una farola que se puede tocar. Cuando suena una grabación, el paisaje se agita con ella.
- `audio.dart`: reproductor con huella de voz arrastrable y grabadora dentro de la app (`record`). En web graba WAV; en móvil, AAC.
- `dusk_tiles.dart`: teselas de OpenStreetMap con la luminancia invertida y teñida, sin clave de proveedor.
- `kit.dart`, `tokens.dart`: cristal, botones, chips, colores, tipografía (Instrument Serif y Bricolage Grotesque) y tiempos de animación.

Librerías: `flutter_animate` (entradas y efectos), `animations` (transformación de tarjeta a ficha y pasos del alta), `lucide_icons_flutter`, `record`, `just_audio`. Todas las animaciones respetan la preferencia de reducir movimiento.
