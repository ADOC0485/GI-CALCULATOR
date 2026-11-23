# Calculadoras — reglas 2026.11.23.1

Revisión: 2026-11-23. Alcance: los tres personajes y tres armas del catálogo inicial, nivel 1–90 y talentos base 1–10. Nuevos IDs o versiones de juego necesitan revisión antes de habilitar este motor.

Por decisión explícita del usuario, la subida de personajes de 90 a 95/100 queda fuera de la calculadora de materiales y no es una función pendiente. El usuario indica que esa subida utiliza un consumible obtenido por duplicados de personajes de cinco estrellas después de C6, sin los materiales de mejora habituales. Esta aclaración define el alcance; no se añaden reglas ni costes para ese consumible al motor.

## Personajes, armas y talentos

En Personajes o Armas, pulsa **Calcular** junto a la ficha. Introduce nivel, ascensión y EXP parcial actuales y objetivo. Las ascensiones 0–6 tienen límites 20, 40, 50, 60, 70, 80 y 90. En un límite, distingue antes y después de ascender: 80/ascensión 5 todavía necesita la última ascensión; 80/ascensión 6 ya la pagó.

El motor suma las diferencias de EXP acumulada y únicamente las ascensiones y niveles de talento pendientes. Los talentos se introducen sin bonos de constelación; sus límites por ascensión son 1, 1, 2, 4, 6, 8 y 10. Los estados imposibles, retrocesos y cantidades inválidas no producen resultados.

La salida incluye materiales y un plan concreto de libros o minerales. El plan usa libros de 20.000/5.000/1.000 EXP o minerales de 10.000/2.000/400 EXP. Redondea con el material menor en cada barrera de ascensión y muestra la EXP suministrada de más. La Mora de mejora corresponde a ese plan (1 por 5 EXP de personaje, 1 por 10 EXP de arma), y se suma a la Mora de ascensión/talentos. El excedente final puede dejar EXP parcial adicional si no se llega a un límite. No usa armas como alimento, bonificaciones aleatorias ni inventario; no pretende optimizar los materiales que ya posee el usuario.

Las tablas acumuladas están separadas del catálogo en `assets/rules/progression-v1.json`. Los campos EXP pendientes del catálogo histórico siguen pendientes: el cálculo utiliza expresamente estas tablas revisadas, no esos campos vacíos. Solo los requisitos utilizables del catálogo activo aportan costes de ascensión y talento.

### Procedencia

