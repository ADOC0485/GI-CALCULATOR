import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../progression/data/scenario_repository.dart';

/// Account currencies the player keeps an eye on (editable, like resin).
class Wallet {
  const Wallet({
    this.primogems = 0,
    this.genesis = 0,
    this.commissionMora = defaultCommissionMora,
  });
  final int primogems, genesis;

  /// Mora added when the daily commissions are checked. It grows with the
  /// Adventure Rank and has changed between versions, so it is an estimate
  /// the player can set to what they really get.
  final int commissionMora;

  /// 4 commissions × 10 + 20 from Katheryne's daily reward.
  static const commissionPrimogems = 60;

  /// Blessing of the Welkin Moon, claimed every day.
  static const welkinPrimogems = 90;

  /// 4 × 4 900 + 9 600 (community guide figure, high Adventure Rank).
  static const defaultCommissionMora = 29200;

  Wallet copyWith({int? primogems, int? genesis, int? commissionMora}) =>
      Wallet(
        primogems: primogems ?? this.primogems,
        genesis: genesis ?? this.genesis,
        commissionMora: commissionMora ?? this.commissionMora,
      );

  Map<String, Object?> toJson() => {
    'primogems': primogems,
    'genesis': genesis,
    'commissionMora': commissionMora,
  };

  factory Wallet.fromJson(Map<String, dynamic>? json) {
    int count(String key, int fallback) =>
        json?[key] is int ? json![key] as int : fallback;
    return Wallet(
      primogems: count('primogems', 0),
      genesis: count('genesis', 0),
      commissionMora: count('commissionMora', defaultCommissionMora),
    );
  }
}

final walletProvider = AsyncNotifierProvider<WalletController, Wallet>(
  WalletController.new,
);

class WalletController extends AsyncNotifier<Wallet> {
  static const _key = 'cartera';

  @override
  Future<Wallet> build() async =>
      Wallet.fromJson(await ref.watch(scenarioRepositoryProvider).load(_key));

  Future<void> save(Wallet next) async {
    await ref.read(scenarioRepositoryProvider).save(_key, next.toJson());
    state = AsyncData(next);
  }

  /// Adds (or with a negative value removes) Primogems.
  Future<void> addPrimogems(int amount) async {
    final current = state.asData?.value ?? await future;
    await save(
      current.copyWith(
        primogems: (current.primogems + amount).clamp(0, 1 << 30),
      ),
    );
  }
}
