# App

Flutter 3, un solo código para Android, iOS y web (Android e iOS primero). El mapa usa `flutter_map` y teselas de OpenStreetMap.

```bash
flutter run -d emulator-5554 --dart-define=API_BASE=http://10.0.2.2:8001   # Android
flutter run -d web-server --web-port 8080 --dart-define=API_BASE=http://localhost:8001
```

La API tiene que estar en marcha. Quien no tiene cuenta puede leer y escuchar; para dejar una historia hay que entrar, y la app lo pide al guardar sin perder lo contado.

## Qué se puede hacer

- **Bienvenida** (solo la primera vez): «¿Cómo lees mejor?» con Normal, Grande o Muy grande.
- **Inicio**: qué es esto, «Dejar una historia», «Abrir el mapa» y lo último que se ha publicado, con filtro por tipo.
- **Mapa**: una placa por lugar con su recuento. Buscar un pueblo, barrio o calle; «Aquí» para ir a donde estás (con una pantalla que lo explica antes de pedir el permiso); zoom con + y −. La hoja de abajo enseña la vista previa del sitio o la lista, arrastrándola o con sus botones. Tocar un sitio vacío ofrece contar su historia. El mapa recuerda dónde se dejó.
- **Ficha**: tabla de datos, reproductor (±10 s y velocidad), lo que cuenta, licencia en lenguaje llano y «Copiar enlace». Quien la subió la corrige en revisión; quien modera la publica, la rechaza o la retira.
- **Contar**: cuatro pasos (Sitio, Historia, Quién y Permiso) y «Gracias». Grabar, escribir o subir un audio. El borrador se guarda en el dispositivo en cada paso; Atrás vuelve al paso anterior. Si falla la subida del audio, el reintento no repite la historia.
- **Cuenta**: entrar o crear cuenta, el rol, el tamaño de letra y lo que has dejado con su sello.
- **Por revisar** (quien modera): la cola de la más antigua a la más nueva y la revisión de cada historia.

Navegación: barra inferior en el móvil (Inicio, Mapa, Contar y Cuenta), NavigationRail en tableta y barra superior en escritorio. Cada sección conserva su pila y las direcciones `/mapa`, `/contar/…`, `/cuenta`, `/revisar` y `/historia/<id>` abren su pantalla.

Sin `--dart-define=API_BASE`, en web la API se busca en el puerto 8001 de la máquina que sirve la app.

## Interfaz

El diseño es «Placa y registro» (`docs/rediseno/` en la rama `develop`): claro por defecto y oscuro si el sistema lo está, con el tamaño de letra del sistema multiplicado por el ajuste propio.

- `lib/theme/`: `vdl_colors.dart` y `vdl_theme.dart` (copiados del handoff del diseño) y `letra.dart` (ajuste de tamaño de letra guardado en el dispositivo).
- `assets/fonts/`: Atkinson Hyperlegible Next para leer y Courier Prime para los datos de ficha, empaquetadas con sus licencias OFL. Ninguna letra se pide por red.
- `lib/ui/`: `placa.dart` (todo lo que se pulsa: se hunde 2 px y pierde la sombra), `campos.dart`, `sello.dart`, `ficha.dart`, `avisos.dart`, `estados.dart`, `pagina.dart`, `barra_inferior.dart`, `teselas.dart`, `placa_mapa.dart`, `buscador.dart`, `reproductor.dart`, `grabador.dart`, `permiso.dart` y `selector_letra.dart`.
- `lib/navegacion.dart`: secciones, rutas y el armazón según el ancho. `lib/borrador.dart`: el borrador de «Contar».

Nada de blur, sombras difusas ni animaciones continuas: las sombras son sólidas y todo respeta la preferencia de reducir movimiento.
