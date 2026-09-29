// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'volume_manifest.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VolumeManifest {

 int get id;@JsonKey(name: 'book_id') int get bookId;/// ZIP の mtime。取得済みデータの世代であり「更新あり」判定の基準。
@JsonKey(name: 'files_version') int get filesVersion;/// ZIP のバイト数。`Content-Length` の検証と空き容量チェックに使う。
@JsonKey(name: 'archive_bytes') int get archiveBytes;/// `<16進 mtime>-<16進 size>` 形式の検証子。再開時の `If-Range` に使う。
@JsonKey(name: 'archive_etag') String? get archiveEtag;/// ZIP に入っている画像の枚数。展開後の検証に使う。
@JsonKey(name: 'page_count') int get pageCount; List<VolumeManifestPage> get pages;
/// Create a copy of VolumeManifest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolumeManifestCopyWith<VolumeManifest> get copyWith => _$VolumeManifestCopyWithImpl<VolumeManifest>(this as VolumeManifest, _$identity);

  /// Serializes this VolumeManifest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VolumeManifest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolumeManifest&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.bookId, _this.bookId) || other.bookId == _this.bookId)&&(identical(other.filesVersion, _this.filesVersion) || other.filesVersion == _this.filesVersion)&&(identical(other.archiveBytes, _this.archiveBytes) || other.archiveBytes == _this.archiveBytes)&&(identical(other.archiveEtag, _this.archiveEtag) || other.archiveEtag == _this.archiveEtag)&&(identical(other.pageCount, _this.pageCount) || other.pageCount == _this.pageCount)&&const DeepCollectionEquality().equals(other.pages, _this.pages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VolumeManifest;
  return Object.hash(runtimeType,_this.id,_this.bookId,_this.filesVersion,_this.archiveBytes,_this.archiveEtag,_this.pageCount,const DeepCollectionEquality().hash(_this.pages));
}

@override
String toString() {
  final _this = this as VolumeManifest;
  return 'VolumeManifest(id: ${_this.id}, bookId: ${_this.bookId}, filesVersion: ${_this.filesVersion}, archiveBytes: ${_this.archiveBytes}, archiveEtag: ${_this.archiveEtag}, pageCount: ${_this.pageCount}, pages: ${_this.pages})';
}


}

/// @nodoc
abstract mixin class $VolumeManifestCopyWith<$Res>  {
  factory $VolumeManifestCopyWith(VolumeManifest value, $Res Function(VolumeManifest) _then) = _$VolumeManifestCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'book_id') int bookId,@JsonKey(name: 'files_version') int filesVersion,@JsonKey(name: 'archive_bytes') int archiveBytes,@JsonKey(name: 'archive_etag') String? archiveEtag,@JsonKey(name: 'page_count') int pageCount, List<VolumeManifestPage> pages
});




}
/// @nodoc
class _$VolumeManifestCopyWithImpl<$Res>
    implements $VolumeManifestCopyWith<$Res> {
  _$VolumeManifestCopyWithImpl(this._self, this._then);

  final VolumeManifest _self;
  final $Res Function(VolumeManifest) _then;

/// Create a copy of VolumeManifest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookId = null,Object? filesVersion = null,Object? archiveBytes = null,Object? archiveEtag = freezed,Object? pageCount = null,Object? pages = null,}) {
  return _then(VolumeManifest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,filesVersion: null == filesVersion ? _self.filesVersion : filesVersion // ignore: cast_nullable_to_non_nullable
as int,archiveBytes: null == archiveBytes ? _self.archiveBytes : archiveBytes // ignore: cast_nullable_to_non_nullable
as int,archiveEtag: freezed == archiveEtag ? _self.archiveEtag : archiveEtag // ignore: cast_nullable_to_non_nullable
as String?,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,pages: null == pages ? _self.pages : pages // ignore: cast_nullable_to_non_nullable
as List<VolumeManifestPage>,
  ));
}

}


