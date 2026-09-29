// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'volume_status_sync.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VolumeStatusSyncItem {

@JsonKey(name: 'volume_id') int get volumeId;@JsonKey(name: 'current_page') int get currentPage;@JsonKey(name: 'max_page') int get maxPage;@JsonKey(name: 'read_at', toJson: _readAtToJson) DateTime get readAt;
/// Create a copy of VolumeStatusSyncItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolumeStatusSyncItemCopyWith<VolumeStatusSyncItem> get copyWith => _$VolumeStatusSyncItemCopyWithImpl<VolumeStatusSyncItem>(this as VolumeStatusSyncItem, _$identity);

  /// Serializes this VolumeStatusSyncItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VolumeStatusSyncItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolumeStatusSyncItem&&(identical(other.volumeId, _this.volumeId) || other.volumeId == _this.volumeId)&&(identical(other.currentPage, _this.currentPage) || other.currentPage == _this.currentPage)&&(identical(other.maxPage, _this.maxPage) || other.maxPage == _this.maxPage)&&(identical(other.readAt, _this.readAt) || other.readAt == _this.readAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VolumeStatusSyncItem;
  return Object.hash(runtimeType,_this.volumeId,_this.currentPage,_this.maxPage,_this.readAt);
}

@override
String toString() {
  final _this = this as VolumeStatusSyncItem;
  return 'VolumeStatusSyncItem(volumeId: ${_this.volumeId}, currentPage: ${_this.currentPage}, maxPage: ${_this.maxPage}, readAt: ${_this.readAt})';
}


}

