# Fase 0 — resultados del 15 de noviembre de 2026

Preparación realizada; pendiente de aprobación para Fase 1.

## Repositorio

Directorio inicial con solo `.git`, rama local `master`, sin commits, archivos de aplicación ni remoto. No se encontraron instrucciones AGENTS.md en los directorios ancestros inspeccionados. Se añadieron únicamente documentación y `.gitignore`.

Se configuró `origin` como https://github.com/ADOC0485/GI-CALCULATOR.git. `git ls-remote` terminó con código 0 y sin referencias: remoto sin ramas anunciadas. GitHub API identifica el repositorio público, rama predeterminada `main`, permisos `pull: true`, `push: false`, `admin: false`. La lectura está comprobada; escritura no autorizada por las credenciales actuales. No se hizo push ni commit, porque la fase aún no está aprobada.

## Verificaciones reales

| Comprobación | Resultado |
| --- | --- |
| Git | 2.55.0.windows.5 |
| Flutter | 3.47.5, canal stable, instalado en C:\flutter |
| Dart | 3.13.4 stable, windows_x64 |
| flutter doctor -v: Windows | Correcto, Windows 11 |
| Visual Studio | Build Tools 2026 18.9.2 reconocido; Windows SDK 10.0.26100.0 |
| Android | Toolchain reconocido, licencias aceptadas; advertencia por múltiples ADB |
| Web | Chrome no encontrado; no bloquea el alcance Windows |
| Red | Recursos de red correctos fuera del sandbox |
| Versiones de paquetes | Consulta directa a pub.dev API; restricciones SDK compatibles |
| Resolución conjunta | flutter pub get --dry-run en carpeta temporal: código 0, 111 dependencias resolubles |

El dry-run terminó con una advertencia sobre ausencia de `.dart_tool/package_config.json` en la carpeta temporal: no generó un proyecto instalable ni configuración final. También indicó tres paquetes con versiones nuevas incompatibles con las restricciones elegidas. No se hizo actualización forzada. La instalación real, el lockfile, la generación Drift y compilación se verifican en Fase 1.

El primer intento de red dentro del sandbox falló al resolver github.com; el reintento permitido fuera del sandbox funcionó. La primera ejecución de Flutter sin salida se canceló; los resultados anteriores corresponden al diagnóstico completo posterior.

## Pruebas y pendientes

No hay código de aplicación: no se ejecutaron pruebas unitarias, de widgets ni integración, y no se declara ninguna funcionalidad terminada. Se ejecutaron los diagnósticos y la resolución de dependencias indicados arriba. La compilación nativa real sigue pendiente.

Se entregan arquitectura, estructura, versiones candidatas, fuentes y riesgos en los documentos vinculados desde README.md. La fuente genshin-db es candidata, no un catálogo certificado. No se importaron materiales, personajes ni imágenes.

Próximo alcance propuesto: Fase 1, inicializar Flutter solo para Windows, navegación con estados vacíos honestos, tema propio y persistencia mínima con pruebas. Android se implementará tras aprobar Windows. No avanzar sin aprobación explícita del usuario, conforme a las secciones 22 y 24 de su prompt maestro.
