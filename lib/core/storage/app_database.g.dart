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

class $DownloadedVolumesTable extends DownloadedVolumes
    with TableInfo<$DownloadedVolumesTable, DownloadedVolumeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadedVolumesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _volumeIdMeta = const VerificationMeta(
    'volumeId',
  );
  @override
  late final GeneratedColumn<int> volumeId = GeneratedColumn<int>(
    'volume_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filesVersionMeta = const VerificationMeta(
    'filesVersion',
  );
  @override
  late final GeneratedColumn<int> filesVersion = GeneratedColumn<int>(
    'files_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VolumeDownloadStatus, String>
  status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<VolumeDownloadStatus>(
        $DownloadedVolumesTable.$converterstatus,
      );
  static const VerificationMeta _receivedBytesMeta = const VerificationMeta(
    'receivedBytes',
  );
  @override
  late final GeneratedColumn<int> receivedBytes = GeneratedColumn<int>(
    'received_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archiveEtagMeta = const VerificationMeta(
    'archiveEtag',
  );
  @override
  late final GeneratedColumn<String> archiveEtag = GeneratedColumn<String>(
    'archive_etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureReasonMeta = const VerificationMeta(
    'failureReason',
  );
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
    'failure_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    volumeId,
    bookId,
    filesVersion,
    status,
    receivedBytes,
    totalBytes,
    pageCount,
    archiveEtag,
    failureReason,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloaded_volumes';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadedVolumeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('volume_id')) {
      context.handle(
        _volumeIdMeta,
        volumeId.isAcceptableOrUnknown(data['volume_id']!, _volumeIdMeta),
      );
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('files_version')) {
      context.handle(
        _filesVersionMeta,
        filesVersion.isAcceptableOrUnknown(
          data['files_version']!,
          _filesVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_filesVersionMeta);
    }
    if (data.containsKey('received_bytes')) {
      context.handle(
        _receivedBytesMeta,
        receivedBytes.isAcceptableOrUnknown(
          data['received_bytes']!,
          _receivedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('archive_etag')) {
      context.handle(
        _archiveEtagMeta,
        archiveEtag.isAcceptableOrUnknown(
          data['archive_etag']!,
          _archiveEtagMeta,
        ),
      );
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
        _failureReasonMeta,
        failureReason.isAcceptableOrUnknown(
          data['failure_reason']!,
          _failureReasonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {volumeId};
  @override
  DownloadedVolumeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadedVolumeRow(
      volumeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      filesVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}files_version'],
      )!,
      status: $DownloadedVolumesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      receivedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      archiveEtag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_etag'],
      ),
      failureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_reason'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadedVolumesTable createAlias(String alias) {
    return $DownloadedVolumesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<VolumeDownloadStatus, String, String>
  $converterstatus = const EnumNameConverter<VolumeDownloadStatus>(
    VolumeDownloadStatus.values,
  );
}

class DownloadedVolumeRow extends DataClass
    implements Insertable<DownloadedVolumeRow> {
  final int volumeId;

  /// タイトル単位の一括操作（#10 / #13）で使う。
  final int bookId;

  /// 取得した内容のバージョン（ZIP の mtime）。
  ///
  /// サーバー側の `files_version` と食い違ったら「更新あり」。
  final int filesVersion;
  final VolumeDownloadStatus status;

  /// 取得済みバイト数（表示用。再開位置は一時ファイルの実サイズを正とする）。
  final int receivedBytes;

  /// ZIP 全体のバイト数（マニフェストの `archive_bytes`）。
  final int totalBytes;

  /// マニフェストのページ数（検証と #11 のページ解決に使う）。
  final int pageCount;

  /// アーカイブの検証子。再開時の `If-Range` に使う。
  final String? archiveEtag;

  /// 失敗理由（ユーザーに見せる日本語）。
  final String? failureReason;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const DownloadedVolumeRow({
    required this.volumeId,
    required this.bookId,
    required this.filesVersion,
    required this.status,
    required this.receivedBytes,
    required this.totalBytes,
    required this.pageCount,
    this.archiveEtag,
    this.failureReason,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['volume_id'] = Variable<int>(volumeId);
    map['book_id'] = Variable<int>(bookId);
    map['files_version'] = Variable<int>(filesVersion);
    {
      map['status'] = Variable<String>(
        $DownloadedVolumesTable.$converterstatus.toSql(status),
      );
    }
    map['received_bytes'] = Variable<int>(receivedBytes);
    map['total_bytes'] = Variable<int>(totalBytes);
    map['page_count'] = Variable<int>(pageCount);
    if (!nullToAbsent || archiveEtag != null) {
      map['archive_etag'] = Variable<String>(archiveEtag);
    }
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadedVolumesCompanion toCompanion(bool nullToAbsent) {
    return DownloadedVolumesCompanion(
      volumeId: Value(volumeId),
      bookId: Value(bookId),
      filesVersion: Value(filesVersion),
      status: Value(status),
      receivedBytes: Value(receivedBytes),
      totalBytes: Value(totalBytes),
      pageCount: Value(pageCount),
      archiveEtag: archiveEtag == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveEtag),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadedVolumeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadedVolumeRow(
      volumeId: serializer.fromJson<int>(json['volumeId']),
      bookId: serializer.fromJson<int>(json['bookId']),
      filesVersion: serializer.fromJson<int>(json['filesVersion']),
      status: $DownloadedVolumesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      receivedBytes: serializer.fromJson<int>(json['receivedBytes']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      archiveEtag: serializer.fromJson<String?>(json['archiveEtag']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'volumeId': serializer.toJson<int>(volumeId),
      'bookId': serializer.toJson<int>(bookId),
      'filesVersion': serializer.toJson<int>(filesVersion),
      'status': serializer.toJson<String>(
        $DownloadedVolumesTable.$converterstatus.toJson(status),
      ),
      'receivedBytes': serializer.toJson<int>(receivedBytes),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'pageCount': serializer.toJson<int>(pageCount),
      'archiveEtag': serializer.toJson<String?>(archiveEtag),
      'failureReason': serializer.toJson<String?>(failureReason),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadedVolumeRow copyWith({
    int? volumeId,
    int? bookId,
    int? filesVersion,
    VolumeDownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    int? pageCount,
    Value<String?> archiveEtag = const Value.absent(),
    Value<String?> failureReason = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadedVolumeRow(
    volumeId: volumeId ?? this.volumeId,
    bookId: bookId ?? this.bookId,
    filesVersion: filesVersion ?? this.filesVersion,
    status: status ?? this.status,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    pageCount: pageCount ?? this.pageCount,
    archiveEtag: archiveEtag.present ? archiveEtag.value : this.archiveEtag,
    failureReason: failureReason.present
        ? failureReason.value
        : this.failureReason,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadedVolumeRow copyWithCompanion(DownloadedVolumesCompanion data) {
    return DownloadedVolumeRow(
      volumeId: data.volumeId.present ? data.volumeId.value : this.volumeId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      filesVersion: data.filesVersion.present
          ? data.filesVersion.value
          : this.filesVersion,
      status: data.status.present ? data.status.value : this.status,
      receivedBytes: data.receivedBytes.present
          ? data.receivedBytes.value
          : this.receivedBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      archiveEtag: data.archiveEtag.present
          ? data.archiveEtag.value
          : this.archiveEtag,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedVolumeRow(')
          ..write('volumeId: $volumeId, ')
          ..write('bookId: $bookId, ')
          ..write('filesVersion: $filesVersion, ')
          ..write('status: $status, ')
          ..write('receivedBytes: $receivedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('pageCount: $pageCount, ')
          ..write('archiveEtag: $archiveEtag, ')
          ..write('failureReason: $failureReason, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    volumeId,
    bookId,
    filesVersion,
    status,
    receivedBytes,
    totalBytes,
    pageCount,
    archiveEtag,
    failureReason,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadedVolumeRow &&
          other.volumeId == this.volumeId &&
          other.bookId == this.bookId &&
          other.filesVersion == this.filesVersion &&
          other.status == this.status &&
          other.receivedBytes == this.receivedBytes &&
          other.totalBytes == this.totalBytes &&
          other.pageCount == this.pageCount &&
          other.archiveEtag == this.archiveEtag &&
          other.failureReason == this.failureReason &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class DownloadedVolumesCompanion extends UpdateCompanion<DownloadedVolumeRow> {
  final Value<int> volumeId;
  final Value<int> bookId;
  final Value<int> filesVersion;
  final Value<VolumeDownloadStatus> status;
  final Value<int> receivedBytes;
  final Value<int> totalBytes;
  final Value<int> pageCount;
  final Value<String?> archiveEtag;
  final Value<String?> failureReason;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  const DownloadedVolumesCompanion({
    this.volumeId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.filesVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.receivedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.archiveEtag = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  DownloadedVolumesCompanion.insert({
    this.volumeId = const Value.absent(),
    required int bookId,
    required int filesVersion,
    required VolumeDownloadStatus status,
    this.receivedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.archiveEtag = const Value.absent(),
    this.failureReason = const Value.absent(),
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
  }) : bookId = Value(bookId),
       filesVersion = Value(filesVersion),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadedVolumeRow> custom({
    Expression<int>? volumeId,
    Expression<int>? bookId,
    Expression<int>? filesVersion,
    Expression<String>? status,
    Expression<int>? receivedBytes,
    Expression<int>? totalBytes,
    Expression<int>? pageCount,
    Expression<String>? archiveEtag,
    Expression<String>? failureReason,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (volumeId != null) 'volume_id': volumeId,
      if (bookId != null) 'book_id': bookId,
      if (filesVersion != null) 'files_version': filesVersion,
      if (status != null) 'status': status,
      if (receivedBytes != null) 'received_bytes': receivedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (pageCount != null) 'page_count': pageCount,
      if (archiveEtag != null) 'archive_etag': archiveEtag,
      if (failureReason != null) 'failure_reason': failureReason,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  DownloadedVolumesCompanion copyWith({
    Value<int>? volumeId,
    Value<int>? bookId,
    Value<int>? filesVersion,
    Value<VolumeDownloadStatus>? status,
    Value<int>? receivedBytes,
    Value<int>? totalBytes,
    Value<int>? pageCount,
    Value<String?>? archiveEtag,
    Value<String?>? failureReason,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
  }) {
    return DownloadedVolumesCompanion(
      volumeId: volumeId ?? this.volumeId,
      bookId: bookId ?? this.bookId,
      filesVersion: filesVersion ?? this.filesVersion,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      pageCount: pageCount ?? this.pageCount,
      archiveEtag: archiveEtag ?? this.archiveEtag,
      failureReason: failureReason ?? this.failureReason,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (volumeId.present) {
      map['volume_id'] = Variable<int>(volumeId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (filesVersion.present) {
      map['files_version'] = Variable<int>(filesVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $DownloadedVolumesTable.$converterstatus.toSql(status.value),
      );
    }
    if (receivedBytes.present) {
      map['received_bytes'] = Variable<int>(receivedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (archiveEtag.present) {
      map['archive_etag'] = Variable<String>(archiveEtag.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedVolumesCompanion(')
          ..write('volumeId: $volumeId, ')
          ..write('bookId: $bookId, ')
          ..write('filesVersion: $filesVersion, ')
          ..write('status: $status, ')
          ..write('receivedBytes: $receivedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('pageCount: $pageCount, ')
          ..write('archiveEtag: $archiveEtag, ')
          ..write('failureReason: $failureReason, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressesTable extends ReadingProgresses
    with TableInfo<$ReadingProgressesTable, ReadingProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _volumeIdMeta = const VerificationMeta(
    'volumeId',
  );
  @override
  late final GeneratedColumn<int> volumeId = GeneratedColumn<int>(
    'volume_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentPageMeta = const VerificationMeta(
    'currentPage',
  );
  @override
  late final GeneratedColumn<int> currentPage = GeneratedColumn<int>(
    'current_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxPageMeta = const VerificationMeta(
    'maxPage',
  );
  @override
  late final GeneratedColumn<int> maxPage = GeneratedColumn<int>(
    'max_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    volumeId,
    currentPage,
    maxPage,
    readAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('volume_id')) {
      context.handle(
        _volumeIdMeta,
        volumeId.isAcceptableOrUnknown(data['volume_id']!, _volumeIdMeta),
      );
    }
    if (data.containsKey('current_page')) {
      context.handle(
        _currentPageMeta,
        currentPage.isAcceptableOrUnknown(
          data['current_page']!,
          _currentPageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentPageMeta);
    }
    if (data.containsKey('max_page')) {
      context.handle(
        _maxPageMeta,
        maxPage.isAcceptableOrUnknown(data['max_page']!, _maxPageMeta),
      );
    } else if (isInserting) {
      context.missing(_maxPageMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    } else if (isInserting) {
      context.missing(_readAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {volumeId};
  @override
  ReadingProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressRow(
      volumeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume_id'],
      )!,
      currentPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_page'],
      )!,
      maxPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_page'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $ReadingProgressesTable createAlias(String alias) {
    return $ReadingProgressesTable(attachedDatabase, alias);
  }
}

class ReadingProgressRow extends DataClass
    implements Insertable<ReadingProgressRow> {
  final int volumeId;

  /// 表示していたページ（1 始まり）。`min(page, files.length)` に丸めた値。
  final int currentPage;

  /// 巻のページ数。0 ページ（ZIP が無い）の巻は行を作らない。
  final int maxPage;

  /// 端末が読んだと申告する時刻。一括同期 API の新旧比較はこの値同士で行う。
  final DateTime readAt;

  /// サーバーへ反映済みか。`false` の行だけを送る。
  final bool synced;
  const ReadingProgressRow({
    required this.volumeId,
    required this.currentPage,
    required this.maxPage,
    required this.readAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['volume_id'] = Variable<int>(volumeId);
    map['current_page'] = Variable<int>(currentPage);
    map['max_page'] = Variable<int>(maxPage);
    map['read_at'] = Variable<DateTime>(readAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  ReadingProgressesCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressesCompanion(
      volumeId: Value(volumeId),
      currentPage: Value(currentPage),
      maxPage: Value(maxPage),
      readAt: Value(readAt),
      synced: Value(synced),
    );
  }

  factory ReadingProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressRow(
      volumeId: serializer.fromJson<int>(json['volumeId']),
      currentPage: serializer.fromJson<int>(json['currentPage']),
      maxPage: serializer.fromJson<int>(json['maxPage']),
      readAt: serializer.fromJson<DateTime>(json['readAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'volumeId': serializer.toJson<int>(volumeId),
      'currentPage': serializer.toJson<int>(currentPage),
      'maxPage': serializer.toJson<int>(maxPage),
      'readAt': serializer.toJson<DateTime>(readAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  ReadingProgressRow copyWith({
    int? volumeId,
    int? currentPage,
    int? maxPage,
    DateTime? readAt,
    bool? synced,
  }) => ReadingProgressRow(
    volumeId: volumeId ?? this.volumeId,
    currentPage: currentPage ?? this.currentPage,
    maxPage: maxPage ?? this.maxPage,
    readAt: readAt ?? this.readAt,
    synced: synced ?? this.synced,
  );
  ReadingProgressRow copyWithCompanion(ReadingProgressesCompanion data) {
    return ReadingProgressRow(
      volumeId: data.volumeId.present ? data.volumeId.value : this.volumeId,
      currentPage: data.currentPage.present
          ? data.currentPage.value
          : this.currentPage,
      maxPage: data.maxPage.present ? data.maxPage.value : this.maxPage,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressRow(')
          ..write('volumeId: $volumeId, ')
          ..write('currentPage: $currentPage, ')
          ..write('maxPage: $maxPage, ')
          ..write('readAt: $readAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(volumeId, currentPage, maxPage, readAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressRow &&
          other.volumeId == this.volumeId &&
          other.currentPage == this.currentPage &&
          other.maxPage == this.maxPage &&
          other.readAt == this.readAt &&
          other.synced == this.synced);
}

class ReadingProgressesCompanion extends UpdateCompanion<ReadingProgressRow> {
  final Value<int> volumeId;
  final Value<int> currentPage;
  final Value<int> maxPage;
  final Value<DateTime> readAt;
  final Value<bool> synced;
  const ReadingProgressesCompanion({
    this.volumeId = const Value.absent(),
    this.currentPage = const Value.absent(),
    this.maxPage = const Value.absent(),
    this.readAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  ReadingProgressesCompanion.insert({
    this.volumeId = const Value.absent(),
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
    this.synced = const Value.absent(),
  }) : currentPage = Value(currentPage),
       maxPage = Value(maxPage),
       readAt = Value(readAt);
  static Insertable<ReadingProgressRow> custom({
    Expression<int>? volumeId,
    Expression<int>? currentPage,
    Expression<int>? maxPage,
    Expression<DateTime>? readAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (volumeId != null) 'volume_id': volumeId,
      if (currentPage != null) 'current_page': currentPage,
      if (maxPage != null) 'max_page': maxPage,
      if (readAt != null) 'read_at': readAt,
      if (synced != null) 'synced': synced,
    });
  }

  ReadingProgressesCompanion copyWith({
    Value<int>? volumeId,
    Value<int>? currentPage,
    Value<int>? maxPage,
    Value<DateTime>? readAt,
    Value<bool>? synced,
  }) {
    return ReadingProgressesCompanion(
      volumeId: volumeId ?? this.volumeId,
      currentPage: currentPage ?? this.currentPage,
      maxPage: maxPage ?? this.maxPage,
      readAt: readAt ?? this.readAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (volumeId.present) {
      map['volume_id'] = Variable<int>(volumeId.value);
    }
    if (currentPage.present) {
      map['current_page'] = Variable<int>(currentPage.value);
    }
    if (maxPage.present) {
      map['max_page'] = Variable<int>(maxPage.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressesCompanion(')
          ..write('volumeId: $volumeId, ')
          ..write('currentPage: $currentPage, ')
          ..write('maxPage: $maxPage, ')
          ..write('readAt: $readAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $OfflineMetadataEntriesTable extends OfflineMetadataEntries
    with TableInfo<$OfflineMetadataEntriesTable, OfflineMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineMetadataEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
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
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, payload, etag, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineMetadataRow> instance, {
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
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  OfflineMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineMetadataRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $OfflineMetadataEntriesTable createAlias(String alias) {
    return $OfflineMetadataEntriesTable(attachedDatabase, alias);
  }
}

class OfflineMetadataRow extends DataClass
    implements Insertable<OfflineMetadataRow> {
  /// `books` / `categories` / `tags` / `book/{bookId}` / `volume/{volumeId}`。
  final String key;

  /// モデルの `toJson()` をそのまま入れた JSON。
  final String payload;

  /// 次回の `If-None-Match` に使う（一覧のみ）。
  final String? etag;
  final DateTime fetchedAt;
  const OfflineMetadataRow({
    required this.key,
    required this.payload,
    this.etag,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  OfflineMetadataEntriesCompanion toCompanion(bool nullToAbsent) {
    return OfflineMetadataEntriesCompanion(
      key: Value(key),
      payload: Value(payload),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory OfflineMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineMetadataRow(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      etag: serializer.fromJson<String?>(json['etag']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'etag': serializer.toJson<String?>(etag),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  OfflineMetadataRow copyWith({
    String? key,
    String? payload,
    Value<String?> etag = const Value.absent(),
    DateTime? fetchedAt,
  }) => OfflineMetadataRow(
    key: key ?? this.key,
    payload: payload ?? this.payload,
    etag: etag.present ? etag.value : this.etag,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  OfflineMetadataRow copyWithCompanion(OfflineMetadataEntriesCompanion data) {
    return OfflineMetadataRow(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      etag: data.etag.present ? data.etag.value : this.etag,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineMetadataRow(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('etag: $etag, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload, etag, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineMetadataRow &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.etag == this.etag &&
          other.fetchedAt == this.fetchedAt);
}

class OfflineMetadataEntriesCompanion
    extends UpdateCompanion<OfflineMetadataRow> {
  final Value<String> key;
  final Value<String> payload;
  final Value<String?> etag;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const OfflineMetadataEntriesCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.etag = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineMetadataEntriesCompanion.insert({
    required String key,
    required String payload,
    this.etag = const Value.absent(),
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload),
       fetchedAt = Value(fetchedAt);
  static Insertable<OfflineMetadataRow> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<String>? etag,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (etag != null) 'etag': etag,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineMetadataEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<String?>? etag,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return OfflineMetadataEntriesCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      etag: etag ?? this.etag,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineMetadataEntriesCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('etag: $etag, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PinnedImagesTable extends PinnedImages
    with TableInfo<$PinnedImagesTable, PinnedImageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PinnedImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, bookId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pinned_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<PinnedImageRow> instance, {
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
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PinnedImageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PinnedImageRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
    );
  }

  @override
  $PinnedImagesTable createAlias(String alias) {
    return $PinnedImagesTable(attachedDatabase, alias);
  }
}

class PinnedImageRow extends DataClass implements Insertable<PinnedImageRow> {
  /// キャッシュキー（`MediaUrls.thumbnailCacheKey`）。
  final String key;

  /// どのタイトルのために保護しているか（ダウンロードを消したら印も消す）。
  final int bookId;
  const PinnedImageRow({required this.key, required this.bookId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['book_id'] = Variable<int>(bookId);
    return map;
  }

  PinnedImagesCompanion toCompanion(bool nullToAbsent) {
    return PinnedImagesCompanion(key: Value(key), bookId: Value(bookId));
  }

  factory PinnedImageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PinnedImageRow(
      key: serializer.fromJson<String>(json['key']),
      bookId: serializer.fromJson<int>(json['bookId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'bookId': serializer.toJson<int>(bookId),
    };
  }

  PinnedImageRow copyWith({String? key, int? bookId}) =>
      PinnedImageRow(key: key ?? this.key, bookId: bookId ?? this.bookId);
  PinnedImageRow copyWithCompanion(PinnedImagesCompanion data) {
    return PinnedImageRow(
      key: data.key.present ? data.key.value : this.key,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PinnedImageRow(')
          ..write('key: $key, ')
          ..write('bookId: $bookId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, bookId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PinnedImageRow &&
          other.key == this.key &&
          other.bookId == this.bookId);
}

class PinnedImagesCompanion extends UpdateCompanion<PinnedImageRow> {
  final Value<String> key;
  final Value<int> bookId;
  final Value<int> rowid;
  const PinnedImagesCompanion({
    this.key = const Value.absent(),
    this.bookId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PinnedImagesCompanion.insert({
    required String key,
    required int bookId,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       bookId = Value(bookId);
  static Insertable<PinnedImageRow> custom({
    Expression<String>? key,
    Expression<int>? bookId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (bookId != null) 'book_id': bookId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PinnedImagesCompanion copyWith({
    Value<String>? key,
    Value<int>? bookId,
    Value<int>? rowid,
  }) {
    return PinnedImagesCompanion(
      key: key ?? this.key,
      bookId: bookId ?? this.bookId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PinnedImagesCompanion(')
          ..write('key: $key, ')
          ..write('bookId: $bookId, ')
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
  late final $DownloadedVolumesTable downloadedVolumes =
      $DownloadedVolumesTable(this);
  late final $ReadingProgressesTable readingProgresses =
      $ReadingProgressesTable(this);
  late final $OfflineMetadataEntriesTable offlineMetadataEntries =
      $OfflineMetadataEntriesTable(this);
  late final $PinnedImagesTable pinnedImages = $PinnedImagesTable(this);
  late final Index cachedImagesKindLastUsedAtKey = Index(
    'cached_images_kind_last_used_at_key',
    'CREATE INDEX IF NOT EXISTS cached_images_kind_last_used_at_key ON cached_images (kind, last_used_at, "key")',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedImages,
    settings,
    downloadedVolumes,
    readingProgresses,
    offlineMetadataEntries,
    pinnedImages,
    cachedImagesKindLastUsedAtKey,
  ];
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
typedef $$DownloadedVolumesTableCreateCompanionBuilder =
    DownloadedVolumesCompanion Function({
      Value<int> volumeId,
      required int bookId,
      required int filesVersion,
      required VolumeDownloadStatus status,
      Value<int> receivedBytes,
      Value<int> totalBytes,
      Value<int> pageCount,
      Value<String?> archiveEtag,
      Value<String?> failureReason,
      required DateTime updatedAt,
      Value<DateTime?> completedAt,
    });
typedef $$DownloadedVolumesTableUpdateCompanionBuilder =
    DownloadedVolumesCompanion Function({
      Value<int> volumeId,
      Value<int> bookId,
      Value<int> filesVersion,
      Value<VolumeDownloadStatus> status,
      Value<int> receivedBytes,
      Value<int> totalBytes,
      Value<int> pageCount,
      Value<String?> archiveEtag,
      Value<String?> failureReason,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
    });

class $$DownloadedVolumesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadedVolumesTable> {
  $$DownloadedVolumesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get volumeId => $composableBuilder(
    column: $table.volumeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get filesVersion => $composableBuilder(
    column: $table.filesVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    VolumeDownloadStatus,
    VolumeDownloadStatus,
    String
  >
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archiveEtag => $composableBuilder(
    column: $table.archiveEtag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadedVolumesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadedVolumesTable> {
  $$DownloadedVolumesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get volumeId => $composableBuilder(
    column: $table.volumeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get filesVersion => $composableBuilder(
    column: $table.filesVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archiveEtag => $composableBuilder(
    column: $table.archiveEtag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadedVolumesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadedVolumesTable> {
  $$DownloadedVolumesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get volumeId =>
      $composableBuilder(column: $table.volumeId, builder: (column) => column);

  GeneratedColumn<int> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get filesVersion => $composableBuilder(
    column: $table.filesVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<VolumeDownloadStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get archiveEtag => $composableBuilder(
    column: $table.archiveEtag,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadedVolumesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadedVolumesTable,
          DownloadedVolumeRow,
          $$DownloadedVolumesTableFilterComposer,
          $$DownloadedVolumesTableOrderingComposer,
          $$DownloadedVolumesTableAnnotationComposer,
          $$DownloadedVolumesTableCreateCompanionBuilder,
          $$DownloadedVolumesTableUpdateCompanionBuilder,
          (
            DownloadedVolumeRow,
            BaseReferences<
              _$AppDatabase,
              $DownloadedVolumesTable,
              DownloadedVolumeRow
            >,
          ),
          DownloadedVolumeRow,
          PrefetchHooks Function()
        > {
  $$DownloadedVolumesTableTableManager(
    _$AppDatabase db,
    $DownloadedVolumesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadedVolumesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadedVolumesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadedVolumesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> volumeId = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<int> filesVersion = const Value.absent(),
                Value<VolumeDownloadStatus> status = const Value.absent(),
                Value<int> receivedBytes = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String?> archiveEtag = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadedVolumesCompanion(
                volumeId: volumeId,
                bookId: bookId,
                filesVersion: filesVersion,
                status: status,
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
                pageCount: pageCount,
                archiveEtag: archiveEtag,
                failureReason: failureReason,
                updatedAt: updatedAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> volumeId = const Value.absent(),
                required int bookId,
                required int filesVersion,
                required VolumeDownloadStatus status,
                Value<int> receivedBytes = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String?> archiveEtag = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadedVolumesCompanion.insert(
                volumeId: volumeId,
                bookId: bookId,
                filesVersion: filesVersion,
                status: status,
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
                pageCount: pageCount,
                archiveEtag: archiveEtag,
                failureReason: failureReason,
                updatedAt: updatedAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadedVolumesTable, DownloadedVolumeRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $DownloadedVolumesTable,
                    DownloadedVolumeRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadedVolumesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadedVolumesTable,
      DownloadedVolumeRow,
      $$DownloadedVolumesTableFilterComposer,
      $$DownloadedVolumesTableOrderingComposer,
      $$DownloadedVolumesTableAnnotationComposer,
      $$DownloadedVolumesTableCreateCompanionBuilder,
      $$DownloadedVolumesTableUpdateCompanionBuilder,
      (
        DownloadedVolumeRow,
        BaseReferences<
          _$AppDatabase,
          $DownloadedVolumesTable,
          DownloadedVolumeRow
        >,
      ),
      DownloadedVolumeRow,
      PrefetchHooks Function()
    >;
typedef $$ReadingProgressesTableCreateCompanionBuilder =
    ReadingProgressesCompanion Function({
      Value<int> volumeId,
      required int currentPage,
      required int maxPage,
      required DateTime readAt,
      Value<bool> synced,
    });
typedef $$ReadingProgressesTableUpdateCompanionBuilder =
    ReadingProgressesCompanion Function({
      Value<int> volumeId,
      Value<int> currentPage,
      Value<int> maxPage,
      Value<DateTime> readAt,
      Value<bool> synced,
    });

class $$ReadingProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get volumeId => $composableBuilder(
    column: $table.volumeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxPage => $composableBuilder(
    column: $table.maxPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get volumeId => $composableBuilder(
    column: $table.volumeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxPage => $composableBuilder(
    column: $table.maxPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get volumeId =>
      $composableBuilder(column: $table.volumeId, builder: (column) => column);

  GeneratedColumn<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxPage =>
      $composableBuilder(column: $table.maxPage, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$ReadingProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressesTable,
          ReadingProgressRow,
          $$ReadingProgressesTableFilterComposer,
          $$ReadingProgressesTableOrderingComposer,
          $$ReadingProgressesTableAnnotationComposer,
          $$ReadingProgressesTableCreateCompanionBuilder,
          $$ReadingProgressesTableUpdateCompanionBuilder,
          (
            ReadingProgressRow,
            BaseReferences<
              _$AppDatabase,
              $ReadingProgressesTable,
              ReadingProgressRow
            >,
          ),
          ReadingProgressRow,
          PrefetchHooks Function()
        > {
  $$ReadingProgressesTableTableManager(
    _$AppDatabase db,
    $ReadingProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> volumeId = const Value.absent(),
                Value<int> currentPage = const Value.absent(),
                Value<int> maxPage = const Value.absent(),
                Value<DateTime> readAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => ReadingProgressesCompanion(
                volumeId: volumeId,
                currentPage: currentPage,
                maxPage: maxPage,
                readAt: readAt,
                synced: synced,
              ),
          createCompanionCallback:
              ({
                Value<int> volumeId = const Value.absent(),
                required int currentPage,
                required int maxPage,
                required DateTime readAt,
                Value<bool> synced = const Value.absent(),
              }) => ReadingProgressesCompanion.insert(
                volumeId: volumeId,
                currentPage: currentPage,
                maxPage: maxPage,
                readAt: readAt,
                synced: synced,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingProgressesTable, ReadingProgressRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ReadingProgressesTable,
                    ReadingProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressesTable,
      ReadingProgressRow,
      $$ReadingProgressesTableFilterComposer,
      $$ReadingProgressesTableOrderingComposer,
      $$ReadingProgressesTableAnnotationComposer,
      $$ReadingProgressesTableCreateCompanionBuilder,
      $$ReadingProgressesTableUpdateCompanionBuilder,
      (
        ReadingProgressRow,
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressesTable,
          ReadingProgressRow
        >,
      ),
      ReadingProgressRow,
      PrefetchHooks Function()
    >;
typedef $$OfflineMetadataEntriesTableCreateCompanionBuilder =
    OfflineMetadataEntriesCompanion Function({
      required String key,
      required String payload,
      Value<String?> etag,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$OfflineMetadataEntriesTableUpdateCompanionBuilder =
    OfflineMetadataEntriesCompanion Function({
      Value<String> key,
      Value<String> payload,
      Value<String?> etag,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$OfflineMetadataEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineMetadataEntriesTable> {
  $$OfflineMetadataEntriesTableFilterComposer({
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

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineMetadataEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineMetadataEntriesTable> {
  $$OfflineMetadataEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineMetadataEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineMetadataEntriesTable> {
  $$OfflineMetadataEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$OfflineMetadataEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineMetadataEntriesTable,
          OfflineMetadataRow,
          $$OfflineMetadataEntriesTableFilterComposer,
          $$OfflineMetadataEntriesTableOrderingComposer,
          $$OfflineMetadataEntriesTableAnnotationComposer,
          $$OfflineMetadataEntriesTableCreateCompanionBuilder,
          $$OfflineMetadataEntriesTableUpdateCompanionBuilder,
          (
            OfflineMetadataRow,
            BaseReferences<
              _$AppDatabase,
              $OfflineMetadataEntriesTable,
              OfflineMetadataRow
            >,
          ),
          OfflineMetadataRow,
          PrefetchHooks Function()
        > {
  $$OfflineMetadataEntriesTableTableManager(
    _$AppDatabase db,
    $OfflineMetadataEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineMetadataEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OfflineMetadataEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfflineMetadataEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineMetadataEntriesCompanion(
                key: key,
                payload: payload,
                etag: etag,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                Value<String?> etag = const Value.absent(),
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => OfflineMetadataEntriesCompanion.insert(
                key: key,
                payload: payload,
                etag: etag,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfflineMetadataEntriesTable, OfflineMetadataRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $OfflineMetadataEntriesTable,
                    OfflineMetadataRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineMetadataEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineMetadataEntriesTable,
      OfflineMetadataRow,
      $$OfflineMetadataEntriesTableFilterComposer,
      $$OfflineMetadataEntriesTableOrderingComposer,
      $$OfflineMetadataEntriesTableAnnotationComposer,
      $$OfflineMetadataEntriesTableCreateCompanionBuilder,
      $$OfflineMetadataEntriesTableUpdateCompanionBuilder,
      (
        OfflineMetadataRow,
        BaseReferences<
          _$AppDatabase,
          $OfflineMetadataEntriesTable,
          OfflineMetadataRow
        >,
      ),
      OfflineMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$PinnedImagesTableCreateCompanionBuilder =
    PinnedImagesCompanion Function({
      required String key,
      required int bookId,
      Value<int> rowid,
    });
typedef $$PinnedImagesTableUpdateCompanionBuilder =
    PinnedImagesCompanion Function({
      Value<String> key,
      Value<int> bookId,
      Value<int> rowid,
    });

class $$PinnedImagesTableFilterComposer
    extends Composer<_$AppDatabase, $PinnedImagesTable> {
  $$PinnedImagesTableFilterComposer({
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

  ColumnFilters<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PinnedImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $PinnedImagesTable> {
  $$PinnedImagesTableOrderingComposer({
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

  ColumnOrderings<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PinnedImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PinnedImagesTable> {
  $$PinnedImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);
}

class $$PinnedImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PinnedImagesTable,
          PinnedImageRow,
          $$PinnedImagesTableFilterComposer,
          $$PinnedImagesTableOrderingComposer,
          $$PinnedImagesTableAnnotationComposer,
          $$PinnedImagesTableCreateCompanionBuilder,
          $$PinnedImagesTableUpdateCompanionBuilder,
          (
            PinnedImageRow,
            BaseReferences<_$AppDatabase, $PinnedImagesTable, PinnedImageRow>,
          ),
          PinnedImageRow,
          PrefetchHooks Function()
        > {
  $$PinnedImagesTableTableManager(_$AppDatabase db, $PinnedImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PinnedImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PinnedImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PinnedImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<int> bookId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PinnedImagesCompanion(key: key, bookId: bookId, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required int bookId,
                Value<int> rowid = const Value.absent(),
              }) => PinnedImagesCompanion.insert(
                key: key,
                bookId: bookId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PinnedImagesTable, PinnedImageRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PinnedImagesTable,
                    PinnedImageRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PinnedImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PinnedImagesTable,
      PinnedImageRow,
      $$PinnedImagesTableFilterComposer,
      $$PinnedImagesTableOrderingComposer,
      $$PinnedImagesTableAnnotationComposer,
      $$PinnedImagesTableCreateCompanionBuilder,
      $$PinnedImagesTableUpdateCompanionBuilder,
      (
        PinnedImageRow,
        BaseReferences<_$AppDatabase, $PinnedImagesTable, PinnedImageRow>,
      ),
      PinnedImageRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedImagesTableTableManager get cachedImages =>
      $$CachedImagesTableTableManager(_db, _db.cachedImages);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DownloadedVolumesTableTableManager get downloadedVolumes =>
      $$DownloadedVolumesTableTableManager(_db, _db.downloadedVolumes);
  $$ReadingProgressesTableTableManager get readingProgresses =>
      $$ReadingProgressesTableTableManager(_db, _db.readingProgresses);
  $$OfflineMetadataEntriesTableTableManager get offlineMetadataEntries =>
      $$OfflineMetadataEntriesTableTableManager(
        _db,
        _db.offlineMetadataEntries,
      );
  $$PinnedImagesTableTableManager get pinnedImages =>
      $$PinnedImagesTableTableManager(_db, _db.pinnedImages);
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