/// Adds pattern-matching-related methods to [VolumeManifest].
extension VolumeManifestPatterns on VolumeManifest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolumeManifest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolumeManifest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolumeManifest value)  $default,){
final _that = this;
switch (_that) {
case _VolumeManifest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolumeManifest value)?  $default,){
final _that = this;
switch (_that) {
case _VolumeManifest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'book_id')  int bookId, @JsonKey(name: 'files_version')  int filesVersion, @JsonKey(name: 'archive_bytes')  int archiveBytes, @JsonKey(name: 'archive_etag')  String? archiveEtag, @JsonKey(name: 'page_count')  int pageCount,  List<VolumeManifestPage> pages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolumeManifest() when $default != null:
return $default(_that.id,_that.bookId,_that.filesVersion,_that.archiveBytes,_that.archiveEtag,_that.pageCount,_that.pages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'book_id')  int bookId, @JsonKey(name: 'files_version')  int filesVersion, @JsonKey(name: 'archive_bytes')  int archiveBytes, @JsonKey(name: 'archive_etag')  String? archiveEtag, @JsonKey(name: 'page_count')  int pageCount,  List<VolumeManifestPage> pages)  $default,) {final _that = this;
switch (_that) {
case _VolumeManifest():
return $default(_that.id,_that.bookId,_that.filesVersion,_that.archiveBytes,_that.archiveEtag,_that.pageCount,_that.pages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'book_id')  int bookId, @JsonKey(name: 'files_version')  int filesVersion, @JsonKey(name: 'archive_bytes')  int archiveBytes, @JsonKey(name: 'archive_etag')  String? archiveEtag, @JsonKey(name: 'page_count')  int pageCount,  List<VolumeManifestPage> pages)?  $default,) {final _that = this;
switch (_that) {
case _VolumeManifest() when $default != null:
return $default(_that.id,_that.bookId,_that.filesVersion,_that.archiveBytes,_that.archiveEtag,_that.pageCount,_that.pages);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolumeManifest implements VolumeManifest {
  const _VolumeManifest({required this.id, @JsonKey(name: 'book_id') this.bookId = 0, @JsonKey(name: 'files_version') this.filesVersion = 0, @JsonKey(name: 'archive_bytes') this.archiveBytes = 0, @JsonKey(name: 'archive_etag') this.archiveEtag, @JsonKey(name: 'page_count') this.pageCount = 0,  List<VolumeManifestPage> pages = const []}): _pages = pages;
  factory _VolumeManifest.fromJson(Map<String, dynamic> json) => _$VolumeManifestFromJson(json);

@override final  int id;
@override@JsonKey(name: 'book_id') final  int bookId;
/// ZIP の mtime。取得済みデータの世代であり「更新あり」判定の基準。
@override@JsonKey(name: 'files_version') final  int filesVersion;
/// ZIP のバイト数。`Content-Length` の検証と空き容量チェックに使う。
@override@JsonKey(name: 'archive_bytes') final  int archiveBytes;
/// `<16進 mtime>-<16進 size>` 形式の検証子。再開時の `If-Range` に使う。
@override@JsonKey(name: 'archive_etag') final  String? archiveEtag;
/// ZIP に入っている画像の枚数。展開後の検証に使う。
@override@JsonKey(name: 'page_count') final  int pageCount;
 final  List<VolumeManifestPage> _pages;
@override@JsonKey() List<VolumeManifestPage> get pages {
  if (_pages is EqualUnmodifiableListView) return _pages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pages);
}


/// Create a copy of VolumeManifest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolumeManifestCopyWith<_VolumeManifest> get copyWith => __$VolumeManifestCopyWithImpl<_VolumeManifest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolumeManifestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolumeManifest&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.filesVersion, filesVersion) || other.filesVersion == filesVersion)&&(identical(other.archiveBytes, archiveBytes) || other.archiveBytes == archiveBytes)&&(identical(other.archiveEtag, archiveEtag) || other.archiveEtag == archiveEtag)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&const DeepCollectionEquality().equals(other.pages, _pages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,bookId,filesVersion,archiveBytes,archiveEtag,pageCount,const DeepCollectionEquality().hash(_pages));
}

@override
String toString() {
    return 'VolumeManifest(id: $id, bookId: $bookId, filesVersion: $filesVersion, archiveBytes: $archiveBytes, archiveEtag: $archiveEtag, pageCount: $pageCount, pages: $pages)';
}


}

/// @nodoc
abstract mixin class _$VolumeManifestCopyWith<$Res> implements $VolumeManifestCopyWith<$Res> {
  factory _$VolumeManifestCopyWith(_VolumeManifest value, $Res Function(_VolumeManifest) _then) = __$VolumeManifestCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'book_id') int bookId,@JsonKey(name: 'files_version') int filesVersion,@JsonKey(name: 'archive_bytes') int archiveBytes,@JsonKey(name: 'archive_etag') String? archiveEtag,@JsonKey(name: 'page_count') int pageCount, List<VolumeManifestPage> pages
});




}
/// @nodoc
class __$VolumeManifestCopyWithImpl<$Res>
    implements _$VolumeManifestCopyWith<$Res> {
  __$VolumeManifestCopyWithImpl(this._self, this._then);

  final _VolumeManifest _self;
  final $Res Function(_VolumeManifest) _then;

/// Create a copy of VolumeManifest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookId = null,Object? filesVersion = null,Object? archiveBytes = null,Object? archiveEtag = freezed,Object? pageCount = null,Object? pages = null,}) {
  return _then(_VolumeManifest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,filesVersion: null == filesVersion ? _self.filesVersion : filesVersion // ignore: cast_nullable_to_non_nullable
as int,archiveBytes: null == archiveBytes ? _self.archiveBytes : archiveBytes // ignore: cast_nullable_to_non_nullable
as int,archiveEtag: freezed == archiveEtag ? _self.archiveEtag : archiveEtag // ignore: cast_nullable_to_non_nullable
as String?,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,pages: null == pages ? _self._pages : pages // ignore: cast_nullable_to_non_nullable
as List<VolumeManifestPage>,
  ));
}


}


