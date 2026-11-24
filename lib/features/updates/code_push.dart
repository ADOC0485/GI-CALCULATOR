import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Small fixes ("parches") sent with Shorebird: they reach installed apps
/// without reinstalling. The app downloads them by itself on launch and uses
/// them the next time it is opened.
class PatchState {
  const PatchState({required this.available, this.current, this.next});

  /// False in debug builds or APKs not built with `shorebird release`.
  final bool available;

  /// Patch running now (null: none yet).
  final int? current;

  /// Newest patch already downloaded (equals [current] when there is nothing new).
  final int? next;

  /// A newer patch is downloaded and waits for the app to be reopened.
  bool get restartRequired =>
      available && next != null && (current == null || next! > current!);

  static const none = PatchState(available: false);
}

/// What the app needs from Shorebird; tests replace it.
abstract class CodePush {
  bool get isAvailable;
  Future<int?> currentPatch();
  Future<int?> nextPatch();

  /// Looks for a new patch and downloads it. True when one was downloaded.
  Future<bool> downloadUpdate();
}

class ShorebirdCodePush implements CodePush {
  // Created on first use, inside the provider's try: outside a Shorebird
  // build the updater only reports that it is unavailable.
  late final _updater = ShorebirdUpdater();

  @override
  bool get isAvailable => _updater.isAvailable;

  @override
  Future<int?> currentPatch() async =>
      (await _updater.readCurrentPatch())?.number;

  @override
  Future<int?> nextPatch() async => (await _updater.readNextPatch())?.number;

  @override
  Future<bool> downloadUpdate() async {
    if (await _updater.checkForUpdate() != UpdateStatus.outdated) return false;
    await _updater.update();
    return true;
  }
}

final codePushProvider = Provider<CodePush>((ref) => ShorebirdCodePush());

/// Reads which patch runs and whether a newer one is waiting.
/// Refresh it with `ref.invalidate`.
final patchStateProvider = FutureProvider<PatchState>((ref) async {
  final push = ref.watch(codePushProvider);
  try {
    if (!push.isAvailable) return PatchState.none;
    return PatchState(
      available: true,
      current: await push.currentPatch(),
      next: await push.nextPatch(),
    );
  } catch (_) {
    return PatchState.none;
  }
});
