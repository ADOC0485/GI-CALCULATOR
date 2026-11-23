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

class $CatalogVersionsTable extends CatalogVersions
    with TableInfo<$CatalogVersionsTable, CatalogVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<String> importedAt = GeneratedColumn<String>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    sequence,
    payload,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {version};
  @override
  CatalogVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogVersion(
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $CatalogVersionsTable createAlias(String alias) {
    return $CatalogVersionsTable(attachedDatabase, alias);
  }
}

class CatalogVersion extends DataClass implements Insertable<CatalogVersion> {
  final String version;
  final int sequence;
  final String payload;
  final String importedAt;
  const CatalogVersion({
    required this.version,
    required this.sequence,
    required this.payload,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<String>(version);
    map['sequence'] = Variable<int>(sequence);
    map['payload'] = Variable<String>(payload);
    map['imported_at'] = Variable<String>(importedAt);
    return map;
  }

  CatalogVersionsCompanion toCompanion(bool nullToAbsent) {
    return CatalogVersionsCompanion(
      version: Value(version),
      sequence: Value(sequence),
      payload: Value(payload),
      importedAt: Value(importedAt),
    );
  }

  factory CatalogVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogVersion(
      version: serializer.fromJson<String>(json['version']),
      sequence: serializer.fromJson<int>(json['sequence']),
      payload: serializer.fromJson<String>(json['payload']),
      importedAt: serializer.fromJson<String>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<String>(version),
      'sequence': serializer.toJson<int>(sequence),
      'payload': serializer.toJson<String>(payload),
      'importedAt': serializer.toJson<String>(importedAt),
    };
  }

