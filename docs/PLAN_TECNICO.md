# Plan técnico — propuesta de Fase 0

## Arquitectura

Un solo proyecto Flutter. Presentation usa Riverpod y GoRouter; Domain contiene entidades, interfaces de repositorio y funciones de cálculo en Dart puro; Data implementa repositorios y almacenamiento Drift; Core contiene errores, reloj inyectable y configuración. Domain no importa Flutter, Riverpod, Drift ni APIs nativas. Los adaptadores de plataforma quedan en Data/Core.

Estructura prevista (se crea gradualmente, sin implementar fases futuras):

```text
lib/
  app/                         # bootstrap, router, tema
  core/                        # errores, reloj, configuración
  data/database/               # Drift, migraciones, transacciones
  features/
    catalog/{domain,data,presentation}/
    progression/{domain,data,presentation}/
    inventory/{domain,data,presentation}/
    resin/{domain,data,presentation}/
    planner/{domain,data,presentation}/
    history/{domain,data,presentation}/
    settings/{domain,data,presentation}/
test/                          # unitarias, widgets y repositorios
integration_test/
assets/catalog/                # solo datos revisados y autorizados
docs/
windows/                       # Fase 1
android/                       # Fase 9
```

## Persistencia e invariantes

SQLite mediante Drift, fuera del repositorio y de OneDrive, en el directorio de soporte de la aplicación. Tablas separadas para catálogo versionado, proyectos, existencias, asignaciones y movimientos. Migraciones con pruebas y copias consistentes; no copiar una base abierta ignorando su WAL.

El catálogo se valida en staging antes de activar una versión en una transacción. Importar catálogo no modifica inventario ni historial. Conservar IDs y resolver referencias retiradas sin borrar progreso. Cada registro incluye fuente, revisión, versión del juego, fecha de verificación y confiabilidad.

Crear un plan nunca descuenta existencias. Reservado y comprometido serán estados excluyentes de asignación; gastado es historial de movimientos, no existencias actuales. La disponibilidad descuenta asignaciones activas una sola vez. Confirmaciones de consumo y sesiones de farmeo usan transacciones e IDs de operación únicos para impedir duplicados.

Motor de progresión por diferencias de estados válidos, incluyendo ascensión y experiencia parcial. Talento base separado de bonificaciones por constelación. Conversiones preservan primero requisitos de baja rareza y consideran Mora, recetas y recursos compartidos.

## Tiempo, estimación y agenda

Reloj inyectable; en producción usa la fecha real. UTC para instantes, zona IANA para presentación y reglas versionadas independientes para reinicios del servidor. No equiparar el día civil del usuario con el día del juego.

Separar requisitos exactos de recompensas variables. Una distribución no verificada no permite inventar probabilidades. Los resultados indican fuente, supuestos y versión de reglas. Resina modelada como evolución temporal con capacidad, consumibles autorizados y ventanas de juego; no como suma ilimitada por día.

Planificador inicial determinista: detectar restricciones imposibles, asignar recursos globales por prioridad, ubicar oportunidades limitadas, distribuir resina y recalcular déficits después de sesiones reales. No prometer óptimo global ni fechas garantizadas. Recalcular al cambiar inventario, objetivos, reglas o día del servidor; descartar resultados antiguos si cambió la revisión de entrada. Isolates para trabajo pesado cuando las mediciones lo justifiquen.

## Dependencias candidatas verificadas el 2026-11-15

| Paquete | Versión candidata | Uso |
| --- | --- | --- |
| flutter_riverpod | 3.5.0 | Estado reactivo |
| go_router | 18.1.4 | Navegación |
| drift / drift_flutter | 2.35.4 / 0.3.1 | SQLite y apertura multiplataforma |
| path_provider | 2.1.6 | Directorio de datos |
| intl / timezone | 0.20.3 / 0.11.2 | Localización y zonas horarias |
| drift_dev / build_runner | 2.35.3 / 2.17.1 | Generación de código |
| flutter_lints | 6.0.0 | Análisis estático |
| flutter_test / integration_test | SDK Flutter | Pruebas |

Metadatos consultados directamente en `https://pub.dev/api/packages/<paquete>`. Sus restricciones declaradas aceptan Flutter 3.47.5 / Dart 3.13.4. Flutter localizations del SDK permite intl ^0.20.3. La resolución conjunta se registra en FASE_0.md; una resolución exitosa no sustituye compilar y probar plugins nativos.

Freezed 4.0.3 y json_serializable 6.15.2 se evaluarán al modelar DTOs: no añadir generación innecesaria en Fase 1. No actualizar Flutter automáticamente: la versión estable instalada cumple los requisitos candidatos. Documentación: https://drift.simonbinder.eu/setup/ y https://docs.flutter.dev/platform-integration/windows/setup.

## Fases y criterios de salida

| Fase | Entrega y verificación |
| --- | --- |
| 0 | Entorno, fuentes, riesgos, arquitectura y plan revisables |
| 1 | Scaffold Windows, tema propio, navegación y persistencia mínima; analyze, widget test, escritura/reapertura SQLite y compilación Windows |
| 2 | Catálogo validado, procedencia, importación transaccional; rechazo de duplicados y datos incompletos |
| 3 | Personajes 1→90 y 80→90; armas 1→90 y 40→90; talentos 1/10/10 y parciales; resultados contrastados con tablas verificadas |
| 4 | Inventario suficiente/insuficiente, reservas compartidas, conversiones y confirmación de consumo |
| 5 | Regeneración, capacidad, consumibles y recompensas variables; pruebas de límites y supuestos |
| 6 | Dominios, reinicios, zona horaria, fin de mes/año, predicción, registro de recompensas y replanificación |
| 7 | Dashboard, calculadoras, agenda semanal/mensual y modo compacto; pruebas de widgets y accesibilidad |
| 8 | Regresión, medidas de rendimiento, minimizar/restaurar, dos monitores/DPI, persistencia y release Windows |
| 9 | Adaptación Android reutilizando núcleo; exportación/importación versionada, conflictos, rollback y APK probado |
| 10 | Regresión final, privacidad, documentación y artefactos verificables |

Tras cada fase: pruebas reales, documentación, pendientes, revisión y autorización antes de avanzar. Commits después de aprobación. Los datos de prueba sintéticos deberán marcarse como tales y nunca constituir un catálogo real.

## Riesgos y mitigaciones

- Cobertura y licencia de datos: auditar cada fuente y restringir el primer catálogo a registros verificables; sin imágenes de terceros inicialmente.
- Reglas del juego cambiantes: versionarlas y no certificar datos solo por estar presentes en un repositorio.
- Planificación con aleatoriedad y recursos compartidos: invariantes de no doble asignación, escenarios y supuestos visibles.
- OneDrive: mantener SQLite fuera del árbol sincronizado; vigilar bloqueos de archivos durante compilación.
- Compatibilidad nativa: resolver paquetes no prueba C++/SQLite; compilar Windows en Fase 1.
- Escritura GitHub: la sesión actual solo tiene lectura; trabajar localmente y resolver autenticación antes de cualquier push autorizado.
- Android: múltiples ADB encontrados; revisar PATH al iniciar esa fase. Web queda fuera del alcance.
