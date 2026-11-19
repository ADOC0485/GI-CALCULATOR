import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

AppDatabase openAppDatabase({Future<String> Function()? databasePath}) =>
    AppDatabase(
      driftDatabase(
        name: 'genshin_progress_planner',
        native: DriftNativeOptions(
          databasePath: databasePath,
          databaseDirectory: databasePath == null
              ? getApplicationSupportDirectory
              : null,
        ),
      ),
    );
