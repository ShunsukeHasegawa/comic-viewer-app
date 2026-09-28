// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReadingBook {

@JsonKey(name: 'book_id') int get bookId; String get title;/// `?m=` 付きの相対 URL。`null` はサムネイル無し。
 String? get thumbnail;@JsonKey(name: 'volume_number') int get volumeNumber;@JsonKey(name: 'volume_id') int get volumeId;@JsonKey(name: 'current_page') int get currentPage;@JsonKey(name: 'max_page') int get maxPage;/// サーバーが計算した進捗率（0-100）。
@JsonKey(name: 'progress_percent') int get progressPercent;
/// Create a copy of ReadingBook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingBookCopyWith<ReadingBook> get copyWith => _$ReadingBookCopyWithImpl<ReadingBook>(this as ReadingBook, _$identity);

  /// Serializes this ReadingBook to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReadingBook;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingBook&&(identical(other.bookId, _this.bookId) || other.bookId == _this.bookId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.thumbnail, _this.thumbnail) || other.thumbnail == _this.thumbnail)&&(identical(other.volumeNumber, _this.volumeNumber) || other.volumeNumber == _this.volumeNumber)&&(identical(other.volumeId, _this.volumeId) || other.volumeId == _this.volumeId)&&(identical(other.currentPage, _this.currentPage) || other.currentPage == _this.currentPage)&&(identical(other.maxPage, _this.maxPage) || other.maxPage == _this.maxPage)&&(identical(other.progressPercent, _this.progressPercent) || other.progressPercent == _this.progressPercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReadingBook;
  return Object.hash(runtimeType,_this.bookId,_this.title,_this.thumbnail,_this.volumeNumber,_this.volumeId,_this.currentPage,_this.maxPage,_this.progressPercent);
}

@override
String toString() {
  final _this = this as ReadingBook;
  return 'ReadingBook(bookId: ${_this.bookId}, title: ${_this.title}, thumbnail: ${_this.thumbnail}, volumeNumber: ${_this.volumeNumber}, volumeId: ${_this.volumeId}, currentPage: ${_this.currentPage}, maxPage: ${_this.maxPage}, progressPercent: ${_this.progressPercent})';
}


}

