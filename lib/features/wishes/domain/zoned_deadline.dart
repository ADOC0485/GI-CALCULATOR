import 'package:timezone/timezone.dart' as tz;

import '../../progression/domain/progression_calculator.dart';
import 'wish_calculator.dart';

tz.Location displayLocation(String zone) =>
    zone == 'UTC' ? tz.UTC : tz.getLocation(zone);

DateTime zonedDeadline(String date, int hour, int minute, String zone) {
  final day = parseDay(date);

  require(
    hour >= 0 && hour < 24 && minute >= 0 && minute < 60,
    'Hora o minuto fuera de rango.',
  );
  final location = displayLocation(zone);
  final local = tz.TZDateTime(
    location,
    day.year,
    day.month,
    day.day,
    hour,
    minute,
  );
  require(
    local.day == day.day && local.hour == hour && local.minute == minute,
    'Esa hora no existe por el cambio horario. Elige otra hora.',
  );
  for (final shift in [-60, 60]) {
    final other = tz.TZDateTime.from(
      local.toUtc().add(Duration(minutes: shift)),
      location,
    );
    require(
      !(other.year == local.year &&
          other.month == local.month &&
          other.day == local.day &&
          other.hour == hour &&
          other.minute == minute),
      'Hora ambigua por cambio horario. Selecciona UTC para indicar el instante exacto.',
    );
  }
  return local.toUtc();
}