/// @nodoc
abstract mixin class $VolumeStatusSyncItemCopyWith<$Res>  {
  factory $VolumeStatusSyncItemCopyWith(VolumeStatusSyncItem value, $Res Function(VolumeStatusSyncItem) _then) = _$VolumeStatusSyncItemCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'volume_id') int volumeId,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'read_at', toJson: _readAtToJson) DateTime readAt
});




}
/// @nodoc
class _$VolumeStatusSyncItemCopyWithImpl<$Res>
    implements $VolumeStatusSyncItemCopyWith<$Res> {
  _$VolumeStatusSyncItemCopyWithImpl(this._self, this._then);

  final VolumeStatusSyncItem _self;
  final $Res Function(VolumeStatusSyncItem) _then;

/// Create a copy of VolumeStatusSyncItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? volumeId = null,Object? currentPage = null,Object? maxPage = null,Object? readAt = null,}) {
  return _then(VolumeStatusSyncItem(
volumeId: null == volumeId ? _self.volumeId : volumeId // ignore: cast_nullable_to_non_nullable
as int,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,readAt: null == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [VolumeStatusSyncItem].
extension VolumeStatusSyncItemPatterns on VolumeStatusSyncItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolumeStatusSyncItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolumeStatusSyncItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolumeStatusSyncItem value)  $default,){
final _that = this;
switch (_that) {
case _VolumeStatusSyncItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolumeStatusSyncItem value)?  $default,){
final _that = this;
switch (_that) {
case _VolumeStatusSyncItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'read_at', toJson: _readAtToJson)  DateTime readAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolumeStatusSyncItem() when $default != null:
return $default(_that.volumeId,_that.currentPage,_that.maxPage,_that.readAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'read_at', toJson: _readAtToJson)  DateTime readAt)  $default,) {final _that = this;
switch (_that) {
case _VolumeStatusSyncItem():
return $default(_that.volumeId,_that.currentPage,_that.maxPage,_that.readAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'read_at', toJson: _readAtToJson)  DateTime readAt)?  $default,) {final _that = this;
switch (_that) {
case _VolumeStatusSyncItem() when $default != null:
return $default(_that.volumeId,_that.currentPage,_that.maxPage,_that.readAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolumeStatusSyncItem implements VolumeStatusSyncItem {
  const _VolumeStatusSyncItem({@JsonKey(name: 'volume_id') required this.volumeId, @JsonKey(name: 'current_page') required this.currentPage, @JsonKey(name: 'max_page') required this.maxPage, @JsonKey(name: 'read_at', toJson: _readAtToJson) required this.readAt});
  factory _VolumeStatusSyncItem.fromJson(Map<String, dynamic> json) => _$VolumeStatusSyncItemFromJson(json);

@override@JsonKey(name: 'volume_id') final  int volumeId;
@override@JsonKey(name: 'current_page') final  int currentPage;
@override@JsonKey(name: 'max_page') final  int maxPage;
@override@JsonKey(name: 'read_at', toJson: _readAtToJson) final  DateTime readAt;

/// Create a copy of VolumeStatusSyncItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolumeStatusSyncItemCopyWith<_VolumeStatusSyncItem> get copyWith => __$VolumeStatusSyncItemCopyWithImpl<_VolumeStatusSyncItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolumeStatusSyncItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolumeStatusSyncItem&&(identical(other.volumeId, volumeId) || other.volumeId == volumeId)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.maxPage, maxPage) || other.maxPage == maxPage)&&(identical(other.readAt, readAt) || other.readAt == readAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,volumeId,currentPage,maxPage,readAt);
}

@override
String toString() {
    return 'VolumeStatusSyncItem(volumeId: $volumeId, currentPage: $currentPage, maxPage: $maxPage, readAt: $readAt)';
}


}

/// @nodoc
abstract mixin class _$VolumeStatusSyncItemCopyWith<$Res> implements $VolumeStatusSyncItemCopyWith<$Res> {
  factory _$VolumeStatusSyncItemCopyWith(_VolumeStatusSyncItem value, $Res Function(_VolumeStatusSyncItem) _then) = __$VolumeStatusSyncItemCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'volume_id') int volumeId,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'read_at', toJson: _readAtToJson) DateTime readAt
});




}
/// @nodoc
class __$VolumeStatusSyncItemCopyWithImpl<$Res>
    implements _$VolumeStatusSyncItemCopyWith<$Res> {
  __$VolumeStatusSyncItemCopyWithImpl(this._self, this._then);

  final _VolumeStatusSyncItem _self;
  final $Res Function(_VolumeStatusSyncItem) _then;

/// Create a copy of VolumeStatusSyncItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? volumeId = null,Object? currentPage = null,Object? maxPage = null,Object? readAt = null,}) {
  return _then(_VolumeStatusSyncItem(
volumeId: null == volumeId ? _self.volumeId : volumeId // ignore: cast_nullable_to_non_nullable
as int,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,readAt: null == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$VolumeStatusSnapshot {

@JsonKey(name: 'volume_id') int get volumeId;@JsonKey(name: 'current_page') int get currentPage;@JsonKey(name: 'max_page') int get maxPage;@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool get isFinished;/// 端末が申告した読了時刻。`read_at` 列の追加前に作られた行では `null`。
@JsonKey(name: 'read_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? get readAt;/// サーバーが記録した時刻。`read_at` が無い行の比較に使う。
@JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? get updatedAt;
/// Create a copy of VolumeStatusSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolumeStatusSnapshotCopyWith<VolumeStatusSnapshot> get copyWith => _$VolumeStatusSnapshotCopyWithImpl<VolumeStatusSnapshot>(this as VolumeStatusSnapshot, _$identity);

  /// Serializes this VolumeStatusSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VolumeStatusSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolumeStatusSnapshot&&(identical(other.volumeId, _this.volumeId) || other.volumeId == _this.volumeId)&&(identical(other.currentPage, _this.currentPage) || other.currentPage == _this.currentPage)&&(identical(other.maxPage, _this.maxPage) || other.maxPage == _this.maxPage)&&(identical(other.isFinished, _this.isFinished) || other.isFinished == _this.isFinished)&&(identical(other.readAt, _this.readAt) || other.readAt == _this.readAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VolumeStatusSnapshot;
  return Object.hash(runtimeType,_this.volumeId,_this.currentPage,_this.maxPage,_this.isFinished,_this.readAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as VolumeStatusSnapshot;
  return 'VolumeStatusSnapshot(volumeId: ${_this.volumeId}, currentPage: ${_this.currentPage}, maxPage: ${_this.maxPage}, isFinished: ${_this.isFinished}, readAt: ${_this.readAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $VolumeStatusSnapshotCopyWith<$Res>  {
  factory $VolumeStatusSnapshotCopyWith(VolumeStatusSnapshot value, $Res Function(VolumeStatusSnapshot) _then) = _$VolumeStatusSnapshotCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'volume_id') int volumeId,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool isFinished,@JsonKey(name: 'read_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? readAt,@JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? updatedAt
});




}
/// @nodoc
class _$VolumeStatusSnapshotCopyWithImpl<$Res>
    implements $VolumeStatusSnapshotCopyWith<$Res> {
  _$VolumeStatusSnapshotCopyWithImpl(this._self, this._then);

  final VolumeStatusSnapshot _self;
  final $Res Function(VolumeStatusSnapshot) _then;

/// Create a copy of VolumeStatusSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? volumeId = null,Object? currentPage = null,Object? maxPage = null,Object? isFinished = null,Object? readAt = freezed,Object? updatedAt = freezed,}) {
  return _then(VolumeStatusSnapshot(
volumeId: null == volumeId ? _self.volumeId : volumeId // ignore: cast_nullable_to_non_nullable
as int,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,isFinished: null == isFinished ? _self.isFinished : isFinished // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [VolumeStatusSnapshot].
extension VolumeStatusSnapshotPatterns on VolumeStatusSnapshot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolumeStatusSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolumeStatusSnapshot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolumeStatusSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _VolumeStatusSnapshot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolumeStatusSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _VolumeStatusSnapshot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished, @JsonKey(name: 'read_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? readAt, @JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolumeStatusSnapshot() when $default != null:
return $default(_that.volumeId,_that.currentPage,_that.maxPage,_that.isFinished,_that.readAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished, @JsonKey(name: 'read_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? readAt, @JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _VolumeStatusSnapshot():
return $default(_that.volumeId,_that.currentPage,_that.maxPage,_that.isFinished,_that.readAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished, @JsonKey(name: 'read_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? readAt, @JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _VolumeStatusSnapshot() when $default != null:
return $default(_that.volumeId,_that.currentPage,_that.maxPage,_that.isFinished,_that.readAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolumeStatusSnapshot extends VolumeStatusSnapshot {
  const _VolumeStatusSnapshot({@JsonKey(name: 'volume_id') required this.volumeId, @JsonKey(name: 'current_page') this.currentPage = 0, @JsonKey(name: 'max_page') this.maxPage = 0, @JsonKey(name: 'is_finished', fromJson: boolFromJson) this.isFinished = false, @JsonKey(name: 'read_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) this.readAt, @JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) this.updatedAt}): super._();
  factory _VolumeStatusSnapshot.fromJson(Map<String, dynamic> json) => _$VolumeStatusSnapshotFromJson(json);

@override@JsonKey(name: 'volume_id') final  int volumeId;
@override@JsonKey(name: 'current_page') final  int currentPage;
@override@JsonKey(name: 'max_page') final  int maxPage;
@override@JsonKey(name: 'is_finished', fromJson: boolFromJson) final  bool isFinished;
/// 端末が申告した読了時刻。`read_at` 列の追加前に作られた行では `null`。
@override@JsonKey(name: 'read_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) final  DateTime? readAt;
/// サーバーが記録した時刻。`read_at` が無い行の比較に使う。
@override@JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) final  DateTime? updatedAt;

/// Create a copy of VolumeStatusSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolumeStatusSnapshotCopyWith<_VolumeStatusSnapshot> get copyWith => __$VolumeStatusSnapshotCopyWithImpl<_VolumeStatusSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolumeStatusSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolumeStatusSnapshot&&(identical(other.volumeId, volumeId) || other.volumeId == volumeId)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.maxPage, maxPage) || other.maxPage == maxPage)&&(identical(other.isFinished, isFinished) || other.isFinished == isFinished)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,volumeId,currentPage,maxPage,isFinished,readAt,updatedAt);
}

@override
String toString() {
    return 'VolumeStatusSnapshot(volumeId: $volumeId, currentPage: $currentPage, maxPage: $maxPage, isFinished: $isFinished, readAt: $readAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$VolumeStatusSnapshotCopyWith<$Res> implements $VolumeStatusSnapshotCopyWith<$Res> {
  factory _$VolumeStatusSnapshotCopyWith(_VolumeStatusSnapshot value, $Res Function(_VolumeStatusSnapshot) _then) = __$VolumeStatusSnapshotCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'volume_id') int volumeId,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool isFinished,@JsonKey(name: 'read_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? readAt,@JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? updatedAt
});




}
/// @nodoc
class __$VolumeStatusSnapshotCopyWithImpl<$Res>
    implements _$VolumeStatusSnapshotCopyWith<$Res> {
  __$VolumeStatusSnapshotCopyWithImpl(this._self, this._then);

  final _VolumeStatusSnapshot _self;
  final $Res Function(_VolumeStatusSnapshot) _then;

/// Create a copy of VolumeStatusSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? volumeId = null,Object? currentPage = null,Object? maxPage = null,Object? isFinished = null,Object? readAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_VolumeStatusSnapshot(
volumeId: null == volumeId ? _self.volumeId : volumeId // ignore: cast_nullable_to_non_nullable
as int,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,isFinished: null == isFinished ? _self.isFinished : isFinished // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$VolumeStatusSkip {

@JsonKey(name: 'volume_id') int get volumeId;@JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown) VolumeStatusSkipReason get reason;/// サーバー側の現在値（`not_found` と、記録が無い場合は `null`）。
 VolumeStatusSnapshot? get current;
/// Create a copy of VolumeStatusSkip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolumeStatusSkipCopyWith<VolumeStatusSkip> get copyWith => _$VolumeStatusSkipCopyWithImpl<VolumeStatusSkip>(this as VolumeStatusSkip, _$identity);

  /// Serializes this VolumeStatusSkip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VolumeStatusSkip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolumeStatusSkip&&(identical(other.volumeId, _this.volumeId) || other.volumeId == _this.volumeId)&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.current, _this.current) || other.current == _this.current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VolumeStatusSkip;
  return Object.hash(runtimeType,_this.volumeId,_this.reason,_this.current);
}

@override
String toString() {
  final _this = this as VolumeStatusSkip;
  return 'VolumeStatusSkip(volumeId: ${_this.volumeId}, reason: ${_this.reason}, current: ${_this.current})';
}


}

/// @nodoc
abstract mixin class $VolumeStatusSkipCopyWith<$Res>  {
  factory $VolumeStatusSkipCopyWith(VolumeStatusSkip value, $Res Function(VolumeStatusSkip) _then) = _$VolumeStatusSkipCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'volume_id') int volumeId,@JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown) VolumeStatusSkipReason reason, VolumeStatusSnapshot? current
});


$VolumeStatusSnapshotCopyWith<$Res>? get current;

}
/// @nodoc
class _$VolumeStatusSkipCopyWithImpl<$Res>
    implements $VolumeStatusSkipCopyWith<$Res> {
  _$VolumeStatusSkipCopyWithImpl(this._self, this._then);

  final VolumeStatusSkip _self;
  final $Res Function(VolumeStatusSkip) _then;

/// Create a copy of VolumeStatusSkip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? volumeId = null,Object? reason = null,Object? current = freezed,}) {
  return _then(VolumeStatusSkip(
volumeId: null == volumeId ? _self.volumeId : volumeId // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as VolumeStatusSkipReason,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as VolumeStatusSnapshot?,
  ));
}
/// Create a copy of VolumeStatusSkip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VolumeStatusSnapshotCopyWith<$Res>? get current {
    if (_self.current == null) {
    return null;
  }

  return $VolumeStatusSnapshotCopyWith<$Res>(_self.current!, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}


/// Adds pattern-matching-related methods to [VolumeStatusSkip].
extension VolumeStatusSkipPatterns on VolumeStatusSkip {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolumeStatusSkip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolumeStatusSkip() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolumeStatusSkip value)  $default,){
final _that = this;
switch (_that) {
case _VolumeStatusSkip():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolumeStatusSkip value)?  $default,){
final _that = this;
switch (_that) {
case _VolumeStatusSkip() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown)  VolumeStatusSkipReason reason,  VolumeStatusSnapshot? current)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolumeStatusSkip() when $default != null:
return $default(_that.volumeId,_that.reason,_that.current);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown)  VolumeStatusSkipReason reason,  VolumeStatusSnapshot? current)  $default,) {final _that = this;
switch (_that) {
case _VolumeStatusSkip():
return $default(_that.volumeId,_that.reason,_that.current);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'volume_id')  int volumeId, @JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown)  VolumeStatusSkipReason reason,  VolumeStatusSnapshot? current)?  $default,) {final _that = this;
switch (_that) {
case _VolumeStatusSkip() when $default != null:
return $default(_that.volumeId,_that.reason,_that.current);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolumeStatusSkip implements VolumeStatusSkip {
  const _VolumeStatusSkip({@JsonKey(name: 'volume_id') required this.volumeId, @JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown) this.reason = VolumeStatusSkipReason.unknown, this.current});
  factory _VolumeStatusSkip.fromJson(Map<String, dynamic> json) => _$VolumeStatusSkipFromJson(json);

@override@JsonKey(name: 'volume_id') final  int volumeId;
@override@JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown) final  VolumeStatusSkipReason reason;
/// サーバー側の現在値（`not_found` と、記録が無い場合は `null`）。
@override final  VolumeStatusSnapshot? current;

/// Create a copy of VolumeStatusSkip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolumeStatusSkipCopyWith<_VolumeStatusSkip> get copyWith => __$VolumeStatusSkipCopyWithImpl<_VolumeStatusSkip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolumeStatusSkipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolumeStatusSkip&&(identical(other.volumeId, volumeId) || other.volumeId == volumeId)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,volumeId,reason,current);
}

@override
String toString() {
    return 'VolumeStatusSkip(volumeId: $volumeId, reason: $reason, current: $current)';
}


}

