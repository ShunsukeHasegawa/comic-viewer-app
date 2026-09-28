// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookDetail {

 int get id; String get title;/// あらすじ。
 String? get overview;@JsonKey(name: 'is_complete', fromJson: boolFromJson) bool get isComplete;@JsonKey(name: 'is_favorite', fromJson: boolFromJson) bool get isFavorite;@JsonKey(fromJson: stringListFromJson) List<String> get authors; String? get publisher; String? get label;@JsonKey(fromJson: stringListFromJson) List<String> get tags; List<BookCategory> get categories; List<BookVolume> get volumes;/// 全巻ダウンロード時の合計バイト数（ZIP が無い巻は 0 として合算）。
@JsonKey(name: 'total_archive_bytes') int get totalArchiveBytes;@JsonKey(name: 'reading_progress') ReadingProgress? get readingProgress;
/// Create a copy of BookDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookDetailCopyWith<BookDetail> get copyWith => _$BookDetailCopyWithImpl<BookDetail>(this as BookDetail, _$identity);

  /// Serializes this BookDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookDetail&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.overview, _this.overview) || other.overview == _this.overview)&&(identical(other.isComplete, _this.isComplete) || other.isComplete == _this.isComplete)&&(identical(other.isFavorite, _this.isFavorite) || other.isFavorite == _this.isFavorite)&&const DeepCollectionEquality().equals(other.authors, _this.authors)&&(identical(other.publisher, _this.publisher) || other.publisher == _this.publisher)&&(identical(other.label, _this.label) || other.label == _this.label)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.categories, _this.categories)&&const DeepCollectionEquality().equals(other.volumes, _this.volumes)&&(identical(other.totalArchiveBytes, _this.totalArchiveBytes) || other.totalArchiveBytes == _this.totalArchiveBytes)&&(identical(other.readingProgress, _this.readingProgress) || other.readingProgress == _this.readingProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookDetail;
  return Object.hash(runtimeType,_this.id,_this.title,_this.overview,_this.isComplete,_this.isFavorite,const DeepCollectionEquality().hash(_this.authors),_this.publisher,_this.label,const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.categories),const DeepCollectionEquality().hash(_this.volumes),_this.totalArchiveBytes,_this.readingProgress);
}

@override
String toString() {
  final _this = this as BookDetail;
  return 'BookDetail(id: ${_this.id}, title: ${_this.title}, overview: ${_this.overview}, isComplete: ${_this.isComplete}, isFavorite: ${_this.isFavorite}, authors: ${_this.authors}, publisher: ${_this.publisher}, label: ${_this.label}, tags: ${_this.tags}, categories: ${_this.categories}, volumes: ${_this.volumes}, totalArchiveBytes: ${_this.totalArchiveBytes}, readingProgress: ${_this.readingProgress})';
}


}