/// @nodoc
abstract mixin class $ReadingBookCopyWith<$Res>  {
  factory $ReadingBookCopyWith(ReadingBook value, $Res Function(ReadingBook) _then) = _$ReadingBookCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'book_id') int bookId, String title, String? thumbnail,@JsonKey(name: 'volume_number') int volumeNumber,@JsonKey(name: 'volume_id') int volumeId,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'progress_percent') int progressPercent
});




}
/// @nodoc
class _$ReadingBookCopyWithImpl<$Res>
    implements $ReadingBookCopyWith<$Res> {
  _$ReadingBookCopyWithImpl(this._self, this._then);

  final ReadingBook _self;
  final $Res Function(ReadingBook) _then;

/// Create a copy of ReadingBook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookId = null,Object? title = null,Object? thumbnail = freezed,Object? volumeNumber = null,Object? volumeId = null,Object? currentPage = null,Object? maxPage = null,Object? progressPercent = null,}) {
  return _then(ReadingBook(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,volumeNumber: null == volumeNumber ? _self.volumeNumber : volumeNumber // ignore: cast_nullable_to_non_nullable
as int,volumeId: null == volumeId ? _self.volumeId : volumeId // ignore: cast_nullable_to_non_nullable
as int,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,progressPercent: null == progressPercent ? _self.progressPercent : progressPercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingBook].
extension ReadingBookPatterns on ReadingBook {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingBook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingBook() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingBook value)  $default,){
final _that = this;
switch (_that) {
case _ReadingBook():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingBook value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingBook() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'book_id')  int bookId,  String title,  String? thumbnail, @JsonKey(name: 'volume_number')  int volumeNumber, @JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'progress_percent')  int progressPercent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingBook() when $default != null:
return $default(_that.bookId,_that.title,_that.thumbnail,_that.volumeNumber,_that.volumeId,_that.currentPage,_that.maxPage,_that.progressPercent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'book_id')  int bookId,  String title,  String? thumbnail, @JsonKey(name: 'volume_number')  int volumeNumber, @JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'progress_percent')  int progressPercent)  $default,) {final _that = this;
switch (_that) {
case _ReadingBook():
return $default(_that.bookId,_that.title,_that.thumbnail,_that.volumeNumber,_that.volumeId,_that.currentPage,_that.maxPage,_that.progressPercent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'book_id')  int bookId,  String title,  String? thumbnail, @JsonKey(name: 'volume_number')  int volumeNumber, @JsonKey(name: 'volume_id')  int volumeId, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'progress_percent')  int progressPercent)?  $default,) {final _that = this;
switch (_that) {
case _ReadingBook() when $default != null:
return $default(_that.bookId,_that.title,_that.thumbnail,_that.volumeNumber,_that.volumeId,_that.currentPage,_that.maxPage,_that.progressPercent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReadingBook implements ReadingBook {
  const _ReadingBook({@JsonKey(name: 'book_id') required this.bookId, this.title = '', this.thumbnail, @JsonKey(name: 'volume_number') this.volumeNumber = 0, @JsonKey(name: 'volume_id') required this.volumeId, @JsonKey(name: 'current_page') this.currentPage = 0, @JsonKey(name: 'max_page') this.maxPage = 0, @JsonKey(name: 'progress_percent') this.progressPercent = 0});
  factory _ReadingBook.fromJson(Map<String, dynamic> json) => _$ReadingBookFromJson(json);

@override@JsonKey(name: 'book_id') final  int bookId;
@override@JsonKey() final  String title;
/// `?m=` 付きの相対 URL。`null` はサムネイル無し。
@override final  String? thumbnail;
@override@JsonKey(name: 'volume_number') final  int volumeNumber;
@override@JsonKey(name: 'volume_id') final  int volumeId;
@override@JsonKey(name: 'current_page') final  int currentPage;
@override@JsonKey(name: 'max_page') final  int maxPage;
/// サーバーが計算した進捗率（0-100）。
@override@JsonKey(name: 'progress_percent') final  int progressPercent;

/// Create a copy of ReadingBook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingBookCopyWith<_ReadingBook> get copyWith => __$ReadingBookCopyWithImpl<_ReadingBook>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReadingBookToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingBook&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.title, title) || other.title == title)&&(identical(other.thumbnail, thumbnail) || other.thumbnail == thumbnail)&&(identical(other.volumeNumber, volumeNumber) || other.volumeNumber == volumeNumber)&&(identical(other.volumeId, volumeId) || other.volumeId == volumeId)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.maxPage, maxPage) || other.maxPage == maxPage)&&(identical(other.progressPercent, progressPercent) || other.progressPercent == progressPercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bookId,title,thumbnail,volumeNumber,volumeId,currentPage,maxPage,progressPercent);
}

@override
String toString() {
    return 'ReadingBook(bookId: $bookId, title: $title, thumbnail: $thumbnail, volumeNumber: $volumeNumber, volumeId: $volumeId, currentPage: $currentPage, maxPage: $maxPage, progressPercent: $progressPercent)';
}


}

/// @nodoc
abstract mixin class _$ReadingBookCopyWith<$Res> implements $ReadingBookCopyWith<$Res> {
  factory _$ReadingBookCopyWith(_ReadingBook value, $Res Function(_ReadingBook) _then) = __$ReadingBookCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'book_id') int bookId, String title, String? thumbnail,@JsonKey(name: 'volume_number') int volumeNumber,@JsonKey(name: 'volume_id') int volumeId,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'progress_percent') int progressPercent
});




}
/// @nodoc
class __$ReadingBookCopyWithImpl<$Res>
    implements _$ReadingBookCopyWith<$Res> {
  __$ReadingBookCopyWithImpl(this._self, this._then);

  final _ReadingBook _self;
  final $Res Function(_ReadingBook) _then;

/// Create a copy of ReadingBook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookId = null,Object? title = null,Object? thumbnail = freezed,Object? volumeNumber = null,Object? volumeId = null,Object? currentPage = null,Object? maxPage = null,Object? progressPercent = null,}) {
  return _then(_ReadingBook(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,volumeNumber: null == volumeNumber ? _self.volumeNumber : volumeNumber // ignore: cast_nullable_to_non_nullable
as int,volumeId: null == volumeId ? _self.volumeId : volumeId // ignore: cast_nullable_to_non_nullable
as int,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,progressPercent: null == progressPercent ? _self.progressPercent : progressPercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$HistoryEntry {

/// 巻 ID。
 int get id;@JsonKey(name: 'book_id') int get bookId; String get title; int get volume; String? get thumbnail;@JsonKey(name: 'current_page') int get currentPage;@JsonKey(name: 'max_page') int get maxPage;@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool get isFinished;@JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? get updatedAt;
/// Create a copy of HistoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HistoryEntryCopyWith<HistoryEntry> get copyWith => _$HistoryEntryCopyWithImpl<HistoryEntry>(this as HistoryEntry, _$identity);

  /// Serializes this HistoryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HistoryEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryEntry&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.bookId, _this.bookId) || other.bookId == _this.bookId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.volume, _this.volume) || other.volume == _this.volume)&&(identical(other.thumbnail, _this.thumbnail) || other.thumbnail == _this.thumbnail)&&(identical(other.currentPage, _this.currentPage) || other.currentPage == _this.currentPage)&&(identical(other.maxPage, _this.maxPage) || other.maxPage == _this.maxPage)&&(identical(other.isFinished, _this.isFinished) || other.isFinished == _this.isFinished)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HistoryEntry;
  return Object.hash(runtimeType,_this.id,_this.bookId,_this.title,_this.volume,_this.thumbnail,_this.currentPage,_this.maxPage,_this.isFinished,_this.updatedAt);
}

@override
String toString() {
  final _this = this as HistoryEntry;
  return 'HistoryEntry(id: ${_this.id}, bookId: ${_this.bookId}, title: ${_this.title}, volume: ${_this.volume}, thumbnail: ${_this.thumbnail}, currentPage: ${_this.currentPage}, maxPage: ${_this.maxPage}, isFinished: ${_this.isFinished}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $HistoryEntryCopyWith<$Res>  {
  factory $HistoryEntryCopyWith(HistoryEntry value, $Res Function(HistoryEntry) _then) = _$HistoryEntryCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'book_id') int bookId, String title, int volume, String? thumbnail,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool isFinished,@JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? updatedAt
});




}
/// @nodoc
class _$HistoryEntryCopyWithImpl<$Res>
    implements $HistoryEntryCopyWith<$Res> {
  _$HistoryEntryCopyWithImpl(this._self, this._then);

  final HistoryEntry _self;
  final $Res Function(HistoryEntry) _then;

/// Create a copy of HistoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookId = null,Object? title = null,Object? volume = null,Object? thumbnail = freezed,Object? currentPage = null,Object? maxPage = null,Object? isFinished = null,Object? updatedAt = freezed,}) {
  return _then(HistoryEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,isFinished: null == isFinished ? _self.isFinished : isFinished // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [HistoryEntry].
extension HistoryEntryPatterns on HistoryEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HistoryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HistoryEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HistoryEntry value)  $default,){
final _that = this;
switch (_that) {
case _HistoryEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HistoryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _HistoryEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'book_id')  int bookId,  String title,  int volume,  String? thumbnail, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished, @JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HistoryEntry() when $default != null:
return $default(_that.id,_that.bookId,_that.title,_that.volume,_that.thumbnail,_that.currentPage,_that.maxPage,_that.isFinished,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'book_id')  int bookId,  String title,  int volume,  String? thumbnail, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished, @JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _HistoryEntry():
return $default(_that.id,_that.bookId,_that.title,_that.volume,_that.thumbnail,_that.currentPage,_that.maxPage,_that.isFinished,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'book_id')  int bookId,  String title,  int volume,  String? thumbnail, @JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'max_page')  int maxPage, @JsonKey(name: 'is_finished', fromJson: boolFromJson)  bool isFinished, @JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _HistoryEntry() when $default != null:
return $default(_that.id,_that.bookId,_that.title,_that.volume,_that.thumbnail,_that.currentPage,_that.maxPage,_that.isFinished,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HistoryEntry implements HistoryEntry {
  const _HistoryEntry({required this.id, @JsonKey(name: 'book_id') required this.bookId, this.title = '', this.volume = 0, this.thumbnail, @JsonKey(name: 'current_page') this.currentPage = 0, @JsonKey(name: 'max_page') this.maxPage = 0, @JsonKey(name: 'is_finished', fromJson: boolFromJson) this.isFinished = false, @JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) this.updatedAt});
  factory _HistoryEntry.fromJson(Map<String, dynamic> json) => _$HistoryEntryFromJson(json);

/// 巻 ID。
@override final  int id;
@override@JsonKey(name: 'book_id') final  int bookId;
@override@JsonKey() final  String title;
@override@JsonKey() final  int volume;
@override final  String? thumbnail;
@override@JsonKey(name: 'current_page') final  int currentPage;
@override@JsonKey(name: 'max_page') final  int maxPage;
@override@JsonKey(name: 'is_finished', fromJson: boolFromJson) final  bool isFinished;
@override@JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) final  DateTime? updatedAt;

