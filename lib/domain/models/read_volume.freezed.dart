// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'read_volume.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReadVolume {

 int get id;/// 巻数。
 int get volume;/// 前回読んでいたページ（1 始まり）。
@JsonKey(name: 'current_page') int get currentPage;@JsonKey(name: 'next_volume_id') int? get nextVolumeId;/// 巻末オーバーレイ用。`?m=` 付きの相対 URL。
@JsonKey(name: 'next_volume_thumbnail') String? get nextVolumeThumbnail;/// ページ番号の一覧。ZIP が無い巻は空になる。
@JsonKey(fromJson: intListFromJson) List<int> get files;/// ページ画像の内容バージョン（ZIP の mtime）。
///
/// 画像 URL に `?v=` として必ず付ける。ZIP を差し替えても URL が変わらないため、
/// この値でキャッシュを切り替える。ZIP が無ければ `null`。
@JsonKey(name: 'files_version') int? get filesVersion; Book get book;
/// Create a copy of ReadVolume
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadVolumeCopyWith<ReadVolume> get copyWith => _$ReadVolumeCopyWithImpl<ReadVolume>(this as ReadVolume, _$identity);

  /// Serializes this ReadVolume to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReadVolume;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadVolume&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.volume, _this.volume) || other.volume == _this.volume)&&(identical(other.currentPage, _this.currentPage) || other.currentPage == _this.currentPage)&&(identical(other.nextVolumeId, _this.nextVolumeId) || other.nextVolumeId == _this.nextVolumeId)&&(identical(other.nextVolumeThumbnail, _this.nextVolumeThumbnail) || other.nextVolumeThumbnail == _this.nextVolumeThumbnail)&&const DeepCollectionEquality().equals(other.files, _this.files)&&(identical(other.filesVersion, _this.filesVersion) || other.filesVersion == _this.filesVersion)&&(identical(other.book, _this.book) || other.book == _this.book));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReadVolume;
  return Object.hash(runtimeType,_this.id,_this.volume,_this.currentPage,_this.nextVolumeId,_this.nextVolumeThumbnail,const DeepCollectionEquality().hash(_this.files),_this.filesVersion,_this.book);
}

@override
String toString() {
  final _this = this as ReadVolume;
  return 'ReadVolume(id: ${_this.id}, volume: ${_this.volume}, currentPage: ${_this.currentPage}, nextVolumeId: ${_this.nextVolumeId}, nextVolumeThumbnail: ${_this.nextVolumeThumbnail}, files: ${_this.files}, filesVersion: ${_this.filesVersion}, book: ${_this.book})';
}


}

/// @nodoc
abstract mixin class $ReadVolumeCopyWith<$Res>  {
  factory $ReadVolumeCopyWith(ReadVolume value, $Res Function(ReadVolume) _then) = _$ReadVolumeCopyWithImpl;
@useResult
$Res call({
 int id, int volume,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'next_volume_id') int? nextVolumeId,@JsonKey(name: 'next_volume_thumbnail') String? nextVolumeThumbnail,@JsonKey(fromJson: intListFromJson) List<int> files,@JsonKey(name: 'files_version') int? filesVersion, Book book
});


$BookCopyWith<$Res> get book;

}
/// @nodoc
class _$ReadVolumeCopyWithImpl<$Res>
    implements $ReadVolumeCopyWith<$Res> {
  _$ReadVolumeCopyWithImpl(this._self, this._then);

  final ReadVolume _self;
  final $Res Function(ReadVolume) _then;

/// Create a copy of ReadVolume
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? volume = null,Object? currentPage = null,Object? nextVolumeId = freezed,Object? nextVolumeThumbnail = freezed,Object? files = null,Object? filesVersion = freezed,Object? book = null,}) {
  return _then(ReadVolume(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,nextVolumeId: freezed == nextVolumeId ? _self.nextVolumeId : nextVolumeId // ignore: cast_nullable_to_non_nullable
as int?,nextVolumeThumbnail: freezed == nextVolumeThumbnail ? _self.nextVolumeThumbnail : nextVolumeThumbnail // ignore: cast_nullable_to_non_nullable
as String?,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<int>,filesVersion: freezed == filesVersion ? _self.filesVersion : filesVersion // ignore: cast_nullable_to_non_nullable
as int?,book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as Book,
  ));
}
/// Create a copy of ReadVolume
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookCopyWith<$Res> get book {
  
  return $BookCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReadVolume].
