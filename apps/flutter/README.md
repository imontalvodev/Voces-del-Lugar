# App

Flutter 3, un solo código para Android, iOS y web. El mapa usa `flutter_map` y teselas de OpenStreetMap.

```bash
flutter run -d web-server --web-port 8080 --dart-define=API_BASE=http://localhost:8001
```

La API tiene que estar en marcha. La app tiene tres secciones: inicio, mapa y cuenta. Quien no tiene cuenta puede leer; para dejar una historia hay que entrar. El punto es el sitio que se pincha en el mapa.

## Qué se puede hacer

- **Inicio**: el paisaje de voces con todo lo publicado y lo último que se ha contado.
- **Mapa**: buscar por título, persona o sitio entre las historias de la vista; buscar un pueblo o una ciudad por su nombre para ir allí; ir a la posición propia (si ya hay permiso, el mapa se abre ahí). Cada lugar tiene una farola aunque guarde varias historias; las demás salen debajo de la elegida. Tocar un sitio vacío, o mantener pulsado, marca el punto para contar.
- **Contar**: cuatro pasos (sitio, historia con categoría, quién la cuenta, permiso y licencia). Grabar, adjuntar o escribir. Si falla la subida del audio, el reintento no repite la historia.
- **Ficha**: escuchar o leer. Quien la escribió la corrige mientras está en revisión; quien modera la publica, la rechaza o la quita del mapa.
- **Cuenta**: entrar o crear cuenta, lo que has dejado con su estado y, si moderas, la cola «Por revisar».

Sin `--dart-define=API_BASE`, en web la API se busca en el puerto 8001 de la máquina que sirve la app.

## Interfaz

El diseño es «Placa y registro» (`docs/rediseno/` en la rama `develop`): claro por defecto y oscuro si el sistema lo está, con el tamaño de letra del sistema multiplicado por el ajuste propio (Normal, Grande o Muy grande).

- `lib/theme/`: `vdl_colors.dart` y `vdl_theme.dart` (copiados del handoff del diseño) y `letra.dart` (ajuste de tamaño de letra guardado en el dispositivo).
- `assets/fonts/`: Atkinson Hyperlegible Next para leer y Courier Prime para los datos de ficha, empaquetadas con sus licencias OFL. Ninguna letra se pide por red.
- `lib/ui/` (piezas nuevas): `placa.dart` (botones que se hunden al pulsar), `campos.dart` (campo, casilla y licencia), `sello.dart` (chips de tipo y sellos de estado), `ficha.dart`, `avisos.dart` (aviso, notificación breve y diálogo), `estados.dart` (carga y vacío), `barra_inferior.dart` y `teselas.dart` (OpenStreetMap con el filtro claro u oscuro del handoff).
- `kit.dart`, `tokens.dart`, `story_card.dart` y `audio.dart` son de la interfaz anterior y se van sustituyendo pantalla a pantalla.

Nada de blur, sombras difusas ni animaciones continuas: las sombras son sólidas y todo respeta la preferencia de reducir movimiento.
