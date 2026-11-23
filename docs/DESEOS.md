# Calculadora de deseos — ampliación solicitada

Actualización 2026-11-23: motor, formulario y escenarios implementados en Fase 3. Reglas, convenciones de tiempo y fuentes en [CALCULADORAS.md](CALCULADORAS.md). El texto siguiente conserva la especificación original.

Solicitud del usuario durante Fase 1: añadir una proyección de deseos basada en recursos actuales, días hasta una fecha objetivo, Bendición lunar, encargos y otras recompensas. El diseño se incorpora ahora; motor y pruebas de cálculo se implementarán en Fase 3, con reglas verificadas en Fase 2.

## Flujo previsto

1. **Lo que tienes:** protogemas y destinos entrelazados; sección avanzada para cristales génesis, brillo y polvo estelar. Mantener separados destinos entrelazados y encuentros del destino.
2. **Tu horizonte:** número de días o fecha objetivo, servidor y zona horaria. Definir si hoy ya está reclamado y el corte del día del servidor; evitar contar hoy dos veces.
3. **Lo que vas a reclamar:** días de inicio de sesión, días restantes de Bendición, encargos completos o días previstos, recompensas opcionales manuales con fecha y estado confirmado/estimado.
4. **Resultado:** deseos disponibles ahora, deseos proyectados, protogemas sobrantes, desglose por origen y supuestos. Recalcular al cambiar entradas.

## Reglas de precisión

- Contar Bendición solamente dentro de su vigencia y en días con ingreso previsto. Nunca multiplicar todo el saldo de días si el horizonte es menor.
- La ayuda oficial indica que la recompensa diaria requiere iniciar sesión y que los cristales iniciales se conceden al comprar: https://support.hoyoverse.com/hc/en-us/articles/52089442214809-What-happens-to-my-Blessing-of-the-Welkin-Moon-Primogems-if-I-don-t-log-in . Consulta: 2026-11-15. No sumar automáticamente cristales iniciales a una Bendición ya activa: podrían estar incluidos en el saldo.
- No asumir renovación de Bendición ni compras futuras; ninguna compra se recomienda por defecto.
- Conversión de cristales y canjes de brillo/polvo solo si el usuario los activa. Verificar costes, límites mensuales, canjes ya realizados y reinicio de tienda. No asumir que el usuario ganará polvo o brillo por tiradas futuras.
- Encargos: indicar si se completan y reclaman todas las recompensas; no confundir encargos diarios con registro de HoYoLAB.
- Eventos, Abismo, Teatro, códigos y otras fuentes: datos confirmados versionados o aportes manuales identificados como estimaciones; sin asumir recompensas máximas ni ingresos desconocidos.
- Usar aritmética entera: destinos existentes + cociente entero de protogemas convertibles entre coste verificado por deseo + canjes explícitos. Mostrar el resto, sin redondear hacia arriba.
- Esta calculadora proyecta recursos, no garantiza un personaje ni calcula probabilidades de obtención.

## Pruebas de aceptación futuras

Cero días; cero recursos; negativos y decimales inválidos; horizonte menor/mayor que Bendición restante; días sin ingreso; hoy reclamado; fecha límite antes/después del reinicio; cambio de mes/año; límites de tienda y canjes previos; cristales ya contabilizados; separación de tipos de destino; redondeo y sobrantes; fuentes opcionales; modificación de inputs y persistencia del escenario.

Los números de los mockups reproducen un ejemplo visual suministrado por el usuario. No constituyen por sí mismos una validación de reglas vigentes. Todos los costes y fuentes restantes se verificarán antes de incorporar el motor.
