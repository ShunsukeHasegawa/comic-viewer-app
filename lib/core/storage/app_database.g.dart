// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedImagesTable extends CachedImages
    with TableInfo<$CachedImagesTable, CachedImageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CachedImageKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CachedImageKind>($CachedImagesTable.$converterkind);
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    kind,
    fileName,
    bytes,
    contentType,
    createdAt,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedImageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUsedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CachedImageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedImageRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      kind: $CachedImagesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      )!,
    );
  }

  @override
  $CachedImagesTable createAlias(String alias) {
    return $CachedImagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CachedImageKind, String, String> $converterkind =
      const EnumNameConverter<CachedImageKind>(CachedImageKind.values);
}

class CachedImageRow extends DataClass implements Insertable<CachedImageRow> {
  /// キャッシュキー（`MediaUrls.pageCacheKey` / `thumbnailCacheKey`）。
  final String key;

  /// 種別（ページ / サムネイル）。上限を別枠で管理する。
  final CachedImageKind kind;

  /// 保存先のファイル名（キャッシュディレクトリからの相対パス）。
  final String fileName;
  final int bytes;

  /// 画像の Content-Type（表示時のヒント。不明なら null）。
  final String? contentType;
  final DateTime createdAt;

  /// 最後に使った時刻（LRU の基準）。
  final DateTime lastUsedAt;
  const CachedImageRow({
    required this.key,
    required this.kind,
    required this.fileName,
    required this.bytes,
    this.contentType,
    required this.createdAt,
    required this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    {
      map['kind'] = Variable<String>(
        $CachedImagesTable.$converterkind.toSql(kind),
      );
    }
    map['file_name'] = Variable<String>(fileName);
    map['bytes'] = Variable<int>(bytes);
    if (!nullToAbsent || contentType != null) {
      map['content_type'] = Variable<String>(contentType);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    return map;
  }

  CachedImagesCompanion toCompanion(bool nullToAbsent) {
    return CachedImagesCompanion(
      key: Value(key),
      kind: Value(kind),
      fileName: Value(fileName),
      bytes: Value(bytes),
      contentType: contentType == null && nullToAbsent
          ? const Value.absent()
          : Value(contentType),
      createdAt: Value(createdAt),
      lastUsedAt: Value(lastUsedAt),
    );
  }

  factory CachedImageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedImageRow(
      key: serializer.fromJson<String>(json['key']),
      kind: $CachedImagesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      fileName: serializer.fromJson<String>(json['fileName']),
      bytes: serializer.fromJson<int>(json['bytes']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'kind': serializer.toJson<String>(
        $CachedImagesTable.$converterkind.toJson(kind),
      ),
      'fileName': serializer.toJson<String>(fileName),
      'bytes': serializer.toJson<int>(bytes),
      'contentType': serializer.toJson<String?>(contentType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime>(lastUsedAt),
    };
  }

  CachedImageRow copyWith({
    String? key,
    CachedImageKind? kind,
    String? fileName,
    int? bytes,
    Value<String?> contentType = const Value.absent(),
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) => CachedImageRow(
    key: key ?? this.key,
    kind: kind ?? this.kind,
    fileName: fileName ?? this.fileName,
    bytes: bytes ?? this.bytes,
    contentType: contentType.present ? contentType.value : this.contentType,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );
  CachedImageRow copyWithCompanion(CachedImagesCompanion data) {
    return CachedImageRow(
      key: data.key.present ? data.key.value : this.key,
      kind: data.kind.present ? data.kind.value : this.kind,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedImageRow(')
          ..write('key: $key, ')
          ..write('kind: $kind, ')
          ..write('fileName: $fileName, ')
          ..write('bytes: $bytes, ')
          ..write('contentType: $contentType, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    kind,
    fileName,
    bytes,
    contentType,
    createdAt,
    lastUsedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedImageRow &&
          other.key == this.key &&
          other.kind == this.kind &&
          other.fileName == this.fileName &&
          other.bytes == this.bytes &&
          other.contentType == this.contentType &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class CachedImagesCompanion extends UpdateCompanion<CachedImageRow> {
  final Value<String> key;
  final Value<CachedImageKind> kind;
  final Value<String> fileName;
  final Value<int> bytes;
  final Value<String?> contentType;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUsedAt;
  final Value<int> rowid;
  const CachedImagesCompanion({
    this.key = const Value.absent(),
    this.kind = const Value.absent(),
    this.fileName = const Value.absent(),
    this.bytes = const Value.absent(),
    this.contentType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedImagesCompanion.insert({
    required String key,
    required CachedImageKind kind,
    required String fileName,
    required int bytes,
    this.contentType = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastUsedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       kind = Value(kind),
       fileName = Value(fileName),
       bytes = Value(bytes),
       createdAt = Value(createdAt),
       lastUsedAt = Value(lastUsedAt);
  static Insertable<CachedImageRow> custom({
    Expression<String>? key,
    Expression<String>? kind,
    Expression<String>? fileName,
    Expression<int>? bytes,
    Expression<String>? contentType,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (kind != null) 'kind': kind,
      if (fileName != null) 'file_name': fileName,
      if (bytes != null) 'bytes': bytes,
      if (contentType != null) 'content_type': contentType,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedImagesCompanion copyWith({
    Value<String>? key,
    Value<CachedImageKind>? kind,
    Value<String>? fileName,
    Value<int>? bytes,
    Value<String?>? contentType,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastUsedAt,
    Value<int>? rowid,
  }) {
    return CachedImagesCompanion(
      key: key ?? this.key,
      kind: kind ?? this.kind,
      fileName: fileName ?? this.fileName,
      bytes: bytes ?? this.bytes,
      contentType: contentType ?? this.contentType,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CachedImagesTable.$converterkind.toSql(kind.value),
      );
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedImagesCompanion(')
          ..write('key: $key, ')
          ..write('kind: $kind, ')
          ..write('fileName: $fileName, ')
          ..write('bytes: $bytes, ')
          ..write('contentType: $contentType, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedImagesTable cachedImages = $CachedImagesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedImages, settings];
}

typedef $$CachedImagesTableCreateCompanionBuilder =
    CachedImagesCompanion Function({
      required String key,
      required CachedImageKind kind,
      required String fileName,
      required int bytes,
      Value<String?> contentType,
      required DateTime createdAt,
      required DateTime lastUsedAt,
      Value<int> rowid,
    });
typedef $$CachedImagesTableUpdateCompanionBuilder =
    CachedImagesCompanion Function({
      Value<String> key,
      Value<CachedImageKind> kind,
      Value<String> fileName,
      Value<int> bytes,
      Value<String?> contentType,
      Value<DateTime> createdAt,
      Value<DateTime> lastUsedAt,
      Value<int> rowid,
    });

class $$CachedImagesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedImagesTable> {
  $$CachedImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CachedImageKind, CachedImageKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedImagesTable> {
  $$CachedImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedImagesTable> {
  $$CachedImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CachedImageKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );
}

class $$CachedImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedImagesTable,
          CachedImageRow,
          $$CachedImagesTableFilterComposer,
          $$CachedImagesTableOrderingComposer,
          $$CachedImagesTableAnnotationComposer,
          $$CachedImagesTableCreateCompanionBuilder,
          $$CachedImagesTableUpdateCompanionBuilder,
          (
            CachedImageRow,
            BaseReferences<_$AppDatabase, $CachedImagesTable, CachedImageRow>,
          ),
          CachedImageRow,
          PrefetchHooks Function()
        > {
  $$CachedImagesTableTableManager(_$AppDatabase db, $CachedImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<CachedImageKind> kind = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedImagesCompanion(
                key: key,
                kind: kind,
                fileName: fileName,
                bytes: bytes,
                contentType: contentType,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required CachedImageKind kind,
                required String fileName,
                required int bytes,
                Value<String?> contentType = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastUsedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedImagesCompanion.insert(
                key: key,
                kind: kind,
                fileName: fileName,
                bytes: bytes,
                contentType: contentType,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedImagesTable, CachedImageRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedImagesTable,
                    CachedImageRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedImagesTable,
      CachedImageRow,
      $$CachedImagesTableFilterComposer,
      $$CachedImagesTableOrderingComposer,
      $$CachedImagesTableAnnotationComposer,
      $$CachedImagesTableCreateCompanionBuilder,
      $$CachedImagesTableUpdateCompanionBuilder,
      (
        CachedImageRow,
        BaseReferences<_$AppDatabase, $CachedImagesTable, CachedImageRow>,
      ),
      CachedImageRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedImagesTableTableManager get cachedImages =>
      $$CachedImagesTableTableManager(_db, _db.cachedImages);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'44154e51c3f3079ee293d8ad0ebd1e17cca871ed';