/// @nodoc
abstract mixin class _$VolumeStatusSkipCopyWith<$Res> implements $VolumeStatusSkipCopyWith<$Res> {
  factory _$VolumeStatusSkipCopyWith(_VolumeStatusSkip value, $Res Function(_VolumeStatusSkip) _then) = __$VolumeStatusSkipCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'volume_id') int volumeId,@JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown) VolumeStatusSkipReason reason, VolumeStatusSnapshot? current
});


@override $VolumeStatusSnapshotCopyWith<$Res>? get current;

}
/// @nodoc
class __$VolumeStatusSkipCopyWithImpl<$Res>
    implements _$VolumeStatusSkipCopyWith<$Res> {
  __$VolumeStatusSkipCopyWithImpl(this._self, this._then);

  final _VolumeStatusSkip _self;
  final $Res Function(_VolumeStatusSkip) _then;

/// Create a copy of VolumeStatusSkip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? volumeId = null,Object? reason = null,Object? current = freezed,}) {
  return _then(_VolumeStatusSkip(
volumeId: null == volumeId ? _self.volumeId : volumeId // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as VolumeStatusSkipReason,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as VolumeStatusSnapshot?,
  ));
}

/// Create a copy of VolumeStatusSkip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VolumeStatusSnapshotCopyWith<$Res>? get current {
    if (_self.current == null) {
    return null;
  }

  return $VolumeStatusSnapshotCopyWith<$Res>(_self.current!, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}


