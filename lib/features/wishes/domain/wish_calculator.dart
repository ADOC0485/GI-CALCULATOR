import '../../progression/domain/progression_calculator.dart';

enum GameServer {
  america(-5, 'América'),
  europe(1, 'Europa'),
  asia(8, 'Asia / TW, HK, MO');

  const GameServer(this.offset, this.label);
  final int offset;
  final String label;
}

// UTC dates below identify game days, not the user's civil date.
DateTime gameDay(DateTime instant, GameServer server) {
  final shifted = instant.toUtc().add(Duration(hours: server.offset - 4));
  return DateTime.utc(shifted.year, shifted.month, shifted.day);
}

String dateKey(DateTime day) => day.toIso8601String().substring(0, 10);
DateTime parseDay(String text) {
  final date = DateTime.tryParse('${text}T00:00:00Z');
  require(
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
        date != null &&
        dateKey(date) == text,
    'Fecha inválida: usa AAAA-MM-DD.',
  );
  return date!;
}

class WishReward {
  const WishReward(this.day, this.amount, {this.confirmed = false});
  final DateTime day;
  final int amount;
  final bool confirmed;
}

class DustPurchase {
  const DustPurchase(this.day, this.count);
  final DateTime day;
  final int count;
}

class WishInput {
  WishInput({
    required this.now,
    required this.target,
    this.server = GameServer.america,
    this.primogems = 0,
    this.intertwined = 0,
    this.acquaint = 0,
    this.useAcquaint = false,
    this.crystals = 0,
    this.convertCrystals = false,
    this.glitter = 0,
    this.glitterWishes = 0,
    this.dust = 0,
    this.dustUsedThisMonth = 0,
    this.purchases = const [],
    this.welkinDays = 0,
    this.welkinTodayClaimed = true,
    this.commissions = true,
    this.commissionsTodayClaimed = true,
    this.skippedLoginDays = const {},
    this.skippedCommissionDays = const {},
    this.rewards = const [],
  });
  final DateTime now, target;
  final GameServer server;
  final int primogems,
      intertwined,
      acquaint,
      crystals,
      glitter,
      glitterWishes,
      dust,
      dustUsedThisMonth,
      welkinDays;
  final bool useAcquaint,
      convertCrystals,
      welkinTodayClaimed,
      commissions,
      commissionsTodayClaimed;
  final Set<String> skippedLoginDays, skippedCommissionDays;
  final List<DustPurchase> purchases;
  final List<WishReward> rewards;
}

class WishResult {
  const WishResult({
    required this.nowWishes,
    required this.projected,
    required this.withEstimates,
    required this.remainder,
    required this.estimatedRemainder,
    required this.otherFates,
    required this.welkinClaims,
    required this.commissionClaims,
    required this.breakdown,
    required this.remainingDust,
    required this.remainingGlitter,
  });
  final int nowWishes,
      projected,
      withEstimates,
      remainder,
      estimatedRemainder,
      otherFates,
      welkinClaims,
      commissionClaims,
      remainingDust,
      remainingGlitter;
  final Map<String, int> breakdown;
}

