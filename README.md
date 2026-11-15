# Genshin Progress Planner

Aplicación prevista en Flutter y Dart para planificar personajes, armas, inventario y farmeo de Genshin Impact. Windows primero; Android después de aprobar Windows. Funcionamiento local, sin cuentas ni servicios de nube.

## Estado

Fase 0: preparación técnica. Todavía no existe una aplicación ejecutable ni calculadoras implementadas. La Fase 1 requiere aprobación del usuario.

- [Plan técnico y arquitectura](docs/PLAN_TECNICO.md)
- [Verificaciones del entorno](docs/FASE_0.md)
- [Fuentes y política de datos](docs/FUENTES.md)

Repositorio: https://github.com/ADOC0485/GI-CALCULATOR

## Convenciones

Código e identificadores en inglés; interfaz y documentación inicial en español. Archivos `snake_case.dart`, tipos `UpperCamelCase`, miembros `lowerCamelCase`. IDs estables independientes del nombre traducido. Cantidades enteras; instantes persistidos en UTC y zona IANA explícita.

Estrategia propuesta: `main` para fases aprobadas y ramas cortas `codex/fase-N-descripcion`. Commits por fase aprobada (`docs:`, `feat:`, `fix:`, `test:`). No hacer push sin autorización. Versionar `pubspec.lock` cuando exista la aplicación. No versionar bases de datos personales, secretos ni compilaciones.
