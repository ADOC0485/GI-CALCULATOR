# Investigación de fuentes — 2026-11-15

Actualización 2026-11-23: Fase 3 incorpora tablas numéricas de EXP de paimon-moe bajo MIT y reglas de deseos contrastadas con soporte oficial y fuentes comunitarias. Revisión fija, URLs, alcance y supuestos en [CALCULADORAS.md](CALCULADORAS.md). No se incorporan imágenes, voces ni textos narrativos del juego.

Actualización 2026-11-19: se incorporó el extracto factual de genshin-db descrito en [CATALOGO.md](CATALOGO.md), fijado al commit `8e5badd60b5d894284ccc927a56c9683529d2592`, con atribución MIT. La versión 7.2 se contrastó con https://genshin.hoyoverse.com/m/es/news/detail/167131 . Los párrafos siguientes conservan el diagnóstico de Fase 0; la cobertura y los pendientes vigentes están en CATALOGO.md.

## Candidata principal: genshin-db

- Repositorio: https://github.com/theBowja/genshin-db
- Licencia consultada: https://github.com/theBowja/genshin-db/blob/main/LICENSE (MIT, copyright theBowja).
- Contiene datos JSON localizados y categorías de personajes, talentos, armas y dominios. Declara procedencia de GenshinData y wiki comunitaria. Su esquema puede cambiar entre versiones.
- Candidato para conversión offline a nuestro esquema; no requiere Node dentro de la aplicación Flutter. Fijar commit y conservar atribución al incorporar contenido permitido.
- La licencia del repositorio no demuestra por sí sola permisos sobre todos los recursos originales de terceros. La redistribución de imágenes y la procedencia de cada conjunto siguen pendientes de revisión.
- El README afirma una versión del juego; esa afirmación no se ha corroborado con una publicación oficial ni se adopta como versión validada del catálogo.

## Contraste de datos

Usar anuncios y documentación oficial de HoYoverse/HoYoLAB y comprobación manual dentro del juego para contrastar reglas y registros publicados. En Fase 2 deberán guardarse URLs concretas por dato; no se ha confirmado una API oficial pública completa que cubra todos los requisitos. No solicitar credenciales ni leer memoria, procesos o archivos internos del juego.

La fuente upstream candidata https://github.com/Dimbreath/AnimeGameData devolvió 404 al consultarla. No se adopta como dependencia ni se presupone licencia o disponibilidad.

## Puerta de entrada al catálogo

Por registro: ID estable, idioma, fuente y revisión, versión del juego, fecha de verificación, licencia/procedencia y confiabilidad (`verified`, `pending`, `rejected`). Validar cantidades, referencias, niveles y calendarios. Solo `verified` alimenta cálculos exactos. Excluir contenido no publicado y cualquier personaje/material sin confirmar, incluido cualquier nombre del ejemplo del prompt hasta validarlo.

No se importaron datos de juego en Fase 0. Recompensas, probabilidades, costes de resina y calendarios concretos permanecen pendientes de verificación en sus fases. La app deberá indicar ausencia de datos, no sustituirlos por cifras inventadas.

## Rama `version-en-linea`: catálogo desde genshin-api

- Repositorio: https://github.com/devesh-anand/genshin-api (carpeta `data/`). No tiene archivo LICENSE; su `package.json` declara ISC. Sus datos provienen de yatta.moe, Enka.Network y la wiki de Fandom.
- El botón **Actualizar desde internet** (pantalla de catálogo) consulta el último commit de la rama `main`, descarga el zip de esa revisión desde `codeload.github.com` (~2 MB), lo convierte con `lib/features/catalog/data/genshin_api_catalog.dart` y lo valida con `CatalogBundle.parse` antes de guardarlo en SQLite. Después todo funciona sin conexión.
- Versión del catálogo: `genshin-api-<12 primeros caracteres del commit>`; la secuencia es la fecha del commit, de modo que cada actualización posterior se acepta y las anteriores se conservan.
- Los nombres llegan en inglés. Tipos de arma y categorías de material se traducen al español. Coste de resina de los dominios queda pendiente (la fuente no lo trae).
- IDs: los del juego (`character:10000073`, `weapon:14511`, `material:101217`), compatibles con el catálogo semilla; los Viajeros comparten ID y reciben sufijo (`character:10000005-aether-anemo`).
- Nombres en español: `assets/catalog/nombres-es.json`, generado con `python -I tool/build_spanish_names.py` desde genshin-db (MIT) fijado en el commit `8e5badd`. Lo que no esté ahí (por ejemplo un personaje nuevo) se muestra en inglés hasta regenerar el archivo.
- Líneas ley: valores por defecto aproximados y editables por el usuario. EXP: 420 de resina dan 126 Ingenios del héroe en nivel de mundo 6–8 según la wiki de Fandom (≈ 120 000 de EXP por línea ley). Mora: 60 000 por línea ley (nivel de mundo 8, estimación). No se presentan como cifras exactas.