/// Create a copy of HistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HistoryEntryCopyWith<_HistoryEntry> get copyWith => __$HistoryEntryCopyWithImpl<_HistoryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HistoryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.title, title) || other.title == title)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.thumbnail, thumbnail) || other.thumbnail == thumbnail)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.maxPage, maxPage) || other.maxPage == maxPage)&&(identical(other.isFinished, isFinished) || other.isFinished == isFinished)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,bookId,title,volume,thumbnail,currentPage,maxPage,isFinished,updatedAt);
}

@override
String toString() {
    return 'HistoryEntry(id: $id, bookId: $bookId, title: $title, volume: $volume, thumbnail: $thumbnail, currentPage: $currentPage, maxPage: $maxPage, isFinished: $isFinished, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$HistoryEntryCopyWith<$Res> implements $HistoryEntryCopyWith<$Res> {
  factory _$HistoryEntryCopyWith(_HistoryEntry value, $Res Function(_HistoryEntry) _then) = __$HistoryEntryCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'book_id') int bookId, String title, int volume, String? thumbnail,@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'max_page') int maxPage,@JsonKey(name: 'is_finished', fromJson: boolFromJson) bool isFinished,@JsonKey(name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? updatedAt
});




}
/// @nodoc
class __$HistoryEntryCopyWithImpl<$Res>
    implements _$HistoryEntryCopyWith<$Res> {
  __$HistoryEntryCopyWithImpl(this._self, this._then);

  final _HistoryEntry _self;
  final $Res Function(_HistoryEntry) _then;

/// Create a copy of HistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookId = null,Object? title = null,Object? volume = null,Object? thumbnail = freezed,Object? currentPage = null,Object? maxPage = null,Object? isFinished = null,Object? updatedAt = freezed,}) {
  return _then(_HistoryEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as String?,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,maxPage: null == maxPage ? _self.maxPage : maxPage // ignore: cast_nullable_to_non_nullable
as int,isFinished: null == isFinished ? _self.isFinished : isFinished // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$UserStats {

@JsonKey(name: 'titles_completed') int get titlesCompleted;@JsonKey(name: 'volumes_completed') int get volumesCompleted;/// 直近 12 か月の読了数（古い月から順）。
 List<MonthlyReadCount> get monthly;
/// Create a copy of UserStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserStatsCopyWith<UserStats> get copyWith => _$UserStatsCopyWithImpl<UserStats>(this as UserStats, _$identity);

  /// Serializes this UserStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserStats;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserStats&&(identical(other.titlesCompleted, _this.titlesCompleted) || other.titlesCompleted == _this.titlesCompleted)&&(identical(other.volumesCompleted, _this.volumesCompleted) || other.volumesCompleted == _this.volumesCompleted)&&const DeepCollectionEquality().equals(other.monthly, _this.monthly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserStats;
  return Object.hash(runtimeType,_this.titlesCompleted,_this.volumesCompleted,const DeepCollectionEquality().hash(_this.monthly));
}

@override
String toString() {
  final _this = this as UserStats;
  return 'UserStats(titlesCompleted: ${_this.titlesCompleted}, volumesCompleted: ${_this.volumesCompleted}, monthly: ${_this.monthly})';
}


}