WishResult calculateWishes(WishInput input) {
  require(
    !input.target.isBefore(input.now),
    'La fecha objetivo es anterior al inicio.',
  );
  require(
    input.target.difference(input.now).inDays <= 3660,
    'El horizonte máximo es de 3660 días.',
  );
  for (final v in [
    input.primogems,
    input.intertwined,
    input.acquaint,
    input.crystals,
    input.glitter,
    input.glitterWishes,
    input.dust,
    input.dustUsedThisMonth,
    input.welkinDays,
  ]) {
    require(
      v >= 0 && v <= 1000000000,
      'Introduce cantidades enteras no negativas, hasta 1.000.000.000.',
    );
  }
  require(
    input.welkinDays <= 180,
    'La Bendición restante debe estar entre 0 y 180 días.',
  );
  require(
    input.dustUsedThisMonth <= 5,
    'Solo hay 5 canjes mensuales por tipo de destino.',
  );
  require(
    input.glitterWishes * 5 <= input.glitter,
    'No tienes brillo suficiente para esos canjes.',
  );
  final first = gameDay(input.now, input.server);
  final last = gameDay(input.target, input.server);
  final dayCount = last.difference(first).inDays;
  for (final key in {
    ...input.skippedLoginDays,
    ...input.skippedCommissionDays,
  }) {
    final day = parseDay(key);
    require(
      !day.isBefore(first) && !day.isAfter(last),
      'Hay días excluidos fuera del horizonte.',
    );
  }
  final active = input.target.isAfter(input.now);
  var welkin = 0;
  var commissions = 0;
  if (active) {
    for (var i = 0; i <= dayCount; i++) {
      final key = dateKey(first.add(Duration(days: i)));
      if (input.skippedLoginDays.contains(key)) continue;
      if (i < input.welkinDays && (i > 0 || !input.welkinTodayClaimed)) {
        welkin++;
      }
      if (input.commissions &&
          !input.skippedCommissionDays.contains(key) &&
          (i > 0 || !input.commissionsTodayClaimed)) {
        commissions++;
      }
    }
  }
  var dustWishes = 0;
  var immediateDust = 0;
  final monthly = <String, int>{
    dateKey(first).substring(0, 7): input.dustUsedThisMonth,
  };
  for (final purchase in input.purchases) {
    require(
      purchase.count >= 1 && purchase.count <= 5,
      'Un canje de polvo debe contener entre 1 y 5 destinos.',
    );
    require(
      !purchase.day.isBefore(first) && !purchase.day.isAfter(last),
      'Canje de polvo fuera del horizonte.',
    );
    require(
      !input.skippedLoginDays.contains(dateKey(purchase.day)),
      'Un canje requiere iniciar sesión ese día.',
    );
    final month = dateKey(purchase.day).substring(0, 7);
    monthly.update(
      month,
      (n) => n + purchase.count,
      ifAbsent: () => purchase.count,
    );
    require(
      monthly[month]! <= 5,
      'Superas los 5 canjes de polvo del mes $month.',
    );
    dustWishes += purchase.count;
    if (purchase.day == first) immediateDust += purchase.count;
  }
  require(
    dustWishes * 75 <= input.dust,
    'Polvo insuficiente: no se presupone polvo ganado con deseos futuros.',
  );
  var confirmed = 0;
  var estimated = 0;
  for (final reward in input.rewards) {
    require(
      reward.amount >= 0 && reward.amount <= 1000000000,
      'Recompensa manual inválida.',
    );
    require(
      !reward.day.isBefore(first) && !reward.day.isAfter(last),
      'Recompensa fuera del horizonte.',
    );
    require(active, 'Con cero tiempo no se añaden recompensas futuras.');
    if (reward.confirmed) {
      confirmed += reward.amount;
    } else {
      estimated += reward.amount;
    }
  }
  final crystals = input.convertCrystals ? input.crystals : 0;
  final available = input.primogems + crystals;
  final fates = input.useAcquaint ? input.acquaint : input.intertwined;
  final base = fates + input.glitterWishes;
  final total = available + welkin * 90 + commissions * 60 + confirmed;
  return WishResult(
    nowWishes: base + immediateDust + available ~/ 160,
    projected: base + dustWishes + total ~/ 160,
    withEstimates: base + dustWishes + (total + estimated) ~/ 160,
    remainder: total % 160,
    estimatedRemainder: (total + estimated) % 160,
    otherFates: input.useAcquaint ? input.intertwined : input.acquaint,
    welkinClaims: welkin,
    commissionClaims: commissions,
    remainingDust: input.dust - dustWishes * 75,
    remainingGlitter: input.glitter - input.glitterWishes * 5,
    breakdown: Map.unmodifiable({
      'Protogemas actuales': input.primogems,
      'Cristales convertidos': crystals,
      'Bendición prevista': welkin * 90,
      'Encargos previstos': commissions * 60,
      'Extras confirmados por ti': confirmed,
      'Extras estimados': estimated,
    }),
  );
}
