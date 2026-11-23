import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../builds/data/build_repository.dart';
import '../progression/data/scenario_repository.dart';

/// Game servers, as chosen when logging in.
const servers = ['América', 'Europa', 'Asia', 'TW, HK, MO', 'China'];

/// Fixed UTC offset of each server's clock (no daylight saving).
const serverUtcOffsetHours = {
  'América': -5,
  'Europa': 1,
  'Asia': 8,
  'TW, HK, MO': 8,
  'China': 8,
};

/// Daily reset hour, in server time; the week resets on Monday at this hour.
const resetHour = 4;

/// Server clock shifted so that the game day starts at midnight.
DateTime _shifted(DateTime now, String server) => now.toUtc().add(
  Duration(hours: (serverUtcOffsetHours[server] ?? -5) - resetHour),
);

/// The game day [now] belongs to on [server] (it changes at 04:00 there).
DateTime gameDay(DateTime now, String server) {
  final t = _shifted(now, server);
  return DateTime(t.year, t.month, t.day);
}

/// Time left until the next daily reset on [server].
Duration untilDailyReset(DateTime now, String server) {
  final t = _shifted(now, server);
  return DateTime.utc(t.year, t.month, t.day + 1).difference(t);
}

/// Time left until the weekly reset (Monday 04:00 server time).
Duration untilWeeklyReset(DateTime now, String server) {
  final t = _shifted(now, server);
  final daysToMonday = (DateTime.monday - t.weekday + 7) % 7;
  return untilDailyReset(now, server) +
      Duration(days: daysToMonday == 0 ? 6 : daysToMonday - 1);
}

/// Server of the profile in use.
final activeServerProvider = Provider<String>(
  (ref) =>
      ref.watch(profilesProvider).asData?.value.active.server ?? servers.first,
);

/// A player account: its own builds, inventory, resin and history.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.server = 'América',
    this.worldLevel = 8,
    this.adventureRank,
    this.gender,
    this.avatarId,
  });
  final String id, name, server;
  final int worldLevel;
  final int? adventureRank;

  /// 'Masculino' or 'Femenino'; used for the welcome message.
  final String? gender;

  /// Catalog ID of the character shown as avatar.
  final String? avatarId;

  /// «Bienvenido», «Bienvenida» or a neutral greeting.
  String get greeting => switch (gender) {
    'Masculino' => '¡Bienvenido, $name!',
    'Femenino' => '¡Bienvenida, $name!',
    _ => '¡Hola, $name!',
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'server': server,
    'worldLevel': worldLevel,
    'adventureRank': adventureRank,
    'gender': gender,
    'avatarId': avatarId,
  };

  static Profile? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id'], name = value['name'];
    if (id is! String || name is! String) return null;
    return Profile(
      id: id,
      name: name,
      server: value['server'] is String ? value['server'] as String : 'América',
      worldLevel: value['worldLevel'] is int ? value['worldLevel'] as int : 8,
      adventureRank: value['adventureRank'] as int?,
      gender: value['gender'] as String?,
      avatarId: value['avatarId'] as String?,
    );
  }
}

class Profiles {
  const Profiles(this.items, this.activeId);
  final List<Profile> items;
  final String activeId;
  Profile get active =>
      items.firstWhere((p) => p.id == activeId, orElse: () => items.first);
}

final profilesProvider = AsyncNotifierProvider<ProfilesController, Profiles>(
  ProfilesController.new,
);

/// Stores profiles in the shared scenario table under one key.
class ProfilesController extends AsyncNotifier<Profiles> {
  static const key = 'perfiles';

  ScenarioRepository get _shared => ref.read(sharedScenarioRepositoryProvider);

  @override
  Future<Profiles> build() async {
    final stored = await ref.watch(sharedScenarioRepositoryProvider).load(key);
    final items = [
      for (final item in (stored?['items'] as List?) ?? const [])
        ?Profile.fromJson(item),
    ];
    if (items.isEmpty) {
      // First run: the existing data becomes the first profile.
      final raw = await _shared.load(BuildRepository.inventoryKey);
      items.add(
        Profile(
          id: defaultProfileId,
          name: 'Viajero',
          worldLevel: int.tryParse('${raw?['worldLevel']}') ?? 8,
          adventureRank: int.tryParse('${raw?['adventureRank']}'),
        ),
      );
    }
    final active =
        stored?['active'] is String &&
            items.any((p) => p.id == stored!['active'])
        ? stored!['active'] as String
        : items.first.id;
    _select(active);
    return Profiles(items, active);
  }

  void _select(String id) {
    if (ref.read(activeProfileIdProvider) != id) {
      ref.read(activeProfileIdProvider.notifier).select(id);
    }
  }

  Future<void> _store(Profiles value) async {
    await _shared.save(key, {
      'active': value.activeId,
      'items': [for (final p in value.items) p.toJson()],
    });
    state = AsyncData(value);
  }

  /// Creates or updates a profile; its World Level and AR also go to that
  /// profile's inventory, which the planners read.
  Future<void> save(Profile profile, {bool activate = false}) async {
    final current = await future;
    final items = [...current.items];
    final index = items.indexWhere((p) => p.id == profile.id);
    if (index < 0) {
      items.add(profile);
    } else {
      items[index] = profile;
    }
    final repo = BuildRepository(
      ScenarioRepository(
        ref.read(databaseProvider),
        prefix: profilePrefix(profile.id),
      ),
    );
    await repo.updateInventory({
      'worldLevel': '${profile.worldLevel}',
      'adventureRank': profile.adventureRank == null
          ? ''
          : '${profile.adventureRank}',
    });
    final active = activate ? profile.id : current.activeId;
    await _store(Profiles(items, active));
    _select(active);
    ref.invalidate(inventoryProvider);
  }

  Future<void> activate(String id) async {
    final current = await future;
    await _store(Profiles(current.items, id));
    _select(id);
  }

  /// Deletes a profile and all its data. The active one cannot be deleted.
  Future<void> delete(String id) async {
    final current = await future;
    if (id == current.activeId || current.items.length < 2) return;
    await _shared.deleteProfileData(id, keep: {key});
    await _store(
      Profiles([...current.items.where((p) => p.id != id)], current.activeId),
    );
  }
}
