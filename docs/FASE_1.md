# Fase 1 — proyecto base Windows

Cierre: 2026-11-19. Alcance de la fase completado. La Fase 2 requiere autorización independiente.

## Implementado

- Proyecto Flutter nativo solo para Windows, con dependencias fijadas en pubspec.lock.
- Navegación GoRouter: Inicio, Personajes, Armas, Deseos, Inventario, Agenda, Historial y Ajustes.
- Pantalla inicial funcional y estados de preparación explícitos en módulos futuros.
- Tema claro pastel, oscuro y Sistema; Riverpod gestiona las preferencias.
- SQLite mediante Drift, esquema versión 1, restricciones de integridad y repositorio separado de la entidad Dart puro.
- Guardado automático de apariencia; errores de apertura con reintento y errores de escritura que conservan el estado anterior.
- Mockups de nueve vistas y especificación de Deseos, incorporados a las fases correspondientes.

## Archivos principales

- `lib/app/planner_app.dart`: aplicación y estados de arranque.
- `lib/app/app_router.dart`, `app_shell.dart`, `app_theme.dart`: navegación y temas.
- `lib/data/database/app_database.dart`: esquema inicial y política de migraciones.
- `lib/data/database/database_connection.dart`: conexión local fuera del repositorio.
- `lib/features/settings/`: dominio, repositorio y preferencias visuales.
- `test/`, `integration_test/app_persistence_test.dart`: pruebas.
- `docs/mockups/TODAS_LAS_VISTAS.md`: diseño futuro, no funcionalidades actuales.

## Validación real

Verificaciones ejecutadas durante la implementación del 2026-11-15:

| Verificación | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias |
| `flutter test --reporter expanded` | 13 pruebas aprobadas |
| Prueba adicional de apariencia Sistema | 1 prueba aprobada: sigue cambios de brillo del sistema |
| `flutter test integration_test/app_persistence_test.dart -d windows` | 1 prueba aprobada: conexión nativa, guardado y recreación de app/conexión sobre el mismo archivo |
| `flutter build windows --debug` posterior a integración | Ejecutable normal generado correctamente |

Las 14 pruebas unitarias/de widgets cubren navegación de ocho destinos, persistencia tras reapertura, integridad de la tabla, archivo corrupto sin borrado automático, cambio de apariencia, fallos de escritura y reintento de apertura, rutas desconocidas, texto ampliado y ventanas de 480, 800 y 1280 píxeles. Se corrigió un fallo de invalidación del estado en el botón Reintentar antes de la ejecución satisfactoria.

Revisión visual del ejecutable el 2026-11-19 mediante Computer Use: pantalla inicial clara y Ajustes en modo oscuro visibles correctamente, textos y controles legibles, sin desbordamientos observados; se observó confirmación de apariencia guardada. Hubo interacción manual del usuario y movimiento de ventana durante la revisión; se renovaron las observaciones antes de continuar, sin usar coordenadas obsoletas. La captura inicial mostró el juego que estaba delante; se activó la ventana identificada del planificador para inspeccionarla. No se interactuó con el juego.

No se repitieron compilación ni pruebas tras esta revisión porque no cambió el código. Solo se actualizó documentación de cierre.

## Límites y trabajo posterior

- Catálogo, cálculos de progresión y Deseos, inventario, resina, historial y agenda aún no están implementados; sus rutas muestran preparación.
- No hay datos de juego importados. Los ejemplos de mockups no son fuentes del motor.
- El modo compacto, pruebas completas en dos monitores/DPI, rendimiento, copias de seguridad e importación/exportación quedan para sus fases.
- El esquema inicial está preparado para migraciones explícitas futuras; no existen versiones anteriores que migrar ni recuperación completa de bases dañadas.
- Ejecutable de desarrollo en `build/windows/x64/runner/Debug/genshin_progress_planner.exe`. Debe conservarse con DLLs y carpeta data. No es un instalador Release.
- Android y Web no se han generado.

## Control de versiones

Trabajo en `codex/fase-1-base`, basado en el commit de Fase 0 `2570fc6`. El usuario autorizó revisar y cerrar la fase con un commit local. No se publica ni se hace push en este cierre.

Siguiente fase propuesta: catálogo de personajes, armas, materiales, actividades y reglas verificables, con procedencia y validación de importaciones.
