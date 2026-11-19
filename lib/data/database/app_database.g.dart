// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PreferenceEntriesTable extends PreferenceEntries
    with TableInfo<$PreferenceEntriesTable, PreferenceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferenceEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _appearanceMeta = const VerificationMeta(
    'appearance',
  );
  @override
  late final GeneratedColumn<String> appearance = GeneratedColumn<String>(
    'appearance',
    aliasedName,
    false,
    check: () => appearance.isIn(['dark', 'light', 'system']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, appearance];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preference_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferenceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('appearance')) {
      context.handle(
        _appearanceMeta,
        appearance.isAcceptableOrUnknown(data['appearance']!, _appearanceMeta),
      );
    } else if (isInserting) {
      context.missing(_appearanceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PreferenceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferenceEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      appearance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}appearance'],
      )!,
    );
  }

  @override
  $PreferenceEntriesTable createAlias(String alias) {
    return $PreferenceEntriesTable(attachedDatabase, alias);
  }
}

class PreferenceEntry extends DataClass implements Insertable<PreferenceEntry> {
  final int id;
  final String appearance;
  const PreferenceEntry({required this.id, required this.appearance});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['appearance'] = Variable<String>(appearance);
    return map;
  }

  PreferenceEntriesCompanion toCompanion(bool nullToAbsent) {
    return PreferenceEntriesCompanion(
      id: Value(id),
      appearance: Value(appearance),
    );
  }

  factory PreferenceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferenceEntry(
      id: serializer.fromJson<int>(json['id']),
      appearance: serializer.fromJson<String>(json['appearance']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'appearance': serializer.toJson<String>(appearance),
    };
  }

  PreferenceEntry copyWith({int? id, String? appearance}) => PreferenceEntry(
    id: id ?? this.id,
    appearance: appearance ?? this.appearance,
  );
  PreferenceEntry copyWithCompanion(PreferenceEntriesCompanion data) {
    return PreferenceEntry(
      id: data.id.present ? data.id.value : this.id,
      appearance: data.appearance.present
          ? data.appearance.value
          : this.appearance,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceEntry(')
          ..write('id: $id, ')
          ..write('appearance: $appearance')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, appearance);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferenceEntry &&
          other.id == this.id &&
          other.appearance == this.appearance);
}

class PreferenceEntriesCompanion extends UpdateCompanion<PreferenceEntry> {
  final Value<int> id;
  final Value<String> appearance;
  const PreferenceEntriesCompanion({
    this.id = const Value.absent(),
    this.appearance = const Value.absent(),
  });
  PreferenceEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String appearance,
  }) : appearance = Value(appearance);
  static Insertable<PreferenceEntry> custom({
    Expression<int>? id,
    Expression<String>? appearance,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (appearance != null) 'appearance': appearance,
    });
  }

  PreferenceEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? appearance,
  }) {
    return PreferenceEntriesCompanion(
      id: id ?? this.id,
      appearance: appearance ?? this.appearance,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (appearance.present) {
      map['appearance'] = Variable<String>(appearance.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceEntriesCompanion(')
          ..write('id: $id, ')
          ..write('appearance: $appearance')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PreferenceEntriesTable preferenceEntries =
      $PreferenceEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [preferenceEntries];
}

typedef $$PreferenceEntriesTableCreateCompanionBuilder =
    PreferenceEntriesCompanion Function({
      Value<int> id,
      required String appearance,
    });
typedef $$PreferenceEntriesTableUpdateCompanionBuilder =
    PreferenceEntriesCompanion Function({
      Value<int> id,
      Value<String> appearance,
    });

class $$PreferenceEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PreferenceEntriesTable> {
  $$PreferenceEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appearance => $composableBuilder(
    column: $table.appearance,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferenceEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferenceEntriesTable> {
  $$PreferenceEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appearance => $composableBuilder(
    column: $table.appearance,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferenceEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferenceEntriesTable> {
  $$PreferenceEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get appearance => $composableBuilder(
    column: $table.appearance,
    builder: (column) => column,
  );
}

class $$PreferenceEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferenceEntriesTable,
          PreferenceEntry,
          $$PreferenceEntriesTableFilterComposer,
          $$PreferenceEntriesTableOrderingComposer,
          $$PreferenceEntriesTableAnnotationComposer,
          $$PreferenceEntriesTableCreateCompanionBuilder,
          $$PreferenceEntriesTableUpdateCompanionBuilder,
          (
            PreferenceEntry,
            BaseReferences<
              _$AppDatabase,
              $PreferenceEntriesTable,
              PreferenceEntry
            >,
          ),
          PreferenceEntry,
          PrefetchHooks Function()
        > {
  $$PreferenceEntriesTableTableManager(
    _$AppDatabase db,
    $PreferenceEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferenceEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferenceEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferenceEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> appearance = const Value.absent(),
          }) => PreferenceEntriesCompanion(id: id, appearance: appearance),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String appearance,
              }) => PreferenceEntriesCompanion.insert(
                id: id,
                appearance: appearance,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferenceEntriesTable, PreferenceEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PreferenceEntriesTable,
                    PreferenceEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferenceEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferenceEntriesTable,
      PreferenceEntry,
      $$PreferenceEntriesTableFilterComposer,
      $$PreferenceEntriesTableOrderingComposer,
      $$PreferenceEntriesTableAnnotationComposer,
      $$PreferenceEntriesTableCreateCompanionBuilder,
      $$PreferenceEntriesTableUpdateCompanionBuilder,
      (
        PreferenceEntry,
        BaseReferences<_$AppDatabase, $PreferenceEntriesTable, PreferenceEntry>,
      ),
      PreferenceEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PreferenceEntriesTableTableManager get preferenceEntries =>
      $$PreferenceEntriesTableTableManager(_db, _db.preferenceEntries);
}