/// @nodoc
abstract mixin class $BookDetailCopyWith<$Res>  {
  factory $BookDetailCopyWith(BookDetail value, $Res Function(BookDetail) _then) = _$BookDetailCopyWithImpl;
@useResult
$Res call({
 int id, String title, String? overview,@JsonKey(name: 'is_complete', fromJson: boolFromJson) bool isComplete,@JsonKey(name: 'is_favorite', fromJson: boolFromJson) bool isFavorite,@JsonKey(fromJson: stringListFromJson) List<String> authors, String? publisher, String? label,@JsonKey(fromJson: stringListFromJson) List<String> tags, List<BookCategory> categories, List<BookVolume> volumes,@JsonKey(name: 'total_archive_bytes') int totalArchiveBytes,@JsonKey(name: 'reading_progress') ReadingProgress? readingProgress
});


$ReadingProgressCopyWith<$Res>? get readingProgress;

}
/// @nodoc
class _$BookDetailCopyWithImpl<$Res>
    implements $BookDetailCopyWith<$Res> {
  _$BookDetailCopyWithImpl(this._self, this._then);

  final BookDetail _self;
  final $Res Function(BookDetail) _then;

/// Create a copy of BookDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? overview = freezed,Object? isComplete = null,Object? isFavorite = null,Object? authors = null,Object? publisher = freezed,Object? label = freezed,Object? tags = null,Object? categories = null,Object? volumes = null,Object? totalArchiveBytes = null,Object? readingProgress = freezed,}) {
  return _then(BookDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as String?,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,authors: null == authors ? _self.authors : authors // ignore: cast_nullable_to_non_nullable
as List<String>,publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<BookCategory>,volumes: null == volumes ? _self.volumes : volumes // ignore: cast_nullable_to_non_nullable
as List<BookVolume>,totalArchiveBytes: null == totalArchiveBytes ? _self.totalArchiveBytes : totalArchiveBytes // ignore: cast_nullable_to_non_nullable
as int,readingProgress: freezed == readingProgress ? _self.readingProgress : readingProgress // ignore: cast_nullable_to_non_nullable
as ReadingProgress?,
  ));
}
/// Create a copy of BookDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadingProgressCopyWith<$Res>? get readingProgress {
    if (_self.readingProgress == null) {
    return null;
  }

  return $ReadingProgressCopyWith<$Res>(_self.readingProgress!, (value) {
    return _then(_self.copyWith(readingProgress: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookDetail].
extension BookDetailPatterns on BookDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookDetail value)  $default,){
final _that = this;
switch (_that) {
case _BookDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookDetail value)?  $default,){
final _that = this;
switch (_that) {
case _BookDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String? overview, @JsonKey(name: 'is_complete', fromJson: boolFromJson)  bool isComplete, @JsonKey(name: 'is_favorite', fromJson: boolFromJson)  bool isFavorite, @JsonKey(fromJson: stringListFromJson)  List<String> authors,  String? publisher,  String? label, @JsonKey(fromJson: stringListFromJson)  List<String> tags,  List<BookCategory> categories,  List<BookVolume> volumes, @JsonKey(name: 'total_archive_bytes')  int totalArchiveBytes, @JsonKey(name: 'reading_progress')  ReadingProgress? readingProgress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookDetail() when $default != null:
return $default(_that.id,_that.title,_that.overview,_that.isComplete,_that.isFavorite,_that.authors,_that.publisher,_that.label,_that.tags,_that.categories,_that.volumes,_that.totalArchiveBytes,_that.readingProgress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String? overview, @JsonKey(name: 'is_complete', fromJson: boolFromJson)  bool isComplete, @JsonKey(name: 'is_favorite', fromJson: boolFromJson)  bool isFavorite, @JsonKey(fromJson: stringListFromJson)  List<String> authors,  String? publisher,  String? label, @JsonKey(fromJson: stringListFromJson)  List<String> tags,  List<BookCategory> categories,  List<BookVolume> volumes, @JsonKey(name: 'total_archive_bytes')  int totalArchiveBytes, @JsonKey(name: 'reading_progress')  ReadingProgress? readingProgress)  $default,) {final _that = this;
switch (_that) {
case _BookDetail():
return $default(_that.id,_that.title,_that.overview,_that.isComplete,_that.isFavorite,_that.authors,_that.publisher,_that.label,_that.tags,_that.categories,_that.volumes,_that.totalArchiveBytes,_that.readingProgress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String? overview, @JsonKey(name: 'is_complete', fromJson: boolFromJson)  bool isComplete, @JsonKey(name: 'is_favorite', fromJson: boolFromJson)  bool isFavorite, @JsonKey(fromJson: stringListFromJson)  List<String> authors,  String? publisher,  String? label, @JsonKey(fromJson: stringListFromJson)  List<String> tags,  List<BookCategory> categories,  List<BookVolume> volumes, @JsonKey(name: 'total_archive_bytes')  int totalArchiveBytes, @JsonKey(name: 'reading_progress')  ReadingProgress? readingProgress)?  $default,) {final _that = this;
switch (_that) {
case _BookDetail() when $default != null:
return $default(_that.id,_that.title,_that.overview,_that.isComplete,_that.isFavorite,_that.authors,_that.publisher,_that.label,_that.tags,_that.categories,_that.volumes,_that.totalArchiveBytes,_that.readingProgress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookDetail implements BookDetail {
  const _BookDetail({required this.id, this.title = '', this.overview, @JsonKey(name: 'is_complete', fromJson: boolFromJson) this.isComplete = false, @JsonKey(name: 'is_favorite', fromJson: boolFromJson) this.isFavorite = false, @JsonKey(fromJson: stringListFromJson)  List<String> authors = const [], this.publisher, this.label, @JsonKey(fromJson: stringListFromJson)  List<String> tags = const [],  List<BookCategory> categories = const [],  List<BookVolume> volumes = const [], @JsonKey(name: 'total_archive_bytes') this.totalArchiveBytes = 0, @JsonKey(name: 'reading_progress') this.readingProgress}): _authors = authors,_tags = tags,_categories = categories,_volumes = volumes;
  factory _BookDetail.fromJson(Map<String, dynamic> json) => _$BookDetailFromJson(json);

@override final  int id;
@override@JsonKey() final  String title;
/// あらすじ。
@override final  String? overview;
@override@JsonKey(name: 'is_complete', fromJson: boolFromJson) final  bool isComplete;
@override@JsonKey(name: 'is_favorite', fromJson: boolFromJson) final  bool isFavorite;
 final  List<String> _authors;
@override@JsonKey(fromJson: stringListFromJson) List<String> get authors {
  if (_authors is EqualUnmodifiableListView) return _authors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_authors);
}

@override final  String? publisher;
@override final  String? label;
 final  List<String> _tags;
@override@JsonKey(fromJson: stringListFromJson) List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<BookCategory> _categories;
@override@JsonKey() List<BookCategory> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  List<BookVolume> _volumes;
@override@JsonKey() List<BookVolume> get volumes {
  if (_volumes is EqualUnmodifiableListView) return _volumes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_volumes);
}

/// 全巻ダウンロード時の合計バイト数（ZIP が無い巻は 0 として合算）。
@override@JsonKey(name: 'total_archive_bytes') final  int totalArchiveBytes;
@override@JsonKey(name: 'reading_progress') final  ReadingProgress? readingProgress;

/// Create a copy of BookDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookDetailCopyWith<_BookDetail> get copyWith => __$BookDetailCopyWithImpl<_BookDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookDetailToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.overview, overview) || other.overview == overview)&&(identical(other.isComplete, isComplete) || other.isComplete == isComplete)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&const DeepCollectionEquality().equals(other.authors, _authors)&&(identical(other.publisher, publisher) || other.publisher == publisher)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.categories, _categories)&&const DeepCollectionEquality().equals(other.volumes, _volumes)&&(identical(other.totalArchiveBytes, totalArchiveBytes) || other.totalArchiveBytes == totalArchiveBytes)&&(identical(other.readingProgress, readingProgress) || other.readingProgress == readingProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,overview,isComplete,isFavorite,const DeepCollectionEquality().hash(_authors),publisher,label,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_volumes),totalArchiveBytes,readingProgress);
}

@override
String toString() {
    return 'BookDetail(id: $id, title: $title, overview: $overview, isComplete: $isComplete, isFavorite: $isFavorite, authors: $authors, publisher: $publisher, label: $label, tags: $tags, categories: $categories, volumes: $volumes, totalArchiveBytes: $totalArchiveBytes, readingProgress: $readingProgress)';
}


}

/// @nodoc
abstract mixin class _$BookDetailCopyWith<$Res> implements $BookDetailCopyWith<$Res> {
  factory _$BookDetailCopyWith(_BookDetail value, $Res Function(_BookDetail) _then) = __$BookDetailCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String? overview,@JsonKey(name: 'is_complete', fromJson: boolFromJson) bool isComplete,@JsonKey(name: 'is_favorite', fromJson: boolFromJson) bool isFavorite,@JsonKey(fromJson: stringListFromJson) List<String> authors, String? publisher, String? label,@JsonKey(fromJson: stringListFromJson) List<String> tags, List<BookCategory> categories, List<BookVolume> volumes,@JsonKey(name: 'total_archive_bytes') int totalArchiveBytes,@JsonKey(name: 'reading_progress') ReadingProgress? readingProgress
});


@override $ReadingProgressCopyWith<$Res>? get readingProgress;

}
/// @nodoc
class __$BookDetailCopyWithImpl<$Res>
    implements _$BookDetailCopyWith<$Res> {
  __$BookDetailCopyWithImpl(this._self, this._then);

  final _BookDetail _self;
  final $Res Function(_BookDetail) _then;

/// Create a copy of BookDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? overview = freezed,Object? isComplete = null,Object? isFavorite = null,Object? authors = null,Object? publisher = freezed,Object? label = freezed,Object? tags = null,Object? categories = null,Object? volumes = null,Object? totalArchiveBytes = null,Object? readingProgress = freezed,}) {
  return _then(_BookDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as String?,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,authors: null == authors ? _self._authors : authors // ignore: cast_nullable_to_non_nullable
as List<String>,publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<BookCategory>,volumes: null == volumes ? _self._volumes : volumes // ignore: cast_nullable_to_non_nullable
as List<BookVolume>,totalArchiveBytes: null == totalArchiveBytes ? _self.totalArchiveBytes : totalArchiveBytes // ignore: cast_nullable_to_non_nullable
as int,readingProgress: freezed == readingProgress ? _self.readingProgress : readingProgress // ignore: cast_nullable_to_non_nullable
as ReadingProgress?,
  ));
}