/// @nodoc
abstract mixin class $UserStatsCopyWith<$Res>  {
  factory $UserStatsCopyWith(UserStats value, $Res Function(UserStats) _then) = _$UserStatsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'titles_completed') int titlesCompleted,@JsonKey(name: 'volumes_completed') int volumesCompleted, List<MonthlyReadCount> monthly
});




}
/// @nodoc
class _$UserStatsCopyWithImpl<$Res>
    implements $UserStatsCopyWith<$Res> {
  _$UserStatsCopyWithImpl(this._self, this._then);

  final UserStats _self;
  final $Res Function(UserStats) _then;

/// Create a copy of UserStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? titlesCompleted = null,Object? volumesCompleted = null,Object? monthly = null,}) {
  return _then(UserStats(
titlesCompleted: null == titlesCompleted ? _self.titlesCompleted : titlesCompleted // ignore: cast_nullable_to_non_nullable
as int,volumesCompleted: null == volumesCompleted ? _self.volumesCompleted : volumesCompleted // ignore: cast_nullable_to_non_nullable
as int,monthly: null == monthly ? _self.monthly : monthly // ignore: cast_nullable_to_non_nullable
as List<MonthlyReadCount>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserStats].
extension UserStatsPatterns on UserStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserStats value)  $default,){
final _that = this;
switch (_that) {
case _UserStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserStats value)?  $default,){
final _that = this;
switch (_that) {
case _UserStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'titles_completed')  int titlesCompleted, @JsonKey(name: 'volumes_completed')  int volumesCompleted,  List<MonthlyReadCount> monthly)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserStats() when $default != null:
return $default(_that.titlesCompleted,_that.volumesCompleted,_that.monthly);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'titles_completed')  int titlesCompleted, @JsonKey(name: 'volumes_completed')  int volumesCompleted,  List<MonthlyReadCount> monthly)  $default,) {final _that = this;
switch (_that) {
case _UserStats():
return $default(_that.titlesCompleted,_that.volumesCompleted,_that.monthly);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'titles_completed')  int titlesCompleted, @JsonKey(name: 'volumes_completed')  int volumesCompleted,  List<MonthlyReadCount> monthly)?  $default,) {final _that = this;
switch (_that) {
case _UserStats() when $default != null:
return $default(_that.titlesCompleted,_that.volumesCompleted,_that.monthly);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserStats implements UserStats {
  const _UserStats({@JsonKey(name: 'titles_completed') this.titlesCompleted = 0, @JsonKey(name: 'volumes_completed') this.volumesCompleted = 0,  List<MonthlyReadCount> monthly = const []}): _monthly = monthly;
  factory _UserStats.fromJson(Map<String, dynamic> json) => _$UserStatsFromJson(json);

@override@JsonKey(name: 'titles_completed') final  int titlesCompleted;
@override@JsonKey(name: 'volumes_completed') final  int volumesCompleted;
/// 直近 12 か月の読了数（古い月から順）。
 final  List<MonthlyReadCount> _monthly;
/// 直近 12 か月の読了数（古い月から順）。
@override@JsonKey() List<MonthlyReadCount> get monthly {
  if (_monthly is EqualUnmodifiableListView) return _monthly;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_monthly);
}


/// Create a copy of UserStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserStatsCopyWith<_UserStats> get copyWith => __$UserStatsCopyWithImpl<_UserStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserStatsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserStats&&(identical(other.titlesCompleted, titlesCompleted) || other.titlesCompleted == titlesCompleted)&&(identical(other.volumesCompleted, volumesCompleted) || other.volumesCompleted == volumesCompleted)&&const DeepCollectionEquality().equals(other.monthly, _monthly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,titlesCompleted,volumesCompleted,const DeepCollectionEquality().hash(_monthly));
}

@override
String toString() {
    return 'UserStats(titlesCompleted: $titlesCompleted, volumesCompleted: $volumesCompleted, monthly: $monthly)';
}


}

