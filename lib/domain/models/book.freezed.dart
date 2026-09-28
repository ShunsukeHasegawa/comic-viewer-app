// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Book {

 int get id; String get title;/// 五十音順の並び替え / 検索に使う読み。
 String? get kana;/// 最新巻のサムネイル URL（`?m=updated_at` 付きの相対 URL）。
/// `null` は「サムネイル無し」。組み立て直してはいけない。
 String? get thumbnail;@JsonKey(name: 'is_complete', fromJson: boolFromJson) bool get isComplete;@JsonKey(name: 'is_unsafe', fromJson: boolFromJson) bool get isUnsafe;/// 最新巻が追加された日時（更新日順の並び替えに使う）。
@JsonKey(name: 'volume_added_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? get volumeAddedAt;@JsonKey(name: 'latest_volume') int? get latestVolume;@JsonKey(fromJson: stringListFromJson) List<String> get author;@JsonKey(fromJson: intListFromJson) List<int> get tags;@JsonKey(fromJson: intListFromJson) List<int> get categories;
/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookCopyWith<Book> get copyWith => _$BookCopyWithImpl<Book>(this as Book, _$identity);

  /// Serializes this Book to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Book;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Book&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.kana, _this.kana) || other.kana == _this.kana)&&(identical(other.thumbnail, _this.thumbnail) || other.thumbnail == _this.thumbnail)&&(identical(other.isComplete, _this.isComplete) || other.isComplete == _this.isComplete)&&(identical(other.isUnsafe, _this.isUnsafe) || other.isUnsafe == _this.isUnsafe)&&(identical(other.volumeAddedAt, _this.volumeAddedAt) || other.volumeAddedAt == _this.volumeAddedAt)&&(identical(other.latestVolume, _this.latestVolume) || other.latestVolume == _this.latestVolume)&&const DeepCollectionEquality().equals(other.author, _this.author)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.categories, _this.categories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Book;
  return Object.hash(runtimeType,_this.id,_this.title,_this.kana,_this.thumbnail,_this.isComplete,_this.isUnsafe,_this.volumeAddedAt,_this.latestVolume,const DeepCollectionEquality().hash(_this.author),const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.categories));
}

@override
String toString() {
  final _this = this as Book;
  return 'Book(id: ${_this.id}, title: ${_this.title}, kana: ${_this.kana}, thumbnail: ${_this.thumbnail}, isComplete: ${_this.isComplete}, isUnsafe: ${_this.isUnsafe}, volumeAddedAt: ${_this.volumeAddedAt}, latestVolume: ${_this.latestVolume}, author: ${_this.author}, tags: ${_this.tags}, categories: ${_this.categories})';
}


}