/// Create a copy of BookDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadingProgressCopyWith<$Res>? get readingProgress {
    if (_self.readingProgress == null) {
    return null;
  }

  return $ReadingProgressCopyWith<$Res>(_self.readingProgress!, (value) {
    return _then(_self.copyWith(readingProgress: value));
  });
}
}


/// @nodoc
mixin _$BookCategory {

 int get id; String get name;
/// Create a copy of BookCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookCategoryCopyWith<BookCategory> get copyWith => _$BookCategoryCopyWithImpl<BookCategory>(this as BookCategory, _$identity);

  /// Serializes this BookCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookCategory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookCategory&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookCategory;
  return Object.hash(runtimeType,_this.id,_this.name);
}

@override
String toString() {
  final _this = this as BookCategory;
  return 'BookCategory(id: ${_this.id}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $BookCategoryCopyWith<$Res>  {
  factory $BookCategoryCopyWith(BookCategory value, $Res Function(BookCategory) _then) = _$BookCategoryCopyWithImpl;
@useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class _$BookCategoryCopyWithImpl<$Res>
    implements $BookCategoryCopyWith<$Res> {
  _$BookCategoryCopyWithImpl(this._self, this._then);

  final BookCategory _self;
  final $Res Function(BookCategory) _then;

/// Create a copy of BookCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(BookCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BookCategory].
extension BookCategoryPatterns on BookCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookCategory value)  $default,){
final _that = this;
switch (_that) {
case _BookCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookCategory value)?  $default,){
final _that = this;
switch (_that) {
case _BookCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookCategory() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name)  $default,) {final _that = this;
switch (_that) {
case _BookCategory():
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _BookCategory() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookCategory implements BookCategory {
  const _BookCategory({required this.id, this.name = ''});
  factory _BookCategory.fromJson(Map<String, dynamic> json) => _$BookCategoryFromJson(json);

@override final  int id;
@override@JsonKey() final  String name;

/// Create a copy of BookCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookCategoryCopyWith<_BookCategory> get copyWith => __$BookCategoryCopyWithImpl<_BookCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name);
}

@override
String toString() {
    return 'BookCategory(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$BookCategoryCopyWith<$Res> implements $BookCategoryCopyWith<$Res> {
  factory _$BookCategoryCopyWith(_BookCategory value, $Res Function(_BookCategory) _then) = __$BookCategoryCopyWithImpl;
@override @useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class __$BookCategoryCopyWithImpl<$Res>
    implements _$BookCategoryCopyWith<$Res> {
  __$BookCategoryCopyWithImpl(this._self, this._then);

  final _BookCategory _self;
  final $Res Function(_BookCategory) _then;

/// Create a copy of BookCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_BookCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$BookVolume {

 int get id; int get volume;/// `?m=` 付きの相対 URL。`null` はサムネイル無し。
 String? get thumbnail;/// 既読情報から分かる総ページ数（未読の巻は `null`）。
@JsonKey(name: 'total_pages') int? get totalPages;/// ZIP のバイト数。ZIP が無ければ `null` = ダウンロードできない。
@JsonKey(name: 'archive_bytes') int? get archiveBytes;/// ページ画像の内容バージョン（ZIP の mtime）。
/// ダウンロード済みデータとの照合（「更新あり」判定）に使う。
@JsonKey(name: 'files_version') int? get filesVersion;@JsonKey(name: 'user_volume_status') VolumeUserStatus? get userStatus;
/// Create a copy of BookVolume
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookVolumeCopyWith<BookVolume> get copyWith => _$BookVolumeCopyWithImpl<BookVolume>(this as BookVolume, _$identity);

  /// Serializes this BookVolume to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookVolume;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookVolume&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.volume, _this.volume) || other.volume == _this.volume)&&(identical(other.thumbnail, _this.thumbnail) || other.thumbnail == _this.thumbnail)&&(identical(other.totalPages, _this.totalPages) || other.totalPages == _this.totalPages)&&(identical(other.archiveBytes, _this.archiveBytes) || other.archiveBytes == _this.archiveBytes)&&(identical(other.filesVersion, _this.filesVersion) || other.filesVersion == _this.filesVersion)&&(identical(other.userStatus, _this.userStatus) || other.userStatus == _this.userStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookVolume;
  return Object.hash(runtimeType,_this.id,_this.volume,_this.thumbnail,_this.totalPages,_this.archiveBytes,_this.filesVersion,_this.userStatus);
}

@override
String toString() {
  final _this = this as BookVolume;
  return 'BookVolume(id: ${_this.id}, volume: ${_this.volume}, thumbnail: ${_this.thumbnail}, totalPages: ${_this.totalPages}, archiveBytes: ${_this.archiveBytes}, filesVersion: ${_this.filesVersion}, userStatus: ${_this.userStatus})';
}


}

/// @nodoc
abstract mixin class $BookVolumeCopyWith<$Res>  {
  factory $BookVolumeCopyWith(BookVolume value, $Res Function(BookVolume) _then) = _$BookVolumeCopyWithImpl;
@useResult
$Res call({
 int id, int volume, String? thumbnail,@JsonKey(name: 'total_pages') int? totalPages,@JsonKey(name: 'archive_bytes') int? archiveBytes,@JsonKey(name: 'files_version') int? filesVersion,@JsonKey(name: 'user_volume_status') VolumeUserStatus? userStatus
});


$VolumeUserStatusCopyWith<$Res>? get userStatus;

}
/// @nodoc
class _$BookVolumeCopyWithImpl<$Res>
    implements $BookVolumeCopyWith<$Res> {
  _$BookVolumeCopyWithImpl(this._self, this._then);

  final BookVolume _self;
  final $Res Function(BookVolume) _then;

/// Create a copy of BookVolume
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? volume = null,Object? thumbnail = freezed,Object? totalPages = freezed,Object? archiveBytes = freezed,Object? filesVersion = freezed,Object? userStatus = freezed,}) {
  return _then(BookVolume(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,totalPages: freezed == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int?,archiveBytes: freezed == archiveBytes ? _self.archiveBytes : archiveBytes // ignore: cast_nullable_to_non_nullable
as int?,filesVersion: freezed == filesVersion ? _self.filesVersion : filesVersion // ignore: cast_nullable_to_non_nullable
as int?,userStatus: freezed == userStatus ? _self.userStatus : userStatus // ignore: cast_nullable_to_non_nullable
as VolumeUserStatus?,
  ));
}
/// Create a copy of BookVolume
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VolumeUserStatusCopyWith<$Res>? get userStatus {
    if (_self.userStatus == null) {
    return null;
  }

  return $VolumeUserStatusCopyWith<$Res>(_self.userStatus!, (value) {
    return _then(_self.copyWith(userStatus: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookVolume].
extension BookVolumePatterns on BookVolume {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookVolume value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookVolume() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookVolume value)  $default,){
final _that = this;
switch (_that) {
case _BookVolume():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookVolume value)?  $default,){
final _that = this;
switch (_that) {
case _BookVolume() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int volume,  String? thumbnail, @JsonKey(name: 'total_pages')  int? totalPages, @JsonKey(name: 'archive_bytes')  int? archiveBytes, @JsonKey(name: 'files_version')  int? filesVersion, @JsonKey(name: 'user_volume_status')  VolumeUserStatus? userStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookVolume() when $default != null:
return $default(_that.id,_that.volume,_that.thumbnail,_that.totalPages,_that.archiveBytes,_that.filesVersion,_that.userStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int volume,  String? thumbnail, @JsonKey(name: 'total_pages')  int? totalPages, @JsonKey(name: 'archive_bytes')  int? archiveBytes, @JsonKey(name: 'files_version')  int? filesVersion, @JsonKey(name: 'user_volume_status')  VolumeUserStatus? userStatus)  $default,) {final _that = this;
switch (_that) {
case _BookVolume():
return $default(_that.id,_that.volume,_that.thumbnail,_that.totalPages,_that.archiveBytes,_that.filesVersion,_that.userStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int volume,  String? thumbnail, @JsonKey(name: 'total_pages')  int? totalPages, @JsonKey(name: 'archive_bytes')  int? archiveBytes, @JsonKey(name: 'files_version')  int? filesVersion, @JsonKey(name: 'user_volume_status')  VolumeUserStatus? userStatus)?  $default,) {final _that = this;
switch (_that) {
case _BookVolume() when $default != null:
return $default(_that.id,_that.volume,_that.thumbnail,_that.totalPages,_that.archiveBytes,_that.filesVersion,_that.userStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookVolume implements BookVolume {
  const _BookVolume({required this.id, this.volume = 0, this.thumbnail, @JsonKey(name: 'total_pages') this.totalPages, @JsonKey(name: 'archive_bytes') this.archiveBytes, @JsonKey(name: 'files_version') this.filesVersion, @JsonKey(name: 'user_volume_status') this.userStatus});
  factory _BookVolume.fromJson(Map<String, dynamic> json) => _$BookVolumeFromJson(json);

@override final  int id;
@override@JsonKey() final  int volume;
/// `?m=` 付きの相対 URL。`null` はサムネイル無し。
@override final  String? thumbnail;
/// 既読情報から分かる総ページ数（未読の巻は `null`）。
@override@JsonKey(name: 'total_pages') final  int? totalPages;
/// ZIP のバイト数。ZIP が無ければ `null` = ダウンロードできない。
@override@JsonKey(name: 'archive_bytes') final  int? archiveBytes;
/// ページ画像の内容バージョン（ZIP の mtime）。
/// ダウンロード済みデータとの照合（「更新あり」判定）に使う。
@override@JsonKey(name: 'files_version') final  int? filesVersion;
@override@JsonKey(name: 'user_volume_status') final  VolumeUserStatus? userStatus;

/// Create a copy of BookVolume
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookVolumeCopyWith<_BookVolume> get copyWith => __$BookVolumeCopyWithImpl<_BookVolume>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookVolumeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookVolume&&(identical(other.id, id) || other.id == id)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.thumbnail, thumbnail) || other.thumbnail == thumbnail)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.archiveBytes, archiveBytes) || other.archiveBytes == archiveBytes)&&(identical(other.filesVersion, filesVersion) || other.filesVersion == filesVersion)&&(identical(other.userStatus, userStatus) || other.userStatus == userStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,volume,thumbnail,totalPages,archiveBytes,filesVersion,userStatus);
}

@override
String toString() {
    return 'BookVolume(id: $id, volume: $volume, thumbnail: $thumbnail, totalPages: $totalPages, archiveBytes: $archiveBytes, filesVersion: $filesVersion, userStatus: $userStatus)';
}


}

/// @nodoc
abstract mixin class _$BookVolumeCopyWith<$Res> implements $BookVolumeCopyWith<$Res> {
  factory _$BookVolumeCopyWith(_BookVolume value, $Res Function(_BookVolume) _then) = __$BookVolumeCopyWithImpl;
@override @useResult
$Res call({
 int id, int volume, String? thumbnail,@JsonKey(name: 'total_pages') int? totalPages,@JsonKey(name: 'archive_bytes') int? archiveBytes,@JsonKey(name: 'files_version') int? filesVersion,@JsonKey(name: 'user_volume_status') VolumeUserStatus? userStatus
});


@override $VolumeUserStatusCopyWith<$Res>? get userStatus;

}
/// @nodoc
class __$BookVolumeCopyWithImpl<$Res>
    implements _$BookVolumeCopyWith<$Res> {
  __$BookVolumeCopyWithImpl(this._self, this._then);

  final _BookVolume _self;
  final $Res Function(_BookVolume) _then;

/// Create a copy of BookVolume
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? volume = null,Object? thumbnail = freezed,Object? totalPages = freezed,Object? archiveBytes = freezed,Object? filesVersion = freezed,Object? userStatus = freezed,}) {
  return _then(_BookVolume(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,totalPages: freezed == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int?,archiveBytes: freezed == archiveBytes ? _self.archiveBytes : archiveBytes // ignore: cast_nullable_to_non_nullable
as int?,filesVersion: freezed == filesVersion ? _self.filesVersion : filesVersion // ignore: cast_nullable_to_non_nullable
as int?,userStatus: freezed == userStatus ? _self.userStatus : userStatus // ignore: cast_nullable_to_non_nullable
as VolumeUserStatus?,
  ));
}

/// Create a copy of BookVolume
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VolumeUserStatusCopyWith<$Res>? get userStatus {
    if (_self.userStatus == null) {
    return null;
  }

  return $VolumeUserStatusCopyWith<$Res>(_self.userStatus!, (value) {
    return _then(_self.copyWith(userStatus: value));
  });
}
}


/// @nodoc
mixin _$VolumeUserStatus {

@JsonKey(name: 'current_page') int get currentPage;@JsonKey(name: 'max_page') int get maxPage;@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool get isFinished;
/// Create a copy of VolumeUserStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolumeUserStatusCopyWith<VolumeUserStatus> get copyWith => _$VolumeUserStatusCopyWithImpl<VolumeUserStatus>(this as VolumeUserStatus, _$identity);

  /// Serializes this VolumeUserStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VolumeUserStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolumeUserStatus&&(identical(other.currentPage, _this.currentPage) || other.currentPage == _this.currentPage)&&(identical(other.maxPage, _this.maxPage) || other.maxPage == _this.maxPage)&&(identical(other.isFinished, _this.isFinished) || other.isFinished == _this.isFinished));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VolumeUserStatus;
  return Object.hash(runtimeType,_this.currentPage,_this.maxPage,_this.isFinished);
}

@override
String toString() {
  final _this = this as VolumeUserStatus;
  return 'VolumeUserStatus(currentPage: ${_this.currentPage}, maxPage: ${_this.maxPage}, isFinished: ${_this.isFinished})';
}


}

/// @nodoc
abstract mixin class $VolumeUserStatusCopyWith<$Res>  {
  factory $VolumeUserStatusCopyWith(VolumeUserStatus value, $Res Function(VolumeUserStatus) _then) = _$VolumeUserStatusCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool isFinished
});




}
/// @nodoc
class _$VolumeUserStatusCopyWithImpl<$Res>
    implements $VolumeUserStatusCopyWith<$Res> {
  _$VolumeUserStatusCopyWithImpl(this._self, this._then);

  final VolumeUserStatus _self;
  final $Res Function(VolumeUserStatus) _then;

/// Create a copy of VolumeUserStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentPage = null,Object? maxPage = null,Object? isFinished = null,}) {
  return _then(VolumeUserStatus(
currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,isFinished: null == isFinished ? _self.isFinished : isFinished // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VolumeUserStatus].
extension VolumeUserStatusPatterns on VolumeUserStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolumeUserStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolumeUserStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolumeUserStatus value)  $default,){
final _that = this;
switch (_that) {
case _VolumeUserStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolumeUserStatus value)?  $default,){
final _that = this;
switch (_that) {
case _VolumeUserStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolumeUserStatus() when $default != null:
return $default(_that.currentPage,_that.maxPage,_that.isFinished);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished)  $default,) {final _that = this;
switch (_that) {
case _VolumeUserStatus():
return $default(_that.currentPage,_that.maxPage,_that.isFinished);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished)?  $default,) {final _that = this;
switch (_that) {
case _VolumeUserStatus() when $default != null:
return $default(_that.currentPage,_that.maxPage,_that.isFinished);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolumeUserStatus implements VolumeUserStatus {
  const _VolumeUserStatus({@JsonKey(name: 'current_page') this.currentPage = 0, @JsonKey(name: 'max_page') this.maxPage = 0, @JsonKey(name: 'is_finished', fromJson: boolFromJson) this.isFinished = false});
  factory _VolumeUserStatus.fromJson(Map<String, dynamic> json) => _$VolumeUserStatusFromJson(json);

@override@JsonKey(name: 'current_page') final  int currentPage;
@override@JsonKey(name: 'max_page') final  int maxPage;
@override@JsonKey(name: 'is_finished', fromJson: boolFromJson) final  bool isFinished;

/// Create a copy of VolumeUserStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolumeUserStatusCopyWith<_VolumeUserStatus> get copyWith => __$VolumeUserStatusCopyWithImpl<_VolumeUserStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolumeUserStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolumeUserStatus&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.maxPage, maxPage) || other.maxPage == maxPage)&&(identical(other.isFinished, isFinished) || other.isFinished == isFinished));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,currentPage,maxPage,isFinished);
}

@override
String toString() {
    return 'VolumeUserStatus(currentPage: $currentPage, maxPage: $maxPage, isFinished: $isFinished)';
}


}

/// @nodoc
abstract mixin class _$VolumeUserStatusCopyWith<$Res> implements $VolumeUserStatusCopyWith<$Res> {
  factory _$VolumeUserStatusCopyWith(_VolumeUserStatus value, $Res Function(_VolumeUserStatus) _then) = __$VolumeUserStatusCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool isFinished
});




}
/// @nodoc
class __$VolumeUserStatusCopyWithImpl<$Res>
    implements _$VolumeUserStatusCopyWith<$Res> {
  __$VolumeUserStatusCopyWithImpl(this._self, this._then);

  final _VolumeUserStatus _self;
  final $Res Function(_VolumeUserStatus) _then;

/// Create a copy of VolumeUserStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentPage = null,Object? maxPage = null,Object? isFinished = null,}) {
  return _then(_VolumeUserStatus(
currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,isFinished: null == isFinished ? _self.isFinished : isFinished // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ReadingProgress {

@JsonKey(name: 'read_volumes') int get readVolumes;@JsonKey(name: 'total_volumes') int get totalVolumes;/// 読みかけの巻の**巻数**（巻 ID ではない）。無ければ `null`。
@JsonKey(name: 'current_volume') int? get currentVolume;@JsonKey(name: 'current_page') int get currentPage;@JsonKey(name: 'total_pages') int get totalPages;
/// Create a copy of ReadingProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingProgressCopyWith<ReadingProgress> get copyWith => _$ReadingProgressCopyWithImpl<ReadingProgress>(this as ReadingProgress, _$identity);

  /// Serializes this ReadingProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReadingProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingProgress&&(identical(other.readVolumes, _this.readVolumes) || other.readVolumes == _this.readVolumes)&&(identical(other.totalVolumes, _this.totalVolumes) || other.totalVolumes == _this.totalVolumes)&&(identical(other.currentVolume, _this.currentVolume) || other.currentVolume == _this.currentVolume)&&(identical(other.currentPage, _this.currentPage) || other.currentPage == _this.currentPage)&&(identical(other.totalPages, _this.totalPages) || other.totalPages == _this.totalPages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReadingProgress;
  return Object.hash(runtimeType,_this.readVolumes,_this.totalVolumes,_this.currentVolume,_this.currentPage,_this.totalPages);
}

@override
String toString() {
  final _this = this as ReadingProgress;
  return 'ReadingProgress(readVolumes: ${_this.readVolumes}, totalVolumes: ${_this.totalVolumes}, currentVolume: ${_this.currentVolume}, currentPage: ${_this.currentPage}, totalPages: ${_this.totalPages})';
}


}

/// @nodoc
abstract mixin class $ReadingProgressCopyWith<$Res>  {
  factory $ReadingProgressCopyWith(ReadingProgress value, $Res Function(ReadingProgress) _then) = _$ReadingProgressCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'read_volumes') int readVolumes,@JsonKey(name: 'total_volumes') int totalVolumes,@JsonKey(name: 'current_volume') int? currentVolume,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'total_pages') int totalPages
});




}
/// @nodoc
class _$ReadingProgressCopyWithImpl<$Res>
    implements $ReadingProgressCopyWith<$Res> {
  _$ReadingProgressCopyWithImpl(this._self, this._then);

  final ReadingProgress _self;
  final $Res Function(ReadingProgress) _then;

/// Create a copy of ReadingProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? readVolumes = null,Object? totalVolumes = null,Object? currentVolume = freezed,Object? currentPage = null,Object? totalPages = null,}) {
  return _then(ReadingProgress(
readVolumes: null == readVolumes ? _self.readVolumes : readVolumes // ignore: cast_nullable_to_non_nullable
as int,totalVolumes: null == totalVolumes ? _self.totalVolumes : totalVolumes // ignore: cast_nullable_to_non_nullable
as int,currentVolume: freezed == currentVolume ? _self.currentVolume : currentVolume // ignore: cast_nullable_to_non_nullable
as int?,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingProgress].
extension ReadingProgressPatterns on ReadingProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingProgress value)  $default,){
final _that = this;
switch (_that) {
case _ReadingProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingProgress value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'read_volumes')  int readVolumes, @JsonKey(name: 'total_volumes')  int totalVolumes, @JsonKey(name: 'current_volume')  int? currentVolume, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'total_pages')  int totalPages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingProgress() when $default != null:
return $default(_that.readVolumes,_that.totalVolumes,_that.currentVolume,_that.currentPage,_that.totalPages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'read_volumes')  int readVolumes, @JsonKey(name: 'total_volumes')  int totalVolumes, @JsonKey(name: 'current_volume')  int? currentVolume, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'total_pages')  int totalPages)  $default,) {final _that = this;
switch (_that) {
case _ReadingProgress():
return $default(_that.readVolumes,_that.totalVolumes,_that.currentVolume,_that.currentPage,_that.totalPages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'read_volumes')  int readVolumes, @JsonKey(name: 'total_volumes')  int totalVolumes, @JsonKey(name: 'current_volume')  int? currentVolume, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'total_pages')  int totalPages)?  $default,) {final _that = this;
switch (_that) {
case _ReadingProgress() when $default != null:
return $default(_that.readVolumes,_that.totalVolumes,_that.currentVolume,_that.currentPage,_that.totalPages);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReadingProgress implements ReadingProgress {
  const _ReadingProgress({@JsonKey(name: 'read_volumes') this.readVolumes = 0, @JsonKey(name: 'total_volumes') this.totalVolumes = 0, @JsonKey(name: 'current_volume') this.currentVolume, @JsonKey(name: 'current_page') this.currentPage = 0, @JsonKey(name: 'total_pages') this.totalPages = 0});
  factory _ReadingProgress.fromJson(Map<String, dynamic> json) => _$ReadingProgressFromJson(json);

@override@JsonKey(name: 'read_volumes') final  int readVolumes;
@override@JsonKey(name: 'total_volumes') final  int totalVolumes;
/// 読みかけの巻の**巻数**（巻 ID ではない）。無ければ `null`。
@override@JsonKey(name: 'current_volume') final  int? currentVolume;
@override@JsonKey(name: 'current_page') final  int currentPage;
@override@JsonKey(name: 'total_pages') final  int totalPages;

/// Create a copy of ReadingProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingProgressCopyWith<_ReadingProgress> get copyWith => __$ReadingProgressCopyWithImpl<_ReadingProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReadingProgressToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingProgress&&(identical(other.readVolumes, readVolumes) || other.readVolumes == readVolumes)&&(identical(other.totalVolumes, totalVolumes) || other.totalVolumes == totalVolumes)&&(identical(other.currentVolume, currentVolume) || other.currentVolume == currentVolume)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,readVolumes,totalVolumes,currentVolume,currentPage,totalPages);
}

@override
String toString() {
    return 'ReadingProgress(readVolumes: $readVolumes, totalVolumes: $totalVolumes, currentVolume: $currentVolume, currentPage: $currentPage, totalPages: $totalPages)';
}


}

/// @nodoc
abstract mixin class _$ReadingProgressCopyWith<$Res> implements $ReadingProgressCopyWith<$Res> {
  factory _$ReadingProgressCopyWith(_ReadingProgress value, $Res Function(_ReadingProgress) _then) = __$ReadingProgressCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'read_volumes') int readVolumes,@JsonKey(name: 'total_volumes') int totalVolumes,@JsonKey(name: 'current_volume') int? currentVolume,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'total_pages') int totalPages
});




}
/// @nodoc
class __$ReadingProgressCopyWithImpl<$Res>
    implements _$ReadingProgressCopyWith<$Res> {
  __$ReadingProgressCopyWithImpl(this._self, this._then);

  final _ReadingProgress _self;
  final $Res Function(_ReadingProgress) _then;

/// Create a copy of ReadingProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? readVolumes = null,Object? totalVolumes = null,Object? currentVolume = freezed,Object? currentPage = null,Object? totalPages = null,}) {
  return _then(_ReadingProgress(
readVolumes: null == readVolumes ? _self.readVolumes : readVolumes // ignore: cast_nullable_to_non_nullable
as int,totalVolumes: null == totalVolumes ? _self.totalVolumes : totalVolumes // ignore: cast_nullable_to_non_nullable
as int,currentVolume: freezed == currentVolume ? _self.currentVolume : currentVolume // ignore: cast_nullable_to_non_nullable
as int?,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
