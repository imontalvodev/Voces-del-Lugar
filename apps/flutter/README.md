# App

Flutter 3, un solo código para Android, iOS y web. El mapa usa `flutter_map` y teselas de OpenStreetMap.

```bash
flutter run -d web-server --web-port 8080 --dart-define=API_BASE=http://localhost:8001
```

La API tiene que estar en marcha. La app tiene tres secciones: inicio, mapa y cuenta. Quien no tiene cuenta puede leer; para dejar una historia hay que entrar. Al abrir el mapa se pide la ubicación y, si se concede, la vista se centra ahí. Si no, abre en Madrid. El campo «Ir a una ciudad o un lugar» mueve el mapa a ese sitio. El punto de una historia nueva sigue siendo el sitio que se pincha.
