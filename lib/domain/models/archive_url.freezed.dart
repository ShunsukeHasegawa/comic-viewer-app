// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'archive_url.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ArchiveUrl {

 String get url;/// 有効期限（最長 24 時間。トークンの期限が先ならそちら）。キューは見ない
/// （期限切れは 403 で分かる）が、調べるときのために受け取っておく。
@JsonKey(name: 'expires_at') DateTime? get expiresAt;/// 発行時の ZIP の mtime（マニフェストの `files_version` と同じもの）。
/// 既定値を持たせない（無いまま 0 で読むと、毎回「サーバー側のデータが
/// 更新されました」になって理由が分からない）。
@JsonKey(name: 'files_version') int get filesVersion;
/// Create a copy of ArchiveUrl
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArchiveUrlCopyWith<ArchiveUrl> get copyWith => _$ArchiveUrlCopyWithImpl<ArchiveUrl>(this as ArchiveUrl, _$identity);

  /// Serializes this ArchiveUrl to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ArchiveUrl;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArchiveUrl&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.filesVersion, _this.filesVersion) || other.filesVersion == _this.filesVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ArchiveUrl;
  return Object.hash(runtimeType,_this.url,_this.expiresAt,_this.filesVersion);
}

@override
String toString() {
  final _this = this as ArchiveUrl;
  return 'ArchiveUrl(url: ${_this.url}, expiresAt: ${_this.expiresAt}, filesVersion: ${_this.filesVersion})';
}


}

/// @nodoc
abstract mixin class $ArchiveUrlCopyWith<$Res>  {
  factory $ArchiveUrlCopyWith(ArchiveUrl value, $Res Function(ArchiveUrl) _then) = _$ArchiveUrlCopyWithImpl;
@useResult
$Res call({
 String url,@JsonKey(name: 'expires_at') DateTime? expiresAt,@JsonKey(name: 'files_version') int filesVersion
});




}
/// @nodoc
class _$ArchiveUrlCopyWithImpl<$Res>
    implements $ArchiveUrlCopyWith<$Res> {
  _$ArchiveUrlCopyWithImpl(this._self, this._then);

  final ArchiveUrl _self;
  final $Res Function(ArchiveUrl) _then;

/// Create a copy of ArchiveUrl
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? expiresAt = freezed,Object? filesVersion = null,}) {
  return _then(ArchiveUrl(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,filesVersion: null == filesVersion ? _self.filesVersion : filesVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ArchiveUrl].
extension ArchiveUrlPatterns on ArchiveUrl {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ArchiveUrl value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ArchiveUrl() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ArchiveUrl value)  $default,){
final _that = this;
switch (_that) {
case _ArchiveUrl():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ArchiveUrl value)?  $default,){
final _that = this;
switch (_that) {
case _ArchiveUrl() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'files_version')  int filesVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ArchiveUrl() when $default != null:
return $default(_that.url,_that.expiresAt,_that.filesVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'files_version')  int filesVersion)  $default,) {final _that = this;
switch (_that) {
case _ArchiveUrl():
return $default(_that.url,_that.expiresAt,_that.filesVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'files_version')  int filesVersion)?  $default,) {final _that = this;
switch (_that) {
case _ArchiveUrl() when $default != null:
return $default(_that.url,_that.expiresAt,_that.filesVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ArchiveUrl implements ArchiveUrl {
  const _ArchiveUrl({required this.url, @JsonKey(name: 'expires_at') this.expiresAt, @JsonKey(name: 'files_version') required this.filesVersion});
  factory _ArchiveUrl.fromJson(Map<String, dynamic> json) => _$ArchiveUrlFromJson(json);

@override final  String url;
/// 有効期限（最長 24 時間。トークンの期限が先ならそちら）。キューは見ない
/// （期限切れは 403 で分かる）が、調べるときのために受け取っておく。
@override@JsonKey(name: 'expires_at') final  DateTime? expiresAt;
/// 発行時の ZIP の mtime（マニフェストの `files_version` と同じもの）。
/// 既定値を持たせない（無いまま 0 で読むと、毎回「サーバー側のデータが
/// 更新されました」になって理由が分からない）。
@override@JsonKey(name: 'files_version') final  int filesVersion;

/// Create a copy of ArchiveUrl
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArchiveUrlCopyWith<_ArchiveUrl> get copyWith => __$ArchiveUrlCopyWithImpl<_ArchiveUrl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArchiveUrlToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArchiveUrl&&(identical(other.url, url) || other.url == url)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.filesVersion, filesVersion) || other.filesVersion == filesVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,url,expiresAt,filesVersion);
}

@override
String toString() {
    return 'ArchiveUrl(url: $url, expiresAt: $expiresAt, filesVersion: $filesVersion)';
}


}

/// @nodoc
abstract mixin class _$ArchiveUrlCopyWith<$Res> implements $ArchiveUrlCopyWith<$Res> {
  factory _$ArchiveUrlCopyWith(_ArchiveUrl value, $Res Function(_ArchiveUrl) _then) = __$ArchiveUrlCopyWithImpl;
@override @useResult
$Res call({
 String url,@JsonKey(name: 'expires_at') DateTime? expiresAt,@JsonKey(name: 'files_version') int filesVersion
});




}
/// @nodoc
class __$ArchiveUrlCopyWithImpl<$Res>
    implements _$ArchiveUrlCopyWith<$Res> {
  __$ArchiveUrlCopyWithImpl(this._self, this._then);

  final _ArchiveUrl _self;
  final $Res Function(_ArchiveUrl) _then;

/// Create a copy of ArchiveUrl
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? expiresAt = freezed,Object? filesVersion = null,}) {
  return _then(_ArchiveUrl(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,filesVersion: null == filesVersion ? _self.filesVersion : filesVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
