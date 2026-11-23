# Genshin Progress Planner

Aplicación en Flutter y Dart para Windows y Android que planifica personajes, armas, talentos, inventario, resina y farmeo de Genshin Impact. Sin cuentas: tus datos se guardan en tu dispositivo, y solo usa internet para actualizar el catálogo del juego y avisar de versiones nuevas.

> **Proyecto no oficial.** App hecha por fans, sin afiliación, respaldo ni patrocinio de HoYoverse ni COGNOSPHERE. Genshin Impact, sus personajes, imágenes y contenido del juego son marcas y propiedad de HoYoverse / COGNOSPHERE. La app es gratuita y no usa ni pide tu cuenta del juego. Si eres titular de derechos y quieres que se retire algún contenido, [abre un issue](https://github.com/ADOC0485/GI-CALCULATOR/issues).

## Descargar

Android: descarga el APK de la [última versión](https://github.com/ADOC0485/GI-CALCULATOR/releases/latest). La app avisa sola cuando hay una versión nueva y se actualiza encima sin perder tus datos.

## Créditos de los datos

- Personajes, armas, materiales e imágenes: [genshin-api](https://github.com/devesh-anand/genshin-api) (devesh-anand), que usa yatta.moe, Enka.Network y la wiki de Fandom.
- Nombres en español y catálogo inicial: [genshin-db](https://github.com/theBowja/genshin-db) (theBowja), licencia MIT.
- Tablas de EXP: [paimon-moe](https://github.com/MadeBaruna/paimon-moe) (MadeBaruna), licencia MIT.
- Promedios de recompensas y líneas ley: guías y wikis de la comunidad (ver [docs/FUENTES.md](docs/FUENTES.md)).

## Estado

Fases 1 y 2 aprobadas. Fase 3 implementada y validada automáticamente, pendiente de revisión visual y aprobación: calculadoras de personajes, armas, talentos y deseos, con escenarios locales. Catálogo inicial de 92 registros; progresión habilitada para sus tres personajes y tres armas. Inventario y agenda funcional se implementarán en sus fases, después de aprobación.

- [Plan técnico y arquitectura](docs/PLAN_TECNICO.md)
- [Verificaciones del entorno](docs/FASE_0.md)
- [Cierre y validación de Fase 1](docs/FASE_1.md)
- [Entrega y validación de Fase 2](docs/FASE_2.md)
- [Entrega y validación de Fase 3](docs/FASE_3.md)
- [Fuentes y política de datos](docs/FUENTES.md)
- [Mockup conceptual de Windows](docs/mockups/README.md)
- [Alcance de la calculadora de deseos](docs/DESEOS.md)
- [Catálogo, fuentes, formato e importación](docs/CATALOGO.md)
- [Calculadoras: uso, fuentes y reglas](docs/CALCULADORAS.md)

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
- `lib/data/database`: SQLite con Drift, esquema 3 y migraciones desde esquemas 1 y 2.
- `lib/features/progression` y `lib/features/wishes`: motores Dart, formularios y escenarios de cálculo.
- `lib/features/catalog`: modelos, validación, importación transaccional y consulta del catálogo.
- `lib/features/settings`: entidad e interfaz Dart puro, repositorio Drift y controlador Riverpod.
- `lib/features/dashboard`: pantalla inicial con estados vacíos.
- `test` e `integration_test`: persistencia, integridad, navegación y recuperación de errores.

Los mockups muestran una propuesta futura y contienen datos de demostración. No son capturas de la aplicación actual.

Repositorio: https://github.com/ADOC0485/GI-CALCULATOR

## Convenciones

Código e identificadores en inglés; interfaz y documentación inicial en español. Archivos `snake_case.dart`, tipos `UpperCamelCase`, miembros `lowerCamelCase`. IDs estables independientes del nombre traducido. Cantidades enteras; instantes persistidos en UTC y zona IANA explícita.

Estrategia propuesta: `main` para fases aprobadas y ramas cortas `codex/fase-N-descripcion`. Commits por fase aprobada (`docs:`, `feat:`, `fix:`, `test:`). No hacer push sin autorización. Versionar `pubspec.lock` cuando exista la aplicación. No versionar bases de datos personales, secretos ni compilaciones.
