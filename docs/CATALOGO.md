# Catálogo inicial — Fase 2

Actualización Fase 3 (2026-11-23): el catálogo histórico se conserva sin modificar. Las calculadoras incorporan tablas de EXP y límites en un paquete de reglas separado para los seis perfiles revisados; véase [CALCULADORAS.md](CALCULADORAS.md).

## Alcance real

El paquete `assets/catalog/seed-v1.json` contiene 92 registros: Amber, Kaeya, Lisa; Arco de Favonius, Espada del Alba y Cuentos de Cazadores de Dragones; 58 materiales referenciados; 24 niveles de dominios y 4 jefes. Es un catálogo inicial curado, no todos los personajes y armas del juego.

Cada registro conserva ID estable, nombre español, versión del juego, fecha de revisión, URL a un commit fijo, licencia, método de revisión y confiabilidad. Se incluyen costes de ascensión y talentos de la fuente. Mora aparece como un material referenciado y no se suma todavía: calcular objetivos pertenece a la Fase 3.

Fuente: [genshin-db](https://github.com/theBowja/genshin-db/tree/8e5badd60b5d894284ccc927a56c9683529d2592), revisión `8e5badd60b5d894284ccc927a56c9683529d2592`. Se conservaron únicamente identificadores, nombres y campos factuales necesarios. No se incluyen retratos, iconos del juego, historias, voces ni descripciones narrativas.

La licencia MIT y la atribución de theBowja se distribuyen en `assets/catalog/LICENSE-genshin-db.txt`. La existencia de la versión 7.2 se contrastó con el [aviso oficial de actualización](https://genshin.hoyoverse.com/m/es/news/detail/167131). Esto no convierte el catálogo comunitario en una publicación oficial ni verifica por sí solo cada regla.

## Qué significa verificado

`verified` indica que los campos incorporados se revisaron contra la fuente comunitaria fijada. Los costes numéricos se contrastan entre las versiones inglesa y española del mismo commit; es una comprobación de consistencia, no dos fuentes independientes. No significa certificación por HoYoverse.

`pendingFields` señala la información ausente o no confirmada. La API `canUseFields` rechaza campos desconocidos, pendientes y registros `pending` o `rejected`. Una ficha puede contener costes revisados y, a la vez, una tabla de experiencia pendiente. `isFullyVerified` exige no tener campos pendientes.

Pendientes actuales:

- Experiencia por nivel, Mora de mejora, límites de nivel por ascensión y bonificaciones de constelaciones.
- Coste de resina, límites y disponibilidad de jefes no documentados en los archivos seleccionados.
- Distribuciones y cantidades garantizadas de recompensas. Se excluyen los promedios fraccionarios del preview de jefes.
- Rareza de materiales cuando la fuente la omite.
- Fuentes adicionales como flores ley y enemigos comunes: los materiales conservan indicaciones textuales, pero no se inventan actividades ni costes.

Estos pendientes deben verificarse antes de utilizarse en sus respectivas calculadoras o planificador. La fase no añade estimaciones.

## Formato de importación

Objeto JSON con `schemaVersion: 1`, `version` única, `sequence` entera creciente, `gameVersion`, `createdAt` ISO, `versionSource` HTTPS y `records`.

Cada registro declara `kind` (`character`, `weapon`, `material`, `activity`), `id` prefijado por tipo, `name`, `provenance`, `additionalSources` y `pendingFields`. Personajes/armas incluyen `requirements` (tipo, etapa y mapa material→cantidad), `experience`, `maxLevel` y `activityIds`. Materiales incluyen categoría y pistas de fuentes; actividades incluyen días ISO 1–7, costes opcionales explícitamente pendientes y recompensas por ID, sin probabilidades implícitas.

El esquema inicial valida seis etapas de ascensión y nueve mejoras de talento base 2–10 en los personajes incluidos. Ampliar a otros perfiles de progresión requerirá revisar estas validaciones y sus datos, no forzar tablas incompatibles dentro del formato.

Desde Personajes o Armas: **Importar catálogo → pegar JSON → Validar → Activar catálogo**. El importador valida estructura e integridad, no autentica al autor del archivo. El estado de confiabilidad de archivos externos es declarado por su autor y debe revisarse antes de activarlos. No hay descargas automáticas ni servicios de nube.

## Persistencia

SQLite pasa de esquema 1 a 2 con una migración transaccional que crea `catalog_versions`, `catalog_records` y `catalog_selection`; conserva la tabla de preferencias.

La importación valida primero en memoria. Luego inserta versión y registros y activa la versión dentro de una sola transacción. Un error revierte todo. Importar el mismo contenido y versión es idempotente; cambiar contenido bajo la misma versión o volver a una secuencia anterior se rechaza. Las versiones anteriores se conservan y pueden consultarse por versión: no se borran IDs históricos aunque un catálogo nuevo los omita.

No se toca inventario ni progreso; esas tablas todavía no existen. Una prueba con una tabla de usuario independiente verifica que el importador no modifica datos ajenos al catálogo.

## Reproducción

```powershell
dart run tool/build_seed_catalog.dart
dart run build_runner build
flutter test
```

El script de extracción usa una revisión fija y necesita red solo para descargar las fuentes que falten en su caché local ignorada por Git. La aplicación instalada usa el paquete incluido y SQLite, sin conexión. Cambiar el catálogo exige una nueva versión y revisar de nuevo la procedencia.
