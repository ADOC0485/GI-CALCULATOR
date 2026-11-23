# Genshin Progress Planner

Aplicación prevista en Flutter y Dart para planificar personajes, armas, inventario y farmeo de Genshin Impact. Windows primero; Android después de aprobar Windows. Funcionamiento local, sin cuentas ni servicios de nube.

## Estado

Fase 1 cerrada. Fase 2 implementada y validada, pendiente de aprobación: catálogo inicial de 92 registros, consulta de personajes/armas/materiales/actividades e importación versionada. Las calculadoras, el inventario y la agenda funcional se implementarán en sus fases, después de aprobación.

- [Plan técnico y arquitectura](docs/PLAN_TECNICO.md)
- [Verificaciones del entorno](docs/FASE_0.md)
- [Cierre y validación de Fase 1](docs/FASE_1.md)
- [Entrega y validación de Fase 2](docs/FASE_2.md)
- [Fuentes y política de datos](docs/FUENTES.md)
- [Mockup conceptual de Windows](docs/mockups/README.md)
- [Alcance de la calculadora de deseos](docs/DESEOS.md)
- [Catálogo, fuentes, formato e importación](docs/CATALOGO.md)

## Desarrollo en Windows

Entorno comprobado: Flutter stable 3.47.5 / Dart 3.13.4 y Visual Studio Build Tools 2026 con C++ y Windows SDK. Las versiones resueltas están fijadas en `pubspec.lock`.

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter test integration_test/app_persistence_test.dart -d windows
flutter run -d windows
```

Compilación de desarrollo: `flutter build windows --debug`. El ejecutable se genera en `build/windows/x64/runner/Debug/genshin_progress_planner.exe`; requiere los demás archivos de esa carpeta. No es todavía el instalador final ni la versión Release de Fase 8.

La base `genshin_progress_planner.sqlite` se abre en el directorio de soporte de la aplicación devuelto por `path_provider`, fuera del repositorio. Almacena preferencias y versiones del catálogo. Si no puede abrirse, la aplicación ofrece reintentar sin eliminar datos. Cambios de esquema requieren migraciones explícitas; no hay reinicio destructivo automático.

## Estructura implementada

- `lib/app`: tema, router y navegación de escritorio.
- `lib/core/presentation`: composición visual compartida.
- `lib/data/database`: SQLite con Drift, esquema 2 y migración desde esquema 1.
- `lib/features/catalog`: modelos, validación, importación transaccional y consulta del catálogo.
- `lib/features/settings`: entidad e interfaz Dart puro, repositorio Drift y controlador Riverpod.
- `lib/features/dashboard`: pantalla inicial con estados vacíos.
- `test` e `integration_test`: persistencia, integridad, navegación y recuperación de errores.

Los mockups muestran una propuesta futura y contienen datos de demostración. No son capturas de la aplicación actual.

Repositorio: https://github.com/ADOC0485/GI-CALCULATOR

## Convenciones

Código e identificadores en inglés; interfaz y documentación inicial en español. Archivos `snake_case.dart`, tipos `UpperCamelCase`, miembros `lowerCamelCase`. IDs estables independientes del nombre traducido. Cantidades enteras; instantes persistidos en UTC y zona IANA explícita.

Estrategia propuesta: `main` para fases aprobadas y ramas cortas `codex/fase-N-descripcion`. Commits por fase aprobada (`docs:`, `feat:`, `fix:`, `test:`). No hacer push sin autorización. Versionar `pubspec.lock` cuando exista la aplicación. No versionar bases de datos personales, secretos ni compilaciones.
