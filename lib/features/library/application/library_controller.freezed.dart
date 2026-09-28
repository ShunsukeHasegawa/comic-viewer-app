// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LibraryData {

 List<Book> get books; Set<int> get favoriteIds; Set<int> get unreadIds; List<ReadingBook> get reading; List<Taxonomy> get categories; List<Taxonomy> get tags; BookSearchIndex get searchIndex; DateTime get fetchedAt;/// サーバーに確認できず手元の内容を表示している（圏外など）。
 bool get isStale;
/// Create a copy of LibraryData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryDataCopyWith<LibraryData> get copyWith => _$LibraryDataCopyWithImpl<LibraryData>(this as LibraryData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LibraryData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryData&&const DeepCollectionEquality().equals(other.books, _this.books)&&const DeepCollectionEquality().equals(other.favoriteIds, _this.favoriteIds)&&const DeepCollectionEquality().equals(other.unreadIds, _this.unreadIds)&&const DeepCollectionEquality().equals(other.reading, _this.reading)&&const DeepCollectionEquality().equals(other.categories, _this.categories)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.searchIndex, _this.searchIndex) || other.searchIndex == _this.searchIndex)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt)&&(identical(other.isStale, _this.isStale) || other.isStale == _this.isStale));
}


@override
int get hashCode {
  final _this = this as LibraryData;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.books),const DeepCollectionEquality().hash(_this.favoriteIds),const DeepCollectionEquality().hash(_this.unreadIds),const DeepCollectionEquality().hash(_this.reading),const DeepCollectionEquality().hash(_this.categories),const DeepCollectionEquality().hash(_this.tags),_this.searchIndex,_this.fetchedAt,_this.isStale);
}

@override
String toString() {
  final _this = this as LibraryData;
  return 'LibraryData(books: ${_this.books}, favoriteIds: ${_this.favoriteIds}, unreadIds: ${_this.unreadIds}, reading: ${_this.reading}, categories: ${_this.categories}, tags: ${_this.tags}, searchIndex: ${_this.searchIndex}, fetchedAt: ${_this.fetchedAt}, isStale: ${_this.isStale})';
}


}

/// @nodoc
abstract mixin class $LibraryDataCopyWith<$Res>  {
  factory $LibraryDataCopyWith(LibraryData value, $Res Function(LibraryData) _then) = _$LibraryDataCopyWithImpl;
@useResult
$Res call({
 List<Book> books, Set<int> favoriteIds, Set<int> unreadIds, List<ReadingBook> reading, List<Taxonomy> categories, List<Taxonomy> tags, BookSearchIndex searchIndex, DateTime fetchedAt, bool isStale
});




}
/// @nodoc
class _$LibraryDataCopyWithImpl<$Res>
    implements $LibraryDataCopyWith<$Res> {
  _$LibraryDataCopyWithImpl(this._self, this._then);

  final LibraryData _self;
  final $Res Function(LibraryData) _then;

/// Create a copy of LibraryData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? books = null,Object? favoriteIds = null,Object? unreadIds = null,Object? reading = null,Object? categories = null,Object? tags = null,Object? searchIndex = null,Object? fetchedAt = null,Object? isStale = null,}) {
  return _then(LibraryData(
books: null == books ? _self.books : books // ignore: cast_nullable_to_non_nullable
as List<Book>,favoriteIds: null == favoriteIds ? _self.favoriteIds : favoriteIds // ignore: cast_nullable_to_non_nullable
as Set<int>,unreadIds: null == unreadIds ? _self.unreadIds : unreadIds // ignore: cast_nullable_to_non_nullable
as Set<int>,reading: null == reading ? _self.reading : reading // ignore: cast_nullable_to_non_nullable
as List<ReadingBook>,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<Taxonomy>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<Taxonomy>,searchIndex: null == searchIndex ? _self.searchIndex : searchIndex // ignore: cast_nullable_to_non_nullable
as BookSearchIndex,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LibraryData].
extension LibraryDataPatterns on LibraryData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryData value)  $default,){
final _that = this;
switch (_that) {
case _LibraryData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryData value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Book> books,  Set<int> favoriteIds,  Set<int> unreadIds,  List<ReadingBook> reading,  List<Taxonomy> categories,  List<Taxonomy> tags,  BookSearchIndex searchIndex,  DateTime fetchedAt,  bool isStale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryData() when $default != null:
return $default(_that.books,_that.favoriteIds,_that.unreadIds,_that.reading,_that.categories,_that.tags,_that.searchIndex,_that.fetchedAt,_that.isStale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Book> books,  Set<int> favoriteIds,  Set<int> unreadIds,  List<ReadingBook> reading,  List<Taxonomy> categories,  List<Taxonomy> tags,  BookSearchIndex searchIndex,  DateTime fetchedAt,  bool isStale)  $default,) {final _that = this;
switch (_that) {
case _LibraryData():
return $default(_that.books,_that.favoriteIds,_that.unreadIds,_that.reading,_that.categories,_that.tags,_that.searchIndex,_that.fetchedAt,_that.isStale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Book> books,  Set<int> favoriteIds,  Set<int> unreadIds,  List<ReadingBook> reading,  List<Taxonomy> categories,  List<Taxonomy> tags,  BookSearchIndex searchIndex,  DateTime fetchedAt,  bool isStale)?  $default,) {final _that = this;
switch (_that) {
case _LibraryData() when $default != null:
return $default(_that.books,_that.favoriteIds,_that.unreadIds,_that.reading,_that.categories,_that.tags,_that.searchIndex,_that.fetchedAt,_that.isStale);case _:
  return null;

}
}

}

/// @nodoc


class _LibraryData implements LibraryData {
  const _LibraryData({required  List<Book> books, required  Set<int> favoriteIds, required  Set<int> unreadIds, required  List<ReadingBook> reading, required  List<Taxonomy> categories, required  List<Taxonomy> tags, required this.searchIndex, required this.fetchedAt, this.isStale = false}): _books = books,_favoriteIds = favoriteIds,_unreadIds = unreadIds,_reading = reading,_categories = categories,_tags = tags;
  

