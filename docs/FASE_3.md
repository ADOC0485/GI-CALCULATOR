# Fase 3 — calculadoras y escenarios

Entrega: 2026-11-23. Implementación y validación automatizada terminadas; pendiente de revisión visual manual y aprobación. Rama local `codex/fase-3-calculadoras`. La fase 2 aprobada quedó en el commit local `a81c795`. Sin commit de fase 3 ni push.

## Entrega

- Personajes y armas: botón **Calcular** en el catálogo. Diferencias de nivel, ascensión y EXP parcial, materiales pendientes, plan de libros/minerales, Mora y excedentes de EXP. Hasta nivel 90 para los seis perfiles del catálogo inicial.
- Talentos: objetivos independientes para ataque, habilidad y definitiva, niveles base 1–10, con validación de ascensión y sin sumar bonificaciones de constelaciones.
- Deseos: saldos actuales, horizonte por días o fecha/hora, servidor y zona horaria, Bendición, encargos, exclusiones de ingreso, conversión opcional de cristales, canjes explícitos de brillo/polvo, límites mensuales y extras confirmados/estimados.
- Resultados reactivos con desglose y restos enteros. Los tipos de destino no comparten dos veces las mismas protogemas.
- Guardar/recuperar un escenario de deseos y uno por personaje/arma en SQLite. Migración transaccional 1/2→3 conservando preferencias y catálogo. No se modifica inventario.
- Tablas numéricas de EXP con licencia MIT y revisión fija; reglas y fuentes documentadas en [CALCULADORAS.md](CALCULADORAS.md).

## Validación realizada

| Comprobación | Resultado |
| --- | --- |
| `flutter analyze --no-pub` | Sin incidencias |
| `flutter test --no-pub --reporter expanded` | 61 pruebas aprobadas |
| Integración nativa Windows | 1 prueba aprobada; guarda escenario de deseos desde el formulario y comprueba persistencia al reabrir, además de tema y catálogo |
| `flutter build windows --debug --no-pub` | Compilación normal correcta después de la integración |
| `tool/build_progression_rules.ps1` | Extracción desde revisión fija ejecutada; cuatro tablas de 90 niveles; puntos de control numéricos aprobados |
| `git diff --check` | Sin errores de espacios |

La cobertura incluye personaje 1→90 y 80→90 antes/después de ascender, arma 1→90 y 40→90, talentos 1/10/10 y parciales, EXP parcial, estados imposibles y retrocesos. Para deseos: cero horizonte, redondeo, cristales optativos, tipos de destino, Bendición vencida o días sin ingreso, hoy reclamado, reinicio exacto, canjes previos, cambio de mes/año, saldo insuficiente y extras estimados. También cubre fechas IANA, horas inexistentes/ambiguas por horario de verano, migraciones, rollback, persistencia y edición/recuperación de formularios.

Se corrigieron dos problemas detectados: desbordamiento horizontal en selectores de servidor/zona y resolución de la zona UTC, que requiere la ubicación UTC incorporada de la biblioteca. La regresión final pasó después de esas correcciones.

La apertura del ejecutable se comprobó por el árbol de accesibilidad de Windows. La herramienta de control no consiguió activar su ventana (`failed to activate captured window`), y la captura mostraba otra ventana superpuesta. Por ello no se declara una inspección visual manual completa. No se interactuó con el juego abierto.

## Cómo revisar

1. Abre `build/windows/x64/runner/Debug/genshin_progress_planner.exe` con todos sus archivos acompañantes.
2. En Personajes, usa **Calcular** junto a Amber. El objetivo inicial 1→90 debe mostrar 8.362.650 EXP.
3. En Deseos, introduce 8.000 protogemas, horizonte 15 días y Bendición restante 25 días. Mantén hoy reclamado y encargos activados, sin extras: 64 deseos y 10 protogemas sobrantes.
4. Guarda un escenario, cambia una entrada y recupéralo. Cierra y vuelve a abrir la app para comprobarlo también manualmente.

## Alcance pendiente

No incluye todos los personajes/armas, reconocimiento de cuenta, probabilidades de banners, inventario, consumo, resina, calendario de farmeo, historial ni Android. El plan de materiales de EXP es una combinación explícita, no una optimización según existencias. Las fuentes comunitarias se identifican como tales. La revisión visual y aprobación de esta fase preceden a Fase 4; no se implementaron funciones de esa fase.

La subida de personajes de 90 a 95/100 está excluida por decisión del usuario, no pendiente de implementación: según su aclaración, utiliza el consumible procedente de duplicados de cinco estrellas posteriores a C6 y no requiere el cálculo habitual de materiales.
