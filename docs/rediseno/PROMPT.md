# Prompt para arrancar al agente

Copia el bloque de abajo como primer mensaje de la sesión de Claude Code en la otra máquina. Arráncala en la carpeta del repositorio, con todas las ramas actualizadas (`git fetch origin`).

---

```text
Vas a aplicar el rediseño «Placa y registro» a la app Flutter de Voces del Lugar
(apps/flutter/), pensada primero para Android e iOS.

Antes de nada:
1. git fetch origin
2. Lee, en este orden, los documentos de la rama develop (docs/rediseno/):
   README.md (contexto, ramas, entorno y reglas), PLAN.md (fases y tareas)
   y SPEC.md (resumen del diseño). Si no estás en develop, léelos con
   `git show origin/develop:docs/rediseno/README.md`, etc.
3. El diseño completo está en docs/rediseno/bundle.html (rama develop). Es la
   fuente de verdad. Ábrelo en un navegador y recorre todas las secciones,
   sobre todo Pantallas (cada pantalla con sus estados) y Handoff Flutter
   (código de tema, medidas, permisos y paquetes).

Ramas:
- Frontend (apps/flutter/): rama mejoras-front.
- Backend (backend/): rama back.
- Documentación del rediseño: rama develop.
Usa un worktree por rama. Nunca hagas push a main, nunca reescribas historia
publicada (nada de --force) y nunca uses `git stash` sin más.

Cómo trabajar:
- Sigue PLAN.md en orden: fase B (backend) y fase 0 primero, luego 1 y 2.
  La fase 3 y lo que está fuera de alcance, solo si te lo pido.
- Primero el test, después el código. Antes de cada commit, verdes
  `flutter analyze`, `flutter test` y `pytest` si tocas el backend.
- Commits pequeños (uno por pieza o pantalla), en Conventional Commits y en
  español.
- Compara cada pantalla en el emulador de Android Studio con las capturas del
  diseño, en claro y oscuro y con el tamaño de letra más grande.
- Escribe siempre en español neutro, nunca voseo.
- Al terminar cada fase, sube la rama y dame un resumen corto: qué está hecho,
  qué queda y qué no se ha podido probar en el emulador.
- Si algo del diseño choca con la API o no es viable en Flutter, pregunta
  antes de improvisar.

Empieza leyendo los documentos y el diseño. Después dime en pocas líneas
cómo vas a abordar la fase B y la fase 0, y arranca.
```