 final  List<Book> _books;
@override List<Book> get books {
  if (_books is EqualUnmodifiableListView) return _books;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_books);
}

 final  Set<int> _favoriteIds;
@override Set<int> get favoriteIds {
  if (_favoriteIds is EqualUnmodifiableSetView) return _favoriteIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_favoriteIds);
}

 final  Set<int> _unreadIds;
@override Set<int> get unreadIds {
  if (_unreadIds is EqualUnmodifiableSetView) return _unreadIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_unreadIds);
}

 final  List<ReadingBook> _reading;
@override List<ReadingBook> get reading {
  if (_reading is EqualUnmodifiableListView) return _reading;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reading);
}

 final  List<Taxonomy> _categories;
@override List<Taxonomy> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  List<Taxonomy> _tags;
@override List<Taxonomy> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  BookSearchIndex searchIndex;
@override final  DateTime fetchedAt;
/// サーバーに確認できず手元の内容を表示している（圏外など）。
@override@JsonKey() final  bool isStale;

/// Create a copy of LibraryData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryDataCopyWith<_LibraryData> get copyWith => __$LibraryDataCopyWithImpl<_LibraryData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryData&&const DeepCollectionEquality().equals(other.books, _books)&&const DeepCollectionEquality().equals(other.favoriteIds, _favoriteIds)&&const DeepCollectionEquality().equals(other.unreadIds, _unreadIds)&&const DeepCollectionEquality().equals(other.reading, _reading)&&const DeepCollectionEquality().equals(other.categories, _categories)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.searchIndex, searchIndex) || other.searchIndex == searchIndex)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt)&&(identical(other.isStale, isStale) || other.isStale == isStale));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_books),const DeepCollectionEquality().hash(_favoriteIds),const DeepCollectionEquality().hash(_unreadIds),const DeepCollectionEquality().hash(_reading),const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_tags),searchIndex,fetchedAt,isStale);
}

@override
String toString() {
    return 'LibraryData(books: $books, favoriteIds: $favoriteIds, unreadIds: $unreadIds, reading: $reading, categories: $categories, tags: $tags, searchIndex: $searchIndex, fetchedAt: $fetchedAt, isStale: $isStale)';
}


}

/// @nodoc
abstract mixin class _$LibraryDataCopyWith<$Res> implements $LibraryDataCopyWith<$Res> {
  factory _$LibraryDataCopyWith(_LibraryData value, $Res Function(_LibraryData) _then) = __$LibraryDataCopyWithImpl;
@override @useResult
$Res call({
 List<Book> books, Set<int> favoriteIds, Set<int> unreadIds, List<ReadingBook> reading, List<Taxonomy> categories, List<Taxonomy> tags, BookSearchIndex searchIndex, DateTime fetchedAt, bool isStale
});




}
/// @nodoc
class __$LibraryDataCopyWithImpl<$Res>
    implements _$LibraryDataCopyWith<$Res> {
  __$LibraryDataCopyWithImpl(this._self, this._then);

  final _LibraryData _self;
  final $Res Function(_LibraryData) _then;

/// Create a copy of LibraryData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? books = null,Object? favoriteIds = null,Object? unreadIds = null,Object? reading = null,Object? categories = null,Object? tags = null,Object? searchIndex = null,Object? fetchedAt = null,Object? isStale = null,}) {
  return _then(_LibraryData(
books: null == books ? _self._books : books // ignore: cast_nullable_to_non_nullable
as List<Book>,favoriteIds: null == favoriteIds ? _self._favoriteIds : favoriteIds // ignore: cast_nullable_to_non_nullable
as Set<int>,unreadIds: null == unreadIds ? _self._unreadIds : unreadIds // ignore: cast_nullable_to_non_nullable
as Set<int>,reading: null == reading ? _self._reading : reading // ignore: cast_nullable_to_non_nullable
as List<ReadingBook>,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<Taxonomy>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<Taxonomy>,searchIndex: null == searchIndex ? _self.searchIndex : searchIndex // ignore: cast_nullable_to_non_nullable
as BookSearchIndex,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
