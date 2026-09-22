# ADR-006: Autenticación y corte del MVP

## Contexto

Fase 1 necesita que una persona entre, deje una historia (texto o audio) anclada a un punto, y que otra la vea en el mapa. ADR-003 ya exige `author_id` y un estado de moderación. Faltaba decidir cómo se demuestra quién es el autor.

## Decisión

- **Cuenta**: email y contraseña. La contraseña se guarda solo como hash bcrypt.
- **Sesión**: JWT de acceso en la cabecera `Authorization: Bearer`, válido 7 días. No hay cookies.
- **Lectura pública**: el mapa y el detalle de una historia `published` no piden cuenta.
- **Escritura**: hace falta cuenta. La historia nace en `pending_review`.
- **Moderación**: `curator` y `admin` pueden pasar una historia a `published` o `rejected`. La primera cuenta que se registra en una base vacía queda como `admin`, para que el grupo de prueba no se quede sin moderador.
- **Mapa**: la app usa `flutter_map` con teselas de OpenStreetMap. La API filtra por el recuadro visible (`west`, `south`, `east`, `north`) y también ofrece proximidad por radio.
- **Audio**: se sube a disco local (`storage_key` relativo). `processing_status` queda en `done`. La cola (Celery, RQ o arq) no entra en este corte; el campo ya existe para cuando haya transcodificado.
- **Publicar** exige consentimiento guardado y, además, texto en `body` o un audio.

## Consecuencias

- Cualquier cliente (la app Flutter, un curl) habla con `/api/v1`. El esquema OpenAPI sale de FastAPI en `/docs`.
- El secreto JWT y la ruta de media vienen de variables de entorno, no del repositorio.
