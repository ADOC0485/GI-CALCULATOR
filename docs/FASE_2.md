# Fase 2 — catálogo e importación versionada

Entrega: 2026-11-19. Implementada y validada. Aprobada por el usuario el 2026-11-23 para continuar a Fase 3. Rama de entrega `codex/fase-2-catalogo`. Sin push.

## Implementado

- Catálogo inicial de 92 registros: 3 personajes, 3 armas, 58 materiales y 28 actividades. No representa el catálogo completo del juego.
- Consulta desde Personajes y Armas, filtros por tipo, búsqueda y fichas con costes, procedencia e información pendiente.
- Modelos con IDs estables, revisión de fuente, versión del juego, licencia, fecha y confiabilidad por registro; exclusión explícita de campos pendientes para futuros cálculos.
- Validación de estructura, referencias, cantidades enteras, etapas, fechas, duplicados y campos ausentes sin declaración de pendiente.
- Importación manual JSON con validación y previsualización antes de activarse; transacción SQLite, conservación de versiones históricas y rechazo de cambios bajo la misma versión o retrocesos de secuencia.
- Migración del esquema 1 al 2 conservando preferencias, repositorio compartido y carga inicial sin conexión.
- Extractor reproducible desde un commit fijo de genshin-db, licencia MIT incluida y documentación de procedencia.

## Validación real

| Comprobación | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias |
| `flutter test` | 36 pruebas aprobadas |
| `flutter test integration_test/app_persistence_test.dart -d windows --reporter expanded` | 1 prueba nativa aprobada; tema y catálogo conservados al reabrir |
| `flutter build windows --debug` | Compilación normal de Windows correcta, realizada después de la integración |
| `dart run tool/build_seed_catalog.dart` | 92 registros regenerados; SHA-256 idéntico antes y después |
| `git diff --check` | Sin errores de espacios; advertencias habituales de conversión LF/CRLF en Windows |

Las pruebas cubren datos inválidos, idempotencia, conflictos de versión, conservación de preferencias y datos ajenos al catálogo, histórico, rollback ante un fallo SQLite, migración desde esquema 1 y consulta/búsqueda/importación inválida en widgets.

SHA-256 del catálogo reproducido: `A7564E877F321B1BE80D17C93C495CF0927773719ECC1E7A38601B8A8B456B8D`.

Ejecutable de desarrollo: `build/windows/x64/runner/Debug/genshin_progress_planner.exe`. Necesita los archivos acompañantes; todavía no es un instalador Release.

## Límites y siguiente fase

La fuente de costes es comunitaria. El contraste entre idiomas comprueba consistencia dentro de la misma fuente, no una verificación independiente. La importación comprueba integridad, pero no autentica al autor externo.

Siguen pendientes las tablas de experiencia, Mora de mejora, límites por ascensión, algunas rarezas, resina y distribuciones de recompensas. Estos campos están señalados y no se ofrecen como datos utilizables en cálculos. Consultar [CATALOGO.md](CATALOGO.md) para el alcance exacto y la reproducción.

La Fase 3 requiere aprobación e incluirá las calculadoras de personajes, armas, talentos y deseos según el plan y [DESEOS.md](DESEOS.md). Primero deberán verificarse las reglas y tablas que utilice cada cálculo. No se implementó funcionalidad de fases posteriores.