  CatalogVersion copyWith({
    String? version,
    int? sequence,
    String? payload,
    String? importedAt,
  }) => CatalogVersion(
    version: version ?? this.version,
    sequence: sequence ?? this.sequence,
    payload: payload ?? this.payload,
    importedAt: importedAt ?? this.importedAt,
  );
  CatalogVersion copyWithCompanion(CatalogVersionsCompanion data) {
    return CatalogVersion(
      version: data.version.present ? data.version.value : this.version,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      payload: data.payload.present ? data.payload.value : this.payload,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogVersion(')
          ..write('version: $version, ')
          ..write('sequence: $sequence, ')
          ..write('payload: $payload, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(version, sequence, payload, importedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogVersion &&
          other.version == this.version &&
          other.sequence == this.sequence &&
          other.payload == this.payload &&
          other.importedAt == this.importedAt);
}

class CatalogVersionsCompanion extends UpdateCompanion<CatalogVersion> {
  final Value<String> version;
  final Value<int> sequence;
  final Value<String> payload;
  final Value<String> importedAt;
  final Value<int> rowid;
  const CatalogVersionsCompanion({
    this.version = const Value.absent(),
    this.sequence = const Value.absent(),
    this.payload = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogVersionsCompanion.insert({
    required String version,
    required int sequence,
    required String payload,
    required String importedAt,
    this.rowid = const Value.absent(),
  }) : version = Value(version),
       sequence = Value(sequence),
       payload = Value(payload),
       importedAt = Value(importedAt);
  static Insertable<CatalogVersion> custom({
    Expression<String>? version,
    Expression<int>? sequence,
    Expression<String>? payload,
    Expression<String>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (sequence != null) 'sequence': sequence,
      if (payload != null) 'payload': payload,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogVersionsCompanion copyWith({
    Value<String>? version,
    Value<int>? sequence,
    Value<String>? payload,
    Value<String>? importedAt,
    Value<int>? rowid,
  }) {
    return CatalogVersionsCompanion(
      version: version ?? this.version,
      sequence: sequence ?? this.sequence,
      payload: payload ?? this.payload,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<String>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogVersionsCompanion(')
          ..write('version: $version, ')
          ..write('sequence: $sequence, ')
          ..write('payload: $payload, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogRecordsTable extends CatalogRecords
    with TableInfo<$CatalogRecordsTable, CatalogRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _catalogVersionMeta = const VerificationMeta(
    'catalogVersion',
  );
  @override
  late final GeneratedColumn<String> catalogVersion = GeneratedColumn<String>(
    'catalog_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_versions (version)',
    ),
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [catalogVersion, recordId, kind, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('catalog_version')) {
      context.handle(
        _catalogVersionMeta,
        catalogVersion.isAcceptableOrUnknown(
          data['catalog_version']!,
          _catalogVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_catalogVersionMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {catalogVersion, recordId};
  @override
  CatalogRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogRecord(
      catalogVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catalog_version'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $CatalogRecordsTable createAlias(String alias) {
    return $CatalogRecordsTable(attachedDatabase, alias);
  }
}

class CatalogRecord extends DataClass implements Insertable<CatalogRecord> {
  final String catalogVersion;
  final String recordId;
  final String kind;
  final String name;
  const CatalogRecord({
    required this.catalogVersion,
    required this.recordId,
    required this.kind,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['catalog_version'] = Variable<String>(catalogVersion);
    map['record_id'] = Variable<String>(recordId);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    return map;
  }

  CatalogRecordsCompanion toCompanion(bool nullToAbsent) {
    return CatalogRecordsCompanion(
      catalogVersion: Value(catalogVersion),
      recordId: Value(recordId),
      kind: Value(kind),
      name: Value(name),
    );
  }

  factory CatalogRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogRecord(
      catalogVersion: serializer.fromJson<String>(json['catalogVersion']),
      recordId: serializer.fromJson<String>(json['recordId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'catalogVersion': serializer.toJson<String>(catalogVersion),
      'recordId': serializer.toJson<String>(recordId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
    };
  }

  CatalogRecord copyWith({
    String? catalogVersion,
    String? recordId,
    String? kind,
    String? name,
  }) => CatalogRecord(
    catalogVersion: catalogVersion ?? this.catalogVersion,
    recordId: recordId ?? this.recordId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
  );
  CatalogRecord copyWithCompanion(CatalogRecordsCompanion data) {
    return CatalogRecord(
      catalogVersion: data.catalogVersion.present
          ? data.catalogVersion.value
          : this.catalogVersion,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogRecord(')
          ..write('catalogVersion: $catalogVersion, ')
          ..write('recordId: $recordId, ')
          ..write('kind: $kind, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(catalogVersion, recordId, kind, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogRecord &&
          other.catalogVersion == this.catalogVersion &&
          other.recordId == this.recordId &&
          other.kind == this.kind &&
          other.name == this.name);
}

class CatalogRecordsCompanion extends UpdateCompanion<CatalogRecord> {
  final Value<String> catalogVersion;
  final Value<String> recordId;
  final Value<String> kind;
  final Value<String> name;
  final Value<int> rowid;
  const CatalogRecordsCompanion({
    this.catalogVersion = const Value.absent(),
    this.recordId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogRecordsCompanion.insert({
    required String catalogVersion,
    required String recordId,
    required String kind,
    required String name,
    this.rowid = const Value.absent(),
  }) : catalogVersion = Value(catalogVersion),
       recordId = Value(recordId),
       kind = Value(kind),
       name = Value(name);
  static Insertable<CatalogRecord> custom({
    Expression<String>? catalogVersion,
    Expression<String>? recordId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (catalogVersion != null) 'catalog_version': catalogVersion,
      if (recordId != null) 'record_id': recordId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogRecordsCompanion copyWith({
    Value<String>? catalogVersion,
    Value<String>? recordId,
    Value<String>? kind,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return CatalogRecordsCompanion(
      catalogVersion: catalogVersion ?? this.catalogVersion,
      recordId: recordId ?? this.recordId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (catalogVersion.present) {
      map['catalog_version'] = Variable<String>(catalogVersion.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogRecordsCompanion(')
          ..write('catalogVersion: $catalogVersion, ')
          ..write('recordId: $recordId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogSelectionTable extends CatalogSelection
    with TableInfo<$CatalogSelectionTable, CatalogSelectionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogSelectionTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _catalogVersionMeta = const VerificationMeta(
    'catalogVersion',
  );
  @override
  late final GeneratedColumn<String> catalogVersion = GeneratedColumn<String>(
    'catalog_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_versions (version)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, catalogVersion];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_selection';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogSelectionData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('catalog_version')) {
      context.handle(
        _catalogVersionMeta,
        catalogVersion.isAcceptableOrUnknown(
          data['catalog_version']!,
          _catalogVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_catalogVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogSelectionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogSelectionData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      catalogVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catalog_version'],
      )!,
    );
  }

  @override
  $CatalogSelectionTable createAlias(String alias) {
    return $CatalogSelectionTable(attachedDatabase, alias);
  }
}

class CatalogSelectionData extends DataClass
    implements Insertable<CatalogSelectionData> {
  final int id;
  final String catalogVersion;
  const CatalogSelectionData({required this.id, required this.catalogVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['catalog_version'] = Variable<String>(catalogVersion);
    return map;
  }

  CatalogSelectionCompanion toCompanion(bool nullToAbsent) {
    return CatalogSelectionCompanion(
      id: Value(id),
      catalogVersion: Value(catalogVersion),
    );
  }

  factory CatalogSelectionData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogSelectionData(
      id: serializer.fromJson<int>(json['id']),
      catalogVersion: serializer.fromJson<String>(json['catalogVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'catalogVersion': serializer.toJson<String>(catalogVersion),
    };
  }

  CatalogSelectionData copyWith({int? id, String? catalogVersion}) =>
      CatalogSelectionData(
        id: id ?? this.id,
        catalogVersion: catalogVersion ?? this.catalogVersion,
      );
  CatalogSelectionData copyWithCompanion(CatalogSelectionCompanion data) {
    return CatalogSelectionData(
      id: data.id.present ? data.id.value : this.id,
      catalogVersion: data.catalogVersion.present
          ? data.catalogVersion.value
          : this.catalogVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogSelectionData(')
          ..write('id: $id, ')
          ..write('catalogVersion: $catalogVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, catalogVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogSelectionData &&
          other.id == this.id &&
          other.catalogVersion == this.catalogVersion);
}

class CatalogSelectionCompanion extends UpdateCompanion<CatalogSelectionData> {
  final Value<int> id;
  final Value<String> catalogVersion;
  const CatalogSelectionCompanion({
    this.id = const Value.absent(),
    this.catalogVersion = const Value.absent(),
  });
  CatalogSelectionCompanion.insert({
    this.id = const Value.absent(),
    required String catalogVersion,
  }) : catalogVersion = Value(catalogVersion);
  static Insertable<CatalogSelectionData> custom({
    Expression<int>? id,
    Expression<String>? catalogVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (catalogVersion != null) 'catalog_version': catalogVersion,
    });
  }

  CatalogSelectionCompanion copyWith({
    Value<int>? id,
    Value<String>? catalogVersion,
  }) {
    return CatalogSelectionCompanion(
      id: id ?? this.id,
      catalogVersion: catalogVersion ?? this.catalogVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (catalogVersion.present) {
      map['catalog_version'] = Variable<String>(catalogVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogSelectionCompanion(')
          ..write('id: $id, ')
          ..write('catalogVersion: $catalogVersion')
          ..write(')'))
        .toString();
  }
}

class $CalculatorScenariosTable extends CalculatorScenarios
    with TableInfo<$CalculatorScenariosTable, CalculatorScenario> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalculatorScenariosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calculator_scenarios';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalculatorScenario> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalculatorScenario map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalculatorScenario(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $CalculatorScenariosTable createAlias(String alias) {
    return $CalculatorScenariosTable(attachedDatabase, alias);
  }
}

class CalculatorScenario extends DataClass
    implements Insertable<CalculatorScenario> {
  final String id;
  final String payload;
  const CalculatorScenario({required this.id, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CalculatorScenariosCompanion toCompanion(bool nullToAbsent) {
    return CalculatorScenariosCompanion(id: Value(id), payload: Value(payload));
  }

  factory CalculatorScenario.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalculatorScenario(
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CalculatorScenario copyWith({String? id, String? payload}) =>
      CalculatorScenario(id: id ?? this.id, payload: payload ?? this.payload);
  CalculatorScenario copyWithCompanion(CalculatorScenariosCompanion data) {
    return CalculatorScenario(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalculatorScenario(')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalculatorScenario &&
          other.id == this.id &&
          other.payload == this.payload);
}

class CalculatorScenariosCompanion extends UpdateCompanion<CalculatorScenario> {
  final Value<String> id;
  final Value<String> payload;
  final Value<int> rowid;
  const CalculatorScenariosCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalculatorScenariosCompanion.insert({
    required String id,
    required String payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payload = Value(payload);
  static Insertable<CalculatorScenario> custom({
    Expression<String>? id,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalculatorScenariosCompanion copyWith({
    Value<String>? id,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return CalculatorScenariosCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalculatorScenariosCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PreferenceEntriesTable preferenceEntries =
      $PreferenceEntriesTable(this);
  late final $CatalogVersionsTable catalogVersions = $CatalogVersionsTable(
    this,
  );
  late final $CatalogRecordsTable catalogRecords = $CatalogRecordsTable(this);
  late final $CatalogSelectionTable catalogSelection = $CatalogSelectionTable(
    this,
  );
  late final $CalculatorScenariosTable calculatorScenarios =
      $CalculatorScenariosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    preferenceEntries,
    catalogVersions,
    catalogRecords,
    catalogSelection,
    calculatorScenarios,
  ];
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
typedef $$CatalogVersionsTableCreateCompanionBuilder =
    CatalogVersionsCompanion Function({
      required String version,
      required int sequence,
      required String payload,
      required String importedAt,
      Value<int> rowid,
    });
typedef $$CatalogVersionsTableUpdateCompanionBuilder =
    CatalogVersionsCompanion Function({
      Value<String> version,
      Value<int> sequence,
      Value<String> payload,
      Value<String> importedAt,
      Value<int> rowid,
    });

final class $$CatalogVersionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CatalogVersionsTable, CatalogVersion> {
  $$CatalogVersionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CatalogRecordsTable, List<CatalogRecord>>
  _catalogRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.catalogRecords,
    aliasName: 'catalog_versions__version__catalog_records__catalog_version',
  );

  $$CatalogRecordsTableProcessedTableManager get catalogRecordsRefs {
    final manager = $$CatalogRecordsTableTableManager($_db, $_db.catalogRecords)
        .filter(
          (f) => f.catalogVersion.version.sqlEquals(
            $_itemColumn<String>('version')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_catalogRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CatalogSelectionTable, List<CatalogSelectionData>>
  _catalogSelectionRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.catalogSelection,
    aliasName: 'catalog_versions__version__catalog_selection__catalog_version',
  );

  $$CatalogSelectionTableProcessedTableManager get catalogSelectionRefs {
    final manager =
        $$CatalogSelectionTableTableManager($_db, $_db.catalogSelection).filter(
          (f) => f.catalogVersion.version.sqlEquals(
            $_itemColumn<String>('version')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _catalogSelectionRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CatalogVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogVersionsTable> {
  $$CatalogVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> catalogRecordsRefs(
    Expression<bool> Function($$CatalogRecordsTableFilterComposer f) f,
  ) {
    final $$CatalogRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.version,
      referencedTable: $db.catalogRecords,
      getReferencedColumn: (t) => t.catalogVersion,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogRecordsTableFilterComposer(
            $db: $db,
            $table: $db.catalogRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> catalogSelectionRefs(
    Expression<bool> Function($$CatalogSelectionTableFilterComposer f) f,
  ) {
    final $$CatalogSelectionTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.version,
      referencedTable: $db.catalogSelection,
      getReferencedColumn: (t) => t.catalogVersion,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogSelectionTableFilterComposer(
            $db: $db,
            $table: $db.catalogSelection,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatalogVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogVersionsTable> {
  $$CatalogVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogVersionsTable> {
  $$CatalogVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  Expression<T> catalogRecordsRefs<T extends Object>(
    Expression<T> Function($$CatalogRecordsTableAnnotationComposer a) f,
  ) {
    final $$CatalogRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.version,
      referencedTable: $db.catalogRecords,
      getReferencedColumn: (t) => t.catalogVersion,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> catalogSelectionRefs<T extends Object>(
    Expression<T> Function($$CatalogSelectionTableAnnotationComposer a) f,
  ) {
    final $$CatalogSelectionTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.version,
      referencedTable: $db.catalogSelection,
      getReferencedColumn: (t) => t.catalogVersion,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogSelectionTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogSelection,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatalogVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogVersionsTable,
          CatalogVersion,
          $$CatalogVersionsTableFilterComposer,
          $$CatalogVersionsTableOrderingComposer,
          $$CatalogVersionsTableAnnotationComposer,
          $$CatalogVersionsTableCreateCompanionBuilder,
          $$CatalogVersionsTableUpdateCompanionBuilder,
          (CatalogVersion, $$CatalogVersionsTableReferences),
          CatalogVersion,
          PrefetchHooks Function({
            bool catalogRecordsRefs,
            bool catalogSelectionRefs,
          })
        > {
  $$CatalogVersionsTableTableManager(
    _$AppDatabase db,
    $CatalogVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> version = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogVersionsCompanion(
                version: version,
                sequence: sequence,
                payload: payload,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String version,
                required int sequence,
                required String payload,
                required String importedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatalogVersionsCompanion.insert(
                version: version,
                sequence: sequence,
                payload: payload,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogVersionsTable, CatalogVersion>(table),
                  $$CatalogVersionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({catalogRecordsRefs = false, catalogSelectionRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (catalogRecordsRefs) db.catalogRecords,
                    if (catalogSelectionRefs) db.catalogSelection,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (catalogRecordsRefs)
                        await $_getPrefetchedDataByColumns<
                          CatalogVersion,
                          $CatalogVersionsTable,
                          CatalogRecord,
                          $CatalogRecordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CatalogVersionsTableReferences
                              ._catalogRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CatalogVersionsTableReferences(
                                db,
                                table,
                                p0,
                              ).catalogRecordsRefs,
                          currentColumn: 'version',
                          referencedColumn: 'catalog_version',
                          typedResults: items,
                        ),
                      if (catalogSelectionRefs)
                        await $_getPrefetchedDataByColumns<
                          CatalogVersion,
                          $CatalogVersionsTable,
                          CatalogSelectionData,
                          $CatalogSelectionTable
                        >(
                          currentTable: table,
                          referencedTable: $$CatalogVersionsTableReferences
                              ._catalogSelectionRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CatalogVersionsTableReferences(
                                db,
                                table,
                                p0,
                              ).catalogSelectionRefs,
                          currentColumn: 'version',
                          referencedColumn: 'catalog_version',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CatalogVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogVersionsTable,
      CatalogVersion,
      $$CatalogVersionsTableFilterComposer,
      $$CatalogVersionsTableOrderingComposer,
      $$CatalogVersionsTableAnnotationComposer,
      $$CatalogVersionsTableCreateCompanionBuilder,
      $$CatalogVersionsTableUpdateCompanionBuilder,
      (CatalogVersion, $$CatalogVersionsTableReferences),
      CatalogVersion,
      PrefetchHooks Function({
        bool catalogRecordsRefs,
        bool catalogSelectionRefs,
      })
    >;
typedef $$CatalogRecordsTableCreateCompanionBuilder =
    CatalogRecordsCompanion Function({
      required String catalogVersion,
      required String recordId,
      required String kind,
      required String name,
      Value<int> rowid,
    });
typedef $$CatalogRecordsTableUpdateCompanionBuilder =
    CatalogRecordsCompanion Function({
      Value<String> catalogVersion,
      Value<String> recordId,
      Value<String> kind,
      Value<String> name,
      Value<int> rowid,
    });

final class $$CatalogRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $CatalogRecordsTable, CatalogRecord> {
  $$CatalogRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CatalogVersionsTable _catalogVersionTable(_$AppDatabase db) =>
      db.catalogVersions.createAlias(
        'catalog_records__catalog_version__catalog_versions__version',
      );

  $$CatalogVersionsTableProcessedTableManager get catalogVersion {
    final $_column = $_itemColumn<String>('catalog_version')!;

    final manager = $$CatalogVersionsTableTableManager(
      $_db,
      $_db.catalogVersions,
    ).filter((f) => f.version.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_catalogVersionTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CatalogRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogRecordsTable> {
  $$CatalogRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  $$CatalogVersionsTableFilterComposer get catalogVersion {
    final $$CatalogVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogVersion,
      referencedTable: $db.catalogVersions,
      getReferencedColumn: (t) => t.version,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogVersionsTableFilterComposer(
            $db: $db,
            $table: $db.catalogVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogRecordsTable> {
  $$CatalogRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  $$CatalogVersionsTableOrderingComposer get catalogVersion {
    final $$CatalogVersionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogVersion,
      referencedTable: $db.catalogVersions,
      getReferencedColumn: (t) => t.version,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogVersionsTableOrderingComposer(
            $db: $db,
            $table: $db.catalogVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogRecordsTable> {
  $$CatalogRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  $$CatalogVersionsTableAnnotationComposer get catalogVersion {
    final $$CatalogVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogVersion,
      referencedTable: $db.catalogVersions,
      getReferencedColumn: (t) => t.version,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogRecordsTable,
          CatalogRecord,
          $$CatalogRecordsTableFilterComposer,
          $$CatalogRecordsTableOrderingComposer,
          $$CatalogRecordsTableAnnotationComposer,
          $$CatalogRecordsTableCreateCompanionBuilder,
          $$CatalogRecordsTableUpdateCompanionBuilder,
          (CatalogRecord, $$CatalogRecordsTableReferences),
          CatalogRecord,
          PrefetchHooks Function({bool catalogVersion})
        > {
  $$CatalogRecordsTableTableManager(
    _$AppDatabase db,
    $CatalogRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> catalogVersion = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogRecordsCompanion(
                catalogVersion: catalogVersion,
                recordId: recordId,
                kind: kind,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String catalogVersion,
                required String recordId,
                required String kind,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => CatalogRecordsCompanion.insert(
                catalogVersion: catalogVersion,
                recordId: recordId,
                kind: kind,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogRecordsTable, CatalogRecord>(table),
                  $$CatalogRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({catalogVersion = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (catalogVersion) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.catalogVersion,
                        referencedTable: $$CatalogRecordsTableReferences
                            ._catalogVersionTable(db),
                        referencedColumn: $$CatalogRecordsTableReferences
                            ._catalogVersionTable(db)
                            .version,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CatalogRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogRecordsTable,
      CatalogRecord,
      $$CatalogRecordsTableFilterComposer,
      $$CatalogRecordsTableOrderingComposer,
      $$CatalogRecordsTableAnnotationComposer,
      $$CatalogRecordsTableCreateCompanionBuilder,
      $$CatalogRecordsTableUpdateCompanionBuilder,
      (CatalogRecord, $$CatalogRecordsTableReferences),
      CatalogRecord,
      PrefetchHooks Function({bool catalogVersion})
    >;
typedef $$CatalogSelectionTableCreateCompanionBuilder =
    CatalogSelectionCompanion Function({
      Value<int> id,
      required String catalogVersion,
    });
typedef $$CatalogSelectionTableUpdateCompanionBuilder =
    CatalogSelectionCompanion Function({
      Value<int> id,
      Value<String> catalogVersion,
    });

final class $$CatalogSelectionTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CatalogSelectionTable,
          CatalogSelectionData
        > {
  $$CatalogSelectionTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CatalogVersionsTable _catalogVersionTable(_$AppDatabase db) =>
      db.catalogVersions.createAlias(
        'catalog_selection__catalog_version__catalog_versions__version',
      );

  $$CatalogVersionsTableProcessedTableManager get catalogVersion {
    final $_column = $_itemColumn<String>('catalog_version')!;

    final manager = $$CatalogVersionsTableTableManager(
      $_db,
      $_db.catalogVersions,
    ).filter((f) => f.version.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_catalogVersionTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CatalogSelectionTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogSelectionTable> {
  $$CatalogSelectionTableFilterComposer({
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

  $$CatalogVersionsTableFilterComposer get catalogVersion {
    final $$CatalogVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogVersion,
      referencedTable: $db.catalogVersions,
      getReferencedColumn: (t) => t.version,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogVersionsTableFilterComposer(
            $db: $db,
            $table: $db.catalogVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogSelectionTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogSelectionTable> {
  $$CatalogSelectionTableOrderingComposer({
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

  $$CatalogVersionsTableOrderingComposer get catalogVersion {
    final $$CatalogVersionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogVersion,
      referencedTable: $db.catalogVersions,
      getReferencedColumn: (t) => t.version,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogVersionsTableOrderingComposer(
            $db: $db,
            $table: $db.catalogVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogSelectionTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogSelectionTable> {
  $$CatalogSelectionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  $$CatalogVersionsTableAnnotationComposer get catalogVersion {
    final $$CatalogVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogVersion,
      referencedTable: $db.catalogVersions,
      getReferencedColumn: (t) => t.version,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogSelectionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogSelectionTable,
          CatalogSelectionData,
          $$CatalogSelectionTableFilterComposer,
          $$CatalogSelectionTableOrderingComposer,
          $$CatalogSelectionTableAnnotationComposer,
          $$CatalogSelectionTableCreateCompanionBuilder,
          $$CatalogSelectionTableUpdateCompanionBuilder,
          (CatalogSelectionData, $$CatalogSelectionTableReferences),
          CatalogSelectionData,
          PrefetchHooks Function({bool catalogVersion})
        > {
  $$CatalogSelectionTableTableManager(
    _$AppDatabase db,
    $CatalogSelectionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogSelectionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogSelectionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogSelectionTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> catalogVersion = const Value.absent(),
              }) => CatalogSelectionCompanion(
                id: id,
                catalogVersion: catalogVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String catalogVersion,
              }) => CatalogSelectionCompanion.insert(
                id: id,
                catalogVersion: catalogVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogSelectionTable, CatalogSelectionData>(
                    table,
                  ),
                  $$CatalogSelectionTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({catalogVersion = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (catalogVersion) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.catalogVersion,
                        referencedTable: $$CatalogSelectionTableReferences
                            ._catalogVersionTable(db),
                        referencedColumn: $$CatalogSelectionTableReferences
                            ._catalogVersionTable(db)
                            .version,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CatalogSelectionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogSelectionTable,
      CatalogSelectionData,
      $$CatalogSelectionTableFilterComposer,
      $$CatalogSelectionTableOrderingComposer,
      $$CatalogSelectionTableAnnotationComposer,
      $$CatalogSelectionTableCreateCompanionBuilder,
      $$CatalogSelectionTableUpdateCompanionBuilder,
      (CatalogSelectionData, $$CatalogSelectionTableReferences),
      CatalogSelectionData,
      PrefetchHooks Function({bool catalogVersion})
    >;
typedef $$CalculatorScenariosTableCreateCompanionBuilder =
    CalculatorScenariosCompanion Function({
      required String id,
      required String payload,
      Value<int> rowid,
    });
typedef $$CalculatorScenariosTableUpdateCompanionBuilder =
    CalculatorScenariosCompanion Function({
      Value<String> id,
      Value<String> payload,
      Value<int> rowid,
    });

class $$CalculatorScenariosTableFilterComposer
    extends Composer<_$AppDatabase, $CalculatorScenariosTable> {
  $$CalculatorScenariosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalculatorScenariosTableOrderingComposer
    extends Composer<_$AppDatabase, $CalculatorScenariosTable> {
  $$CalculatorScenariosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalculatorScenariosTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalculatorScenariosTable> {
  $$CalculatorScenariosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$CalculatorScenariosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalculatorScenariosTable,
          CalculatorScenario,
          $$CalculatorScenariosTableFilterComposer,
          $$CalculatorScenariosTableOrderingComposer,
          $$CalculatorScenariosTableAnnotationComposer,
          $$CalculatorScenariosTableCreateCompanionBuilder,
          $$CalculatorScenariosTableUpdateCompanionBuilder,
          (
            CalculatorScenario,
            BaseReferences<
              _$AppDatabase,
              $CalculatorScenariosTable,
              CalculatorScenario
            >,
          ),
          CalculatorScenario,
          PrefetchHooks Function()
        > {
  $$CalculatorScenariosTableTableManager(
    _$AppDatabase db,
    $CalculatorScenariosTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalculatorScenariosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalculatorScenariosTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalculatorScenariosTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalculatorScenariosCompanion(
                id: id,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => CalculatorScenariosCompanion.insert(
                id: id,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalculatorScenariosTable, CalculatorScenario>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $CalculatorScenariosTable,
                    CalculatorScenario
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalculatorScenariosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalculatorScenariosTable,
      CalculatorScenario,
      $$CalculatorScenariosTableFilterComposer,
      $$CalculatorScenariosTableOrderingComposer,
      $$CalculatorScenariosTableAnnotationComposer,
      $$CalculatorScenariosTableCreateCompanionBuilder,
      $$CalculatorScenariosTableUpdateCompanionBuilder,
      (
        CalculatorScenario,
        BaseReferences<
          _$AppDatabase,
          $CalculatorScenariosTable,
          CalculatorScenario
        >,
      ),
      CalculatorScenario,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PreferenceEntriesTableTableManager get preferenceEntries =>
      $$PreferenceEntriesTableTableManager(_db, _db.preferenceEntries);
  $$CatalogVersionsTableTableManager get catalogVersions =>
      $$CatalogVersionsTableTableManager(_db, _db.catalogVersions);
  $$CatalogRecordsTableTableManager get catalogRecords =>
      $$CatalogRecordsTableTableManager(_db, _db.catalogRecords);
  $$CatalogSelectionTableTableManager get catalogSelection =>
      $$CatalogSelectionTableTableManager(_db, _db.catalogSelection);
  $$CalculatorScenariosTableTableManager get calculatorScenarios =>
      $$CalculatorScenariosTableTableManager(_db, _db.calculatorScenarios);
}