extension ReadVolumePatterns on ReadVolume {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadVolume value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadVolume() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadVolume value)  $default,){
final _that = this;
switch (_that) {
case _ReadVolume():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadVolume value)?  $default,){
final _that = this;
switch (_that) {
case _ReadVolume() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int volume, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'next_volume_id')  int? nextVolumeId, @JsonKey(name: 'next_volume_thumbnail')  String? nextVolumeThumbnail, @JsonKey(fromJson: intListFromJson)  List<int> files, @JsonKey(name: 'files_version')  int? filesVersion,  Book book)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadVolume() when $default != null:
return $default(_that.id,_that.volume,_that.currentPage,_that.nextVolumeId,_that.nextVolumeThumbnail,_that.files,_that.filesVersion,_that.book);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int volume, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'next_volume_id')  int? nextVolumeId, @JsonKey(name: 'next_volume_thumbnail')  String? nextVolumeThumbnail, @JsonKey(fromJson: intListFromJson)  List<int> files, @JsonKey(name: 'files_version')  int? filesVersion,  Book book)  $default,) {final _that = this;
switch (_that) {
case _ReadVolume():
return $default(_that.id,_that.volume,_that.currentPage,_that.nextVolumeId,_that.nextVolumeThumbnail,_that.files,_that.filesVersion,_that.book);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int volume, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'next_volume_id')  int? nextVolumeId, @JsonKey(name: 'next_volume_thumbnail')  String? nextVolumeThumbnail, @JsonKey(fromJson: intListFromJson)  List<int> files, @JsonKey(name: 'files_version')  int? filesVersion,  Book book)?  $default,) {final _that = this;
switch (_that) {
case _ReadVolume() when $default != null:
return $default(_that.id,_that.volume,_that.currentPage,_that.nextVolumeId,_that.nextVolumeThumbnail,_that.files,_that.filesVersion,_that.book);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReadVolume implements ReadVolume {
  const _ReadVolume({required this.id, this.volume = 0, @JsonKey(name: 'current_page') this.currentPage = 1, @JsonKey(name: 'next_volume_id') this.nextVolumeId, @JsonKey(name: 'next_volume_thumbnail') this.nextVolumeThumbnail, @JsonKey(fromJson: intListFromJson)  List<int> files = const [], @JsonKey(name: 'files_version') this.filesVersion, required this.book}): _files = files;
  factory _ReadVolume.fromJson(Map<String, dynamic> json) => _$ReadVolumeFromJson(json);

@override final  int id;
/// 巻数。
@override@JsonKey() final  int volume;
/// 前回読んでいたページ（1 始まり）。
@override@JsonKey(name: 'current_page') final  int currentPage;
@override@JsonKey(name: 'next_volume_id') final  int? nextVolumeId;
/// 巻末オーバーレイ用。`?m=` 付きの相対 URL。
@override@JsonKey(name: 'next_volume_thumbnail') final  String? nextVolumeThumbnail;
/// ページ番号の一覧。ZIP が無い巻は空になる。
 final  List<int> _files;
/// ページ番号の一覧。ZIP が無い巻は空になる。
@override@JsonKey(fromJson: intListFromJson) List<int> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}

/// ページ画像の内容バージョン（ZIP の mtime）。
///
/// 画像 URL に `?v=` として必ず付ける。ZIP を差し替えても URL が変わらないため、
/// この値でキャッシュを切り替える。ZIP が無ければ `null`。
@override@JsonKey(name: 'files_version') final  int? filesVersion;
@override final  Book book;

/// Create a copy of ReadVolume
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadVolumeCopyWith<_ReadVolume> get copyWith => __$ReadVolumeCopyWithImpl<_ReadVolume>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReadVolumeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadVolume&&(identical(other.id, id) || other.id == id)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.nextVolumeId, nextVolumeId) || other.nextVolumeId == nextVolumeId)&&(identical(other.nextVolumeThumbnail, nextVolumeThumbnail) || other.nextVolumeThumbnail == nextVolumeThumbnail)&&const DeepCollectionEquality().equals(other.files, _files)&&(identical(other.filesVersion, filesVersion) || other.filesVersion == filesVersion)&&(identical(other.book, book) || other.book == book));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,volume,currentPage,nextVolumeId,nextVolumeThumbnail,const DeepCollectionEquality().hash(_files),filesVersion,book);
}

@override
String toString() {
    return 'ReadVolume(id: $id, volume: $volume, currentPage: $currentPage, nextVolumeId: $nextVolumeId, nextVolumeThumbnail: $nextVolumeThumbnail, files: $files, filesVersion: $filesVersion, book: $book)';
}


}

/// @nodoc
abstract mixin class _$ReadVolumeCopyWith<$Res> implements $ReadVolumeCopyWith<$Res> {
  factory _$ReadVolumeCopyWith(_ReadVolume value, $Res Function(_ReadVolume) _then) = __$ReadVolumeCopyWithImpl;
@override @useResult
$Res call({
 int id, int volume,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'next_volume_id') int? nextVolumeId,@JsonKey(name: 'next_volume_thumbnail') String? nextVolumeThumbnail,@JsonKey(fromJson: intListFromJson) List<int> files,@JsonKey(name: 'files_version') int? filesVersion, Book book
});


@override $BookCopyWith<$Res> get book;

}
/// @nodoc
class __$ReadVolumeCopyWithImpl<$Res>
    implements _$ReadVolumeCopyWith<$Res> {
  __$ReadVolumeCopyWithImpl(this._self, this._then);

  final _ReadVolume _self;
  final $Res Function(_ReadVolume) _then;

/// Create a copy of ReadVolume
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? volume = null,Object? currentPage = null,Object? nextVolumeId = freezed,Object? nextVolumeThumbnail = freezed,Object? files = null,Object? filesVersion = freezed,Object? book = null,}) {
  return _then(_ReadVolume(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,nextVolumeId: freezed == nextVolumeId ? _self.nextVolumeId : nextVolumeId // ignore: cast_nullable_to_non_nullable
as int?,nextVolumeThumbnail: freezed == nextVolumeThumbnail ? _self.nextVolumeThumbnail : nextVolumeThumbnail // ignore: cast_nullable_to_non_nullable
as String?,files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<int>,filesVersion: freezed == filesVersion ? _self.filesVersion : filesVersion // ignore: cast_nullable_to_non_nullable
as int?,book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as Book,
  ));
}

/// Create a copy of ReadVolume
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookCopyWith<$Res> get book {
  
  return $BookCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}

// dart format on
