# Investigación de fuentes — 2026-11-15

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