/// @nodoc
abstract mixin class _$UserStatsCopyWith<$Res> implements $UserStatsCopyWith<$Res> {
  factory _$UserStatsCopyWith(_UserStats value, $Res Function(_UserStats) _then) = __$UserStatsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'titles_completed') int titlesCompleted,@JsonKey(name: 'volumes_completed') int volumesCompleted, List<MonthlyReadCount> monthly
});




}
/// @nodoc
class __$UserStatsCopyWithImpl<$Res>
    implements _$UserStatsCopyWith<$Res> {
  __$UserStatsCopyWithImpl(this._self, this._then);

  final _UserStats _self;
  final $Res Function(_UserStats) _then;

/// Create a copy of UserStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? titlesCompleted = null,Object? volumesCompleted = null,Object? monthly = null,}) {
  return _then(_UserStats(
titlesCompleted: null == titlesCompleted ? _self.titlesCompleted : titlesCompleted // ignore: cast_nullable_to_non_nullable
as int,volumesCompleted: null == volumesCompleted ? _self.volumesCompleted : volumesCompleted // ignore: cast_nullable_to_non_nullable
as int,monthly: null == monthly ? _self._monthly : monthly // ignore: cast_nullable_to_non_nullable
as List<MonthlyReadCount>,
  ));
}


}