/// @nodoc
abstract mixin class $BookCopyWith<$Res>  {
  factory $BookCopyWith(Book value, $Res Function(Book) _then) = _$BookCopyWithImpl;
@useResult
$Res call({
 int id, String title, String? kana, String? thumbnail,@JsonKey(name: 'is_complete', fromJson: boolFromJson) bool isComplete,@JsonKey(name: 'is_unsafe', fromJson: boolFromJson) bool isUnsafe,@JsonKey(name: 'volume_added_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? volumeAddedAt,@JsonKey(name: 'latest_volume') int? latestVolume,@JsonKey(fromJson: stringListFromJson) List<String> author,@JsonKey(fromJson: intListFromJson) List<int> tags,@JsonKey(fromJson: intListFromJson) List<int> categories
});




}
/// @nodoc
class _$BookCopyWithImpl<$Res>
    implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._self, this._then);

  final Book _self;
  final $Res Function(Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? kana = freezed,Object? thumbnail = freezed,Object? isComplete = null,Object? isUnsafe = null,Object? volumeAddedAt = freezed,Object? latestVolume = freezed,Object? author = null,Object? tags = null,Object? categories = null,}) {
  return _then(Book(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,kana: freezed == kana ? _self.kana : kana // ignore: cast_nullable_to_non_nullable
as String?,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,isUnsafe: null == isUnsafe ? _self.isUnsafe : isUnsafe // ignore: cast_nullable_to_non_nullable
as bool,volumeAddedAt: freezed == volumeAddedAt ? _self.volumeAddedAt : volumeAddedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,latestVolume: freezed == latestVolume ? _self.latestVolume : latestVolume // ignore: cast_nullable_to_non_nullable
as int?,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<int>,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [Book].
extension BookPatterns on Book {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Book value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Book value)  $default,){
final _that = this;
switch (_that) {
case _Book():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Book value)?  $default,){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String? kana,  String? thumbnail, @JsonKey(name: 'is_complete', fromJson: boolFromJson)  bool isComplete, @JsonKey(name: 'is_unsafe', fromJson: boolFromJson)  bool isUnsafe, @JsonKey(name: 'volume_added_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? volumeAddedAt, @JsonKey(name: 'latest_volume')  int? latestVolume, @JsonKey(fromJson: stringListFromJson)  List<String> author, @JsonKey(fromJson: intListFromJson)  List<int> tags, @JsonKey(fromJson: intListFromJson)  List<int> categories)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.id,_that.title,_that.kana,_that.thumbnail,_that.isComplete,_that.isUnsafe,_that.volumeAddedAt,_that.latestVolume,_that.author,_that.tags,_that.categories);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String? kana,  String? thumbnail, @JsonKey(name: 'is_complete', fromJson: boolFromJson)  bool isComplete, @JsonKey(name: 'is_unsafe', fromJson: boolFromJson)  bool isUnsafe, @JsonKey(name: 'volume_added_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? volumeAddedAt, @JsonKey(name: 'latest_volume')  int? latestVolume, @JsonKey(fromJson: stringListFromJson)  List<String> author, @JsonKey(fromJson: intListFromJson)  List<int> tags, @JsonKey(fromJson: intListFromJson)  List<int> categories)  $default,) {final _that = this;
switch (_that) {
case _Book():
return $default(_that.id,_that.title,_that.kana,_that.thumbnail,_that.isComplete,_that.isUnsafe,_that.volumeAddedAt,_that.latestVolume,_that.author,_that.tags,_that.categories);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String? kana,  String? thumbnail, @JsonKey(name: 'is_complete', fromJson: boolFromJson)  bool isComplete, @JsonKey(name: 'is_unsafe', fromJson: boolFromJson)  bool isUnsafe, @JsonKey(name: 'volume_added_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? volumeAddedAt, @JsonKey(name: 'latest_volume')  int? latestVolume, @JsonKey(fromJson: stringListFromJson)  List<String> author, @JsonKey(fromJson: intListFromJson)  List<int> tags, @JsonKey(fromJson: intListFromJson)  List<int> categories)?  $default,) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.id,_that.title,_that.kana,_that.thumbnail,_that.isComplete,_that.isUnsafe,_that.volumeAddedAt,_that.latestVolume,_that.author,_that.tags,_that.categories);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Book implements Book {
  const _Book({required this.id, this.title = '', this.kana, this.thumbnail, @JsonKey(name: 'is_complete', fromJson: boolFromJson) this.isComplete = false, @JsonKey(name: 'is_unsafe', fromJson: boolFromJson) this.isUnsafe = false, @JsonKey(name: 'volume_added_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) this.volumeAddedAt, @JsonKey(name: 'latest_volume') this.latestVolume, @JsonKey(fromJson: stringListFromJson)  List<String> author = const [], @JsonKey(fromJson: intListFromJson)  List<int> tags = const [], @JsonKey(fromJson: intListFromJson)  List<int> categories = const []}): _author = author,_tags = tags,_categories = categories;
  factory _Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);

@override final  int id;
@override@JsonKey() final  String title;
/// 五十音順の並び替え / 検索に使う読み。
@override final  String? kana;
/// 最新巻のサムネイル URL（`?m=updated_at` 付きの相対 URL）。
/// `null` は「サムネイル無し」。組み立て直してはいけない。
@override final  String? thumbnail;
@override@JsonKey(name: 'is_complete', fromJson: boolFromJson) final  bool isComplete;
@override@JsonKey(name: 'is_unsafe', fromJson: boolFromJson) final  bool isUnsafe;
/// 最新巻が追加された日時（更新日順の並び替えに使う）。
@override@JsonKey(name: 'volume_added_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) final  DateTime? volumeAddedAt;
@override@JsonKey(name: 'latest_volume') final  int? latestVolume;
 final  List<String> _author;
@override@JsonKey(fromJson: stringListFromJson) List<String> get author {
  if (_author is EqualUnmodifiableListView) return _author;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_author);
}

 final  List<int> _tags;
@override@JsonKey(fromJson: intListFromJson) List<int> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<int> _categories;
@override@JsonKey(fromJson: intListFromJson) List<int> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}


/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookCopyWith<_Book> get copyWith => __$BookCopyWithImpl<_Book>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Book&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.kana, kana) || other.kana == kana)&&(identical(other.thumbnail, thumbnail) || other.thumbnail == thumbnail)&&(identical(other.isComplete, isComplete) || other.isComplete == isComplete)&&(identical(other.isUnsafe, isUnsafe) || other.isUnsafe == isUnsafe)&&(identical(other.volumeAddedAt, volumeAddedAt) || other.volumeAddedAt == volumeAddedAt)&&(identical(other.latestVolume, latestVolume) || other.latestVolume == latestVolume)&&const DeepCollectionEquality().equals(other.author, _author)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.categories, _categories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,kana,thumbnail,isComplete,isUnsafe,volumeAddedAt,latestVolume,const DeepCollectionEquality().hash(_author),const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_categories));
}

@override
String toString() {
    return 'Book(id: $id, title: $title, kana: $kana, thumbnail: $thumbnail, isComplete: $isComplete, isUnsafe: $isUnsafe, volumeAddedAt: $volumeAddedAt, latestVolume: $latestVolume, author: $author, tags: $tags, categories: $categories)';
}


}

