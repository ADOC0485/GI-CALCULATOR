import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_connection.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = openAppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});