/// @nodoc
mixin _$MonthlyReadCount {

/// `YYYY-MM`。
 String get month; int get count;
/// Create a copy of MonthlyReadCount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonthlyReadCountCopyWith<MonthlyReadCount> get copyWith => _$MonthlyReadCountCopyWithImpl<MonthlyReadCount>(this as MonthlyReadCount, _$identity);

  /// Serializes this MonthlyReadCount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MonthlyReadCount;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MonthlyReadCount&&(identical(other.month, _this.month) || other.month == _this.month)&&(identical(other.count, _this.count) || other.count == _this.count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MonthlyReadCount;
  return Object.hash(runtimeType,_this.month,_this.count);
}

@override
String toString() {
  final _this = this as MonthlyReadCount;
  return 'MonthlyReadCount(month: ${_this.month}, count: ${_this.count})';
}


}

/// @nodoc
abstract mixin class $MonthlyReadCountCopyWith<$Res>  {
  factory $MonthlyReadCountCopyWith(MonthlyReadCount value, $Res Function(MonthlyReadCount) _then) = _$MonthlyReadCountCopyWithImpl;
@useResult
$Res call({
 String month, int count
});




}
/// @nodoc
class _$MonthlyReadCountCopyWithImpl<$Res>
    implements $MonthlyReadCountCopyWith<$Res> {
  _$MonthlyReadCountCopyWithImpl(this._self, this._then);

  final MonthlyReadCount _self;
  final $Res Function(MonthlyReadCount) _then;

/// Create a copy of MonthlyReadCount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? month = null,Object? count = null,}) {
  return _then(MonthlyReadCount(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MonthlyReadCount].
extension MonthlyReadCountPatterns on MonthlyReadCount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MonthlyReadCount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MonthlyReadCount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MonthlyReadCount value)  $default,){
final _that = this;
switch (_that) {
case _MonthlyReadCount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MonthlyReadCount value)?  $default,){
final _that = this;
switch (_that) {
case _MonthlyReadCount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String month,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MonthlyReadCount() when $default != null:
return $default(_that.month,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String month,  int count)  $default,) {final _that = this;
switch (_that) {
case _MonthlyReadCount():
return $default(_that.month,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String month,  int count)?  $default,) {final _that = this;
switch (_that) {
case _MonthlyReadCount() when $default != null:
return $default(_that.month,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MonthlyReadCount implements MonthlyReadCount {
  const _MonthlyReadCount({this.month = '', this.count = 0});
  factory _MonthlyReadCount.fromJson(Map<String, dynamic> json) => _$MonthlyReadCountFromJson(json);

/// `YYYY-MM`。
@override@JsonKey() final  String month;
@override@JsonKey() final  int count;

/// Create a copy of MonthlyReadCount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MonthlyReadCountCopyWith<_MonthlyReadCount> get copyWith => __$MonthlyReadCountCopyWithImpl<_MonthlyReadCount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MonthlyReadCountToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MonthlyReadCount&&(identical(other.month, month) || other.month == month)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,month,count);
}

@override
String toString() {
    return 'MonthlyReadCount(month: $month, count: $count)';
}


}

/// @nodoc
abstract mixin class _$MonthlyReadCountCopyWith<$Res> implements $MonthlyReadCountCopyWith<$Res> {
  factory _$MonthlyReadCountCopyWith(_MonthlyReadCount value, $Res Function(_MonthlyReadCount) _then) = __$MonthlyReadCountCopyWithImpl;
@override @useResult
$Res call({
 String month, int count
});




}
/// @nodoc
class __$MonthlyReadCountCopyWithImpl<$Res>
    implements _$MonthlyReadCountCopyWith<$Res> {
  __$MonthlyReadCountCopyWithImpl(this._self, this._then);

  final _MonthlyReadCount _self;
  final $Res Function(_MonthlyReadCount) _then;

/// Create a copy of MonthlyReadCount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? month = null,Object? count = null,}) {
  return _then(_MonthlyReadCount(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Taxonomy {

 int get id; String get name;
/// Create a copy of Taxonomy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxonomyCopyWith<Taxonomy> get copyWith => _$TaxonomyCopyWithImpl<Taxonomy>(this as Taxonomy, _$identity);

  /// Serializes this Taxonomy to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Taxonomy;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Taxonomy&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Taxonomy;
  return Object.hash(runtimeType,_this.id,_this.name);
}

@override
String toString() {
  final _this = this as Taxonomy;
  return 'Taxonomy(id: ${_this.id}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $TaxonomyCopyWith<$Res>  {
  factory $TaxonomyCopyWith(Taxonomy value, $Res Function(Taxonomy) _then) = _$TaxonomyCopyWithImpl;
@useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class _$TaxonomyCopyWithImpl<$Res>
    implements $TaxonomyCopyWith<$Res> {
  _$TaxonomyCopyWithImpl(this._self, this._then);

  final Taxonomy _self;
  final $Res Function(Taxonomy) _then;

/// Create a copy of Taxonomy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(Taxonomy(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Taxonomy].
extension TaxonomyPatterns on Taxonomy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Taxonomy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Taxonomy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Taxonomy value)  $default,){
final _that = this;
switch (_that) {
case _Taxonomy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Taxonomy value)?  $default,){
final _that = this;
switch (_that) {
case _Taxonomy() when $default != null:
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
case _Taxonomy() when $default != null:
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
case _Taxonomy():
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
case _Taxonomy() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Taxonomy implements Taxonomy {
  const _Taxonomy({required this.id, this.name = ''});
  factory _Taxonomy.fromJson(Map<String, dynamic> json) => _$TaxonomyFromJson(json);

@override final  int id;
@override@JsonKey() final  String name;

/// Create a copy of Taxonomy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxonomyCopyWith<_Taxonomy> get copyWith => __$TaxonomyCopyWithImpl<_Taxonomy>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaxonomyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Taxonomy&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name);
}

@override
String toString() {
    return 'Taxonomy(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$TaxonomyCopyWith<$Res> implements $TaxonomyCopyWith<$Res> {
  factory _$TaxonomyCopyWith(_Taxonomy value, $Res Function(_Taxonomy) _then) = __$TaxonomyCopyWithImpl;
@override @useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class __$TaxonomyCopyWithImpl<$Res>
    implements _$TaxonomyCopyWith<$Res> {
  __$TaxonomyCopyWithImpl(this._self, this._then);

  final _Taxonomy _self;
  final $Res Function(_Taxonomy) _then;

/// Create a copy of Taxonomy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_Taxonomy(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