/// @nodoc
abstract mixin class _$BookCopyWith<$Res> implements $BookCopyWith<$Res> {
  factory _$BookCopyWith(_Book value, $Res Function(_Book) _then) = __$BookCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String? kana, String? thumbnail,@JsonKey(name: 'is_complete', fromJson: boolFromJson) bool isComplete,@JsonKey(name: 'is_unsafe', fromJson: boolFromJson) bool isUnsafe,@JsonKey(name: 'volume_added_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? volumeAddedAt,@JsonKey(name: 'latest_volume') int? latestVolume,@JsonKey(fromJson: stringListFromJson) List<String> author,@JsonKey(fromJson: intListFromJson) List<int> tags,@JsonKey(fromJson: intListFromJson) List<int> categories
});




}
/// @nodoc
class __$BookCopyWithImpl<$Res>
    implements _$BookCopyWith<$Res> {
  __$BookCopyWithImpl(this._self, this._then);

  final _Book _self;
  final $Res Function(_Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? kana = freezed,Object? thumbnail = freezed,Object? isComplete = null,Object? isUnsafe = null,Object? volumeAddedAt = freezed,Object? latestVolume = freezed,Object? author = null,Object? tags = null,Object? categories = null,}) {
  return _then(_Book(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,kana: freezed == kana ? _self.kana : kana // ignore: cast_nullable_to_non_nullable
as String?,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,isUnsafe: null == isUnsafe ? _self.isUnsafe : isUnsafe // ignore: cast_nullable_to_non_nullable
as bool,volumeAddedAt: freezed == volumeAddedAt ? _self.volumeAddedAt : volumeAddedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,latestVolume: freezed == latestVolume ? _self.latestVolume : latestVolume // ignore: cast_nullable_to_non_nullable
as int?,author: null == author ? _self._author : author // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<int>,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}


/// @nodoc
mixin _$UserStatus {

/// 未読の巻を含む書籍 ID。
@JsonKey(fromJson: intListFromJson) List<int> get unreads;/// お気に入りの書籍 ID。
@JsonKey(fromJson: intListFromJson) List<int> get favorites;
/// Create a copy of UserStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserStatusCopyWith<UserStatus> get copyWith => _$UserStatusCopyWithImpl<UserStatus>(this as UserStatus, _$identity);

  /// Serializes this UserStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserStatus&&const DeepCollectionEquality().equals(other.unreads, _this.unreads)&&const DeepCollectionEquality().equals(other.favorites, _this.favorites));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserStatus;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.unreads),const DeepCollectionEquality().hash(_this.favorites));
}

@override
String toString() {
  final _this = this as UserStatus;
  return 'UserStatus(unreads: ${_this.unreads}, favorites: ${_this.favorites})';
}


}

/// @nodoc
abstract mixin class $UserStatusCopyWith<$Res>  {
  factory $UserStatusCopyWith(UserStatus value, $Res Function(UserStatus) _then) = _$UserStatusCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: intListFromJson) List<int> unreads,@JsonKey(fromJson: intListFromJson) List<int> favorites
});




}
/// @nodoc
class _$UserStatusCopyWithImpl<$Res>
    implements $UserStatusCopyWith<$Res> {
  _$UserStatusCopyWithImpl(this._self, this._then);

  final UserStatus _self;
  final $Res Function(UserStatus) _then;

/// Create a copy of UserStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? unreads = null,Object? favorites = null,}) {
  return _then(UserStatus(
unreads: null == unreads ? _self.unreads : unreads // ignore: cast_nullable_to_non_nullable
as List<int>,favorites: null == favorites ? _self.favorites : favorites // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserStatus].
extension UserStatusPatterns on UserStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserStatus value)  $default,){
final _that = this;
switch (_that) {
case _UserStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserStatus value)?  $default,){
final _that = this;
switch (_that) {
case _UserStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: intListFromJson)  List<int> unreads, @JsonKey(fromJson: intListFromJson)  List<int> favorites)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserStatus() when $default != null:
return $default(_that.unreads,_that.favorites);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: intListFromJson)  List<int> unreads, @JsonKey(fromJson: intListFromJson)  List<int> favorites)  $default,) {final _that = this;
switch (_that) {
case _UserStatus():
return $default(_that.unreads,_that.favorites);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: intListFromJson)  List<int> unreads, @JsonKey(fromJson: intListFromJson)  List<int> favorites)?  $default,) {final _that = this;
switch (_that) {
case _UserStatus() when $default != null:
return $default(_that.unreads,_that.favorites);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserStatus implements UserStatus {
  const _UserStatus({@JsonKey(fromJson: intListFromJson)  List<int> unreads = const [], @JsonKey(fromJson: intListFromJson)  List<int> favorites = const []}): _unreads = unreads,_favorites = favorites;
  factory _UserStatus.fromJson(Map<String, dynamic> json) => _$UserStatusFromJson(json);

/// 未読の巻を含む書籍 ID。
 final  List<int> _unreads;
/// 未読の巻を含む書籍 ID。
@override@JsonKey(fromJson: intListFromJson) List<int> get unreads {
  if (_unreads is EqualUnmodifiableListView) return _unreads;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_unreads);
}

/// お気に入りの書籍 ID。
 final  List<int> _favorites;
/// お気に入りの書籍 ID。
@override@JsonKey(fromJson: intListFromJson) List<int> get favorites {
  if (_favorites is EqualUnmodifiableListView) return _favorites;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_favorites);
}


/// Create a copy of UserStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserStatusCopyWith<_UserStatus> get copyWith => __$UserStatusCopyWithImpl<_UserStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserStatus&&const DeepCollectionEquality().equals(other.unreads, _unreads)&&const DeepCollectionEquality().equals(other.favorites, _favorites));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_unreads),const DeepCollectionEquality().hash(_favorites));
}

@override
String toString() {
    return 'UserStatus(unreads: $unreads, favorites: $favorites)';
}


}

/// @nodoc
abstract mixin class _$UserStatusCopyWith<$Res> implements $UserStatusCopyWith<$Res> {
  factory _$UserStatusCopyWith(_UserStatus value, $Res Function(_UserStatus) _then) = __$UserStatusCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: intListFromJson) List<int> unreads,@JsonKey(fromJson: intListFromJson) List<int> favorites
});




}
/// @nodoc
class __$UserStatusCopyWithImpl<$Res>
    implements _$UserStatusCopyWith<$Res> {
  __$UserStatusCopyWithImpl(this._self, this._then);

  final _UserStatus _self;
  final $Res Function(_UserStatus) _then;

/// Create a copy of UserStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? unreads = null,Object? favorites = null,}) {
  return _then(_UserStatus(
unreads: null == unreads ? _self._unreads : unreads // ignore: cast_nullable_to_non_nullable
as List<int>,favorites: null == favorites ? _self._favorites : favorites // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

// dart format on