/// @nodoc
mixin _$VolumeStatusSyncResult {

 List<VolumeStatusSnapshot> get applied; List<VolumeStatusSkip> get skipped;
/// Create a copy of VolumeStatusSyncResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolumeStatusSyncResultCopyWith<VolumeStatusSyncResult> get copyWith => _$VolumeStatusSyncResultCopyWithImpl<VolumeStatusSyncResult>(this as VolumeStatusSyncResult, _$identity);

  /// Serializes this VolumeStatusSyncResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VolumeStatusSyncResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolumeStatusSyncResult&&const DeepCollectionEquality().equals(other.applied, _this.applied)&&const DeepCollectionEquality().equals(other.skipped, _this.skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VolumeStatusSyncResult;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.applied),const DeepCollectionEquality().hash(_this.skipped));
}

@override
String toString() {
  final _this = this as VolumeStatusSyncResult;
  return 'VolumeStatusSyncResult(applied: ${_this.applied}, skipped: ${_this.skipped})';
}


}

/// @nodoc
abstract mixin class $VolumeStatusSyncResultCopyWith<$Res>  {
  factory $VolumeStatusSyncResultCopyWith(VolumeStatusSyncResult value, $Res Function(VolumeStatusSyncResult) _then) = _$VolumeStatusSyncResultCopyWithImpl;
@useResult
$Res call({
 List<VolumeStatusSnapshot> applied, List<VolumeStatusSkip> skipped
});




}
/// @nodoc
class _$VolumeStatusSyncResultCopyWithImpl<$Res>
    implements $VolumeStatusSyncResultCopyWith<$Res> {
  _$VolumeStatusSyncResultCopyWithImpl(this._self, this._then);

  final VolumeStatusSyncResult _self;
  final $Res Function(VolumeStatusSyncResult) _then;

/// Create a copy of VolumeStatusSyncResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? applied = null,Object? skipped = null,}) {
  return _then(VolumeStatusSyncResult(
applied: null == applied ? _self.applied : applied // ignore: cast_nullable_to_non_nullable
as List<VolumeStatusSnapshot>,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as List<VolumeStatusSkip>,
  ));
}

}