- EXP acumulada: [characterExp.js](https://github.com/MadeBaruna/paimon-moe/blob/4b873a6decad0384665084c69e9927a9fa266555/src/data/characterExp.js) y [weaponExp.js](https://github.com/MadeBaruna/paimon-moe/blob/4b873a6decad0384665084c69e9927a9fa266555/src/data/weaponExp.js), revisión fija de paimon-moe. Licencia MIT de Made Baruna incluida en `assets/rules/LICENSE-paimon-moe.txt`. Solo se incorporan tablas numéricas.
- Contraste de reglas y valores: [EXP de personajes](https://genshin-impact.fandom.com/wiki/Character_EXP), [EXP de armas](https://genshin-impact.fandom.com/wiki/Weapon_EXP), [materiales de talento](https://genshin-impact.fandom.com/wiki/Character_Talent_Material). Datos comunitarios, no certificación oficial. Consultados mediante resultados indexados, dado que el acceso directo a estas páginas rechazó la solicitud.
- Puntos de control probados: personaje 1→90 = 8.362.650 EXP; 80→90 = 3.423.125; arma 4★ 1→90 = 6.042.650; arma 3★ = 3.988.200; arma 4★ 40→90 = 5.546.525; dos talentos 1→10 = 3.305.000 Mora, sin ascensión ni nivelación.
- Costes por personaje/arma: se mantiene la fuente fijada de genshin-db descrita en [CATALOGO.md](CATALOGO.md).

Reproducir las tablas: `powershell -File tool/build_progression_rules.ps1` desde el repositorio. El script necesita red, la aplicación no. La salida debe conservar los mismos valores; las pruebas contrastan los puntos de control anteriores.

## Deseos

La sección Deseos recalcula al editar. Selecciona a qué tipo de destino asignar protogemas y canjes; los destinos del otro tipo permanecen separados y no reciben una segunda asignación del mismo saldo.

El inicio es un instante UTC fijo visible en pantalla. El horizonte puede ser un número de periodos de 24 horas o una fecha/hora en la zona IANA elegida. Las fechas de exclusiones, canjes y extras representan días del juego, definidos por el reinicio de las 04:00 del servidor. Se incluye una oportunidad nueva cuando el objetivo alcanza el reinicio. Las horas civiles inexistentes o ambiguas por cambio horario se rechazan; UTC permite especificar el instante sin ambigüedad.

- Con cero tiempo se muestran recursos y canjes actuales elegidos, sin recompensas diarias futuras.
- Los días restantes de Bendición incluyen el día actual del juego, esté reclamado o no. Solo se cuentan días dentro de su vigencia y con ingreso previsto. Los días perdidos también consumen vigencia. No hay renovación ni suma automática de los 300 cristales iniciales.
- Se presupone ingreso diario salvo exclusiones. Los encargos completos aportan 60 al día; también se pueden excluir días concretos de encargos. Dos controles independientes indican si hoy ya se reclamó Bendición y encargos.
- Cristales: conversión opcional 1:1. Brillo: cantidad de canjes explícita, coste 5. Polvo: entradas con fecha y cantidad, coste 75, límite de 5 por tipo/mes, contando canjes ya realizados del mes inicial. El saldo no aumenta al cambiar de mes ni por futuras tiradas.
- El formulario de extras permite añadir fecha, protogemas y estado confirmado por el usuario o estimado. No se carga ningún evento ni recompensa máxima automáticamente. No añadas extras ya incluidos en los saldos. En el último día incluye solo ingresos anteriores a la hora objetivo.
- El resultado base incluye ingresos diarios condicionados al plan y extras declarados confirmados. Otra cifra añade los estimados. Ninguna es una garantía. Se muestra desglose, días contados, saldos restantes y restos de protogemas tras dividir entre 160 sin redondear arriba.

### Fuentes de deseos

- [Soporte oficial: Bendición y días sin ingreso](https://support.hoyoverse.com/hc/en-us/articles/52089442214809-What-happens-to-my-Blessing-of-the-Welkin-Moon-Primogems-if-I-don-t-log-in): 90 diarios, pérdida al no ingresar, vigencia sin extensión y 300 cristales de compra.
- [Soporte oficial: conversión de cristales](https://support.hoyoverse.com/hc/en-us/articles/50333864357145-How-do-I-purchase-Primogems): 1:1.
- [Aviso oficial 2.1](https://genshin.hoyoverse.com/en/news/detail/104025): zonas de servidor UTC−5, UTC+1 y UTC+8, con reinicio de oportunidades a las 04:00. Las zonas de servidor usan offsets fijos, no el horario de verano del usuario.
- [Tienda de Paimon](https://traveler.gg/paimons-bargains/), [precios y reinicio mensual](https://gamewith.net/genshin-impact/article/show/22383), [guía comunitaria en HoYoLAB](https://www.hoyolab.com/article/25961079): coste de destinos, brillo, polvo y límites. No son publicaciones oficiales de reglas por estar alojadas en HoYoLAB.
- [Planificador comunitario de ingresos](https://genshinimpact.th.gl/primogem-calculator): contraste de 60 protogemas por encargos completos y coste de 160 por deseo.

## Escenarios y datos locales

**Guardar escenario** guarda las entradas válidas en SQLite. **Recuperar escenario** las restaura y recalcula; no guarda una cifra final que pueda quedar desactualizada. Se conserva un escenario de deseos y uno por personaje/arma. Un nuevo guardado reemplaza el anterior de ese mismo tipo. No hay lista de proyectos ni historial de progreso todavía.

Deseos conserva el inicio original; **Actualizar inicio a ahora** cambia la referencia y requiere revisar saldos y reclamaciones. Cambiar la fecha no inventa ganancias ya obtenidas. Progresión conserva la versión de catálogo usada y avisa al recuperar si la versión activa cambió.

SQLite pasa a esquema 3. Las migraciones desde 1 o 2 crean la tabla `calculator_scenarios` dentro de una transacción, conservando preferencias y catálogo. Guardar escenarios no descuenta materiales ni modifica inventario.
