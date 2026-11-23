import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:genshin_progress_planner/features/wishes/domain/zoned_deadline.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test(
    'Local target resolves to exact UTC instant, including year boundary',
    () {
      expect(
        zonedDeadline('2026-12-31', 23, 30, 'America/Bogota'),
        DateTime.utc(2027, 1, 1, 4, 30),
      );
      expect(
        zonedDeadline('2026-11-23', 4, 0, 'Asia/Shanghai'),
        DateTime.utc(2026, 11, 22, 20),
      );
    },
  );
  test('Reject nonexistent and ambiguous DST local times', () {
    expect(
      () => zonedDeadline('2026-03-08', 2, 30, 'America/New_York'),
      throwsA(isA<CalculationException>()),
    );
    expect(
      () => zonedDeadline('2026-11-01', 1, 30, 'America/New_York'),
      throwsA(isA<CalculationException>()),
    );
    expect(
      zonedDeadline('2026-11-01', 6, 30, 'UTC'),
      DateTime.utc(2026, 11, 1, 6, 30),
    );
  });
}