/// Adds pattern-matching-related methods to [VolumeStatusSyncResult].
extension VolumeStatusSyncResultPatterns on VolumeStatusSyncResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolumeStatusSyncResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolumeStatusSyncResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolumeStatusSyncResult value)  $default,){
final _that = this;
switch (_that) {
case _VolumeStatusSyncResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolumeStatusSyncResult value)?  $default,){
final _that = this;
switch (_that) {
case _VolumeStatusSyncResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VolumeStatusSnapshot> applied,  List<VolumeStatusSkip> skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolumeStatusSyncResult() when $default != null:
return $default(_that.applied,_that.skipped);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VolumeStatusSnapshot> applied,  List<VolumeStatusSkip> skipped)  $default,) {final _that = this;
switch (_that) {
case _VolumeStatusSyncResult():
return $default(_that.applied,_that.skipped);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VolumeStatusSnapshot> applied,  List<VolumeStatusSkip> skipped)?  $default,) {final _that = this;
switch (_that) {
case _VolumeStatusSyncResult() when $default != null:
return $default(_that.applied,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolumeStatusSyncResult implements VolumeStatusSyncResult {
  const _VolumeStatusSyncResult({ List<VolumeStatusSnapshot> applied = const [],  List<VolumeStatusSkip> skipped = const []}): _applied = applied,_skipped = skipped;
  factory _VolumeStatusSyncResult.fromJson(Map<String, dynamic> json) => _$VolumeStatusSyncResultFromJson(json);

 final  List<VolumeStatusSnapshot> _applied;
@override@JsonKey() List<VolumeStatusSnapshot> get applied {
  if (_applied is EqualUnmodifiableListView) return _applied;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_applied);
}

 final  List<VolumeStatusSkip> _skipped;
@override@JsonKey() List<VolumeStatusSkip> get skipped {
  if (_skipped is EqualUnmodifiableListView) return _skipped;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_skipped);
}


/// Create a copy of VolumeStatusSyncResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolumeStatusSyncResultCopyWith<_VolumeStatusSyncResult> get copyWith => __$VolumeStatusSyncResultCopyWithImpl<_VolumeStatusSyncResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolumeStatusSyncResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolumeStatusSyncResult&&const DeepCollectionEquality().equals(other.applied, _applied)&&const DeepCollectionEquality().equals(other.skipped, _skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_applied),const DeepCollectionEquality().hash(_skipped));
}

@override
String toString() {
    return 'VolumeStatusSyncResult(applied: $applied, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$VolumeStatusSyncResultCopyWith<$Res> implements $VolumeStatusSyncResultCopyWith<$Res> {
  factory _$VolumeStatusSyncResultCopyWith(_VolumeStatusSyncResult value, $Res Function(_VolumeStatusSyncResult) _then) = __$VolumeStatusSyncResultCopyWithImpl;
@override @useResult
$Res call({
 List<VolumeStatusSnapshot> applied, List<VolumeStatusSkip> skipped
});




}
/// @nodoc
class __$VolumeStatusSyncResultCopyWithImpl<$Res>
    implements _$VolumeStatusSyncResultCopyWith<$Res> {
  __$VolumeStatusSyncResultCopyWithImpl(this._self, this._then);

  final _VolumeStatusSyncResult _self;
  final $Res Function(_VolumeStatusSyncResult) _then;

/// Create a copy of VolumeStatusSyncResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? applied = null,Object? skipped = null,}) {
  return _then(_VolumeStatusSyncResult(
applied: null == applied ? _self._applied : applied // ignore: cast_nullable_to_non_nullable
as List<VolumeStatusSnapshot>,skipped: null == skipped ? _self._skipped : skipped // ignore: cast_nullable_to_non_nullable
as List<VolumeStatusSkip>,
  ));
}


}

// dart format on