/// @nodoc
mixin _$VolumeManifestPage {

 int get index;/// `jpg` / `png` / `avif`（サーバー側で `jpeg` → `jpg` に正規化済み）。
 String get extension; int get bytes;
/// Create a copy of VolumeManifestPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolumeManifestPageCopyWith<VolumeManifestPage> get copyWith => _$VolumeManifestPageCopyWithImpl<VolumeManifestPage>(this as VolumeManifestPage, _$identity);

  /// Serializes this VolumeManifestPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VolumeManifestPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolumeManifestPage&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.extension, _this.extension) || other.extension == _this.extension)&&(identical(other.bytes, _this.bytes) || other.bytes == _this.bytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VolumeManifestPage;
  return Object.hash(runtimeType,_this.index,_this.extension,_this.bytes);
}

@override
String toString() {
  final _this = this as VolumeManifestPage;
  return 'VolumeManifestPage(index: ${_this.index}, extension: ${_this.extension}, bytes: ${_this.bytes})';
}


}

/// @nodoc
abstract mixin class $VolumeManifestPageCopyWith<$Res>  {
  factory $VolumeManifestPageCopyWith(VolumeManifestPage value, $Res Function(VolumeManifestPage) _then) = _$VolumeManifestPageCopyWithImpl;
@useResult
$Res call({
 int index, String extension, int bytes
});




}
/// @nodoc
class _$VolumeManifestPageCopyWithImpl<$Res>
    implements $VolumeManifestPageCopyWith<$Res> {
  _$VolumeManifestPageCopyWithImpl(this._self, this._then);

  final VolumeManifestPage _self;
  final $Res Function(VolumeManifestPage) _then;

/// Create a copy of VolumeManifestPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? extension = null,Object? bytes = null,}) {
  return _then(VolumeManifestPage(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,extension: null == extension ? _self.extension : extension // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VolumeManifestPage].
extension VolumeManifestPagePatterns on VolumeManifestPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolumeManifestPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolumeManifestPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolumeManifestPage value)  $default,){
final _that = this;
switch (_that) {
case _VolumeManifestPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolumeManifestPage value)?  $default,){
final _that = this;
switch (_that) {
case _VolumeManifestPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String extension,  int bytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolumeManifestPage() when $default != null:
return $default(_that.index,_that.extension,_that.bytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String extension,  int bytes)  $default,) {final _that = this;
switch (_that) {
case _VolumeManifestPage():
return $default(_that.index,_that.extension,_that.bytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String extension,  int bytes)?  $default,) {final _that = this;
switch (_that) {
case _VolumeManifestPage() when $default != null:
return $default(_that.index,_that.extension,_that.bytes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolumeManifestPage implements VolumeManifestPage {
  const _VolumeManifestPage({this.index = 0, this.extension = 'jpg', this.bytes = 0});
  factory _VolumeManifestPage.fromJson(Map<String, dynamic> json) => _$VolumeManifestPageFromJson(json);

@override@JsonKey() final  int index;
/// `jpg` / `png` / `avif`（サーバー側で `jpeg` → `jpg` に正規化済み）。
@override@JsonKey() final  String extension;
@override@JsonKey() final  int bytes;

/// Create a copy of VolumeManifestPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolumeManifestPageCopyWith<_VolumeManifestPage> get copyWith => __$VolumeManifestPageCopyWithImpl<_VolumeManifestPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolumeManifestPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolumeManifestPage&&(identical(other.index, index) || other.index == index)&&(identical(other.extension, extension) || other.extension == extension)&&(identical(other.bytes, bytes) || other.bytes == bytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,index,extension,bytes);
}

@override
String toString() {
    return 'VolumeManifestPage(index: $index, extension: $extension, bytes: $bytes)';
}


}

/// @nodoc
abstract mixin class _$VolumeManifestPageCopyWith<$Res> implements $VolumeManifestPageCopyWith<$Res> {
  factory _$VolumeManifestPageCopyWith(_VolumeManifestPage value, $Res Function(_VolumeManifestPage) _then) = __$VolumeManifestPageCopyWithImpl;
@override @useResult
$Res call({
 int index, String extension, int bytes
});




}
/// @nodoc
class __$VolumeManifestPageCopyWithImpl<$Res>
    implements _$VolumeManifestPageCopyWith<$Res> {
  __$VolumeManifestPageCopyWithImpl(this._self, this._then);

  final _VolumeManifestPage _self;
  final $Res Function(_VolumeManifestPage) _then;

/// Create a copy of VolumeManifestPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? extension = null,Object? bytes = null,}) {
  return _then(_VolumeManifestPage(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,extension: null == extension ? _self.extension : extension // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
