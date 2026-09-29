// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LibraryFilter {

 String get query; Set<int> get categoryIds; Set<int> get tagIds; bool get onlyFavorites; bool get onlyUnread; bool get onlyComplete;/// ダウンロード済みのみ表示。
///
/// `null` は**未指定**で、オフライン（サーバーに確認できない）なら ON として
/// 扱う（#11）。「既定 ON」を状態として書き込まないのは、圏外で開いたあとに
/// オンラインへ戻ったときに、ユーザーが触っていない絞り込みが残って
/// 「本が減った」ように見えるのを避けるため。
 bool? get onlyDownloaded; LibrarySort get sort;
/// Create a copy of LibraryFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryFilterCopyWith<LibraryFilter> get copyWith => _$LibraryFilterCopyWithImpl<LibraryFilter>(this as LibraryFilter, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LibraryFilter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryFilter&&(identical(other.query, _this.query) || other.query == _this.query)&&const DeepCollectionEquality().equals(other.categoryIds, _this.categoryIds)&&const DeepCollectionEquality().equals(other.tagIds, _this.tagIds)&&(identical(other.onlyFavorites, _this.onlyFavorites) || other.onlyFavorites == _this.onlyFavorites)&&(identical(other.onlyUnread, _this.onlyUnread) || other.onlyUnread == _this.onlyUnread)&&(identical(other.onlyComplete, _this.onlyComplete) || other.onlyComplete == _this.onlyComplete)&&(identical(other.onlyDownloaded, _this.onlyDownloaded) || other.onlyDownloaded == _this.onlyDownloaded)&&(identical(other.sort, _this.sort) || other.sort == _this.sort));
}


@override
int get hashCode {
  final _this = this as LibraryFilter;
  return Object.hash(runtimeType,_this.query,const DeepCollectionEquality().hash(_this.categoryIds),const DeepCollectionEquality().hash(_this.tagIds),_this.onlyFavorites,_this.onlyUnread,_this.onlyComplete,_this.onlyDownloaded,_this.sort);
}

@override
String toString() {
  final _this = this as LibraryFilter;
  return 'LibraryFilter(query: ${_this.query}, categoryIds: ${_this.categoryIds}, tagIds: ${_this.tagIds}, onlyFavorites: ${_this.onlyFavorites}, onlyUnread: ${_this.onlyUnread}, onlyComplete: ${_this.onlyComplete}, onlyDownloaded: ${_this.onlyDownloaded}, sort: ${_this.sort})';
}


}

/// @nodoc
abstract mixin class $LibraryFilterCopyWith<$Res>  {
  factory $LibraryFilterCopyWith(LibraryFilter value, $Res Function(LibraryFilter) _then) = _$LibraryFilterCopyWithImpl;
@useResult
$Res call({
 String query, Set<int> categoryIds, Set<int> tagIds, bool onlyFavorites, bool onlyUnread, bool onlyComplete, bool? onlyDownloaded, LibrarySort sort
});




}
/// @nodoc
class _$LibraryFilterCopyWithImpl<$Res>
    implements $LibraryFilterCopyWith<$Res> {
  _$LibraryFilterCopyWithImpl(this._self, this._then);

  final LibraryFilter _self;
  final $Res Function(LibraryFilter) _then;

/// Create a copy of LibraryFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? query = null,Object? categoryIds = null,Object? tagIds = null,Object? onlyFavorites = null,Object? onlyUnread = null,Object? onlyComplete = null,Object? onlyDownloaded = freezed,Object? sort = null,}) {
  return _then(LibraryFilter(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,categoryIds: null == categoryIds ? _self.categoryIds : categoryIds // ignore: cast_nullable_to_non_nullable
as Set<int>,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as Set<int>,onlyFavorites: null == onlyFavorites ? _self.onlyFavorites : onlyFavorites // ignore: cast_nullable_to_non_nullable
as bool,onlyUnread: null == onlyUnread ? _self.onlyUnread : onlyUnread // ignore: cast_nullable_to_non_nullable
as bool,onlyComplete: null == onlyComplete ? _self.onlyComplete : onlyComplete // ignore: cast_nullable_to_non_nullable
as bool,onlyDownloaded: freezed == onlyDownloaded ? _self.onlyDownloaded : onlyDownloaded // ignore: cast_nullable_to_non_nullable
as bool?,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as LibrarySort,
  ));
}

}


/// Adds pattern-matching-related methods to [LibraryFilter].
extension LibraryFilterPatterns on LibraryFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryFilter value)  $default,){
final _that = this;
switch (_that) {
case _LibraryFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryFilter value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryFilter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String query,  Set<int> categoryIds,  Set<int> tagIds,  bool onlyFavorites,  bool onlyUnread,  bool onlyComplete,  bool? onlyDownloaded,  LibrarySort sort)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryFilter() when $default != null:
return $default(_that.query,_that.categoryIds,_that.tagIds,_that.onlyFavorites,_that.onlyUnread,_that.onlyComplete,_that.onlyDownloaded,_that.sort);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String query,  Set<int> categoryIds,  Set<int> tagIds,  bool onlyFavorites,  bool onlyUnread,  bool onlyComplete,  bool? onlyDownloaded,  LibrarySort sort)  $default,) {final _that = this;
switch (_that) {
case _LibraryFilter():
return $default(_that.query,_that.categoryIds,_that.tagIds,_that.onlyFavorites,_that.onlyUnread,_that.onlyComplete,_that.onlyDownloaded,_that.sort);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String query,  Set<int> categoryIds,  Set<int> tagIds,  bool onlyFavorites,  bool onlyUnread,  bool onlyComplete,  bool? onlyDownloaded,  LibrarySort sort)?  $default,) {final _that = this;
switch (_that) {
case _LibraryFilter() when $default != null:
return $default(_that.query,_that.categoryIds,_that.tagIds,_that.onlyFavorites,_that.onlyUnread,_that.onlyComplete,_that.onlyDownloaded,_that.sort);case _:
  return null;

}
}

}

/// @nodoc


class _LibraryFilter extends LibraryFilter {
  const _LibraryFilter({this.query = '',  Set<int> categoryIds = const {},  Set<int> tagIds = const {}, this.onlyFavorites = false, this.onlyUnread = false, this.onlyComplete = false, this.onlyDownloaded, this.sort = LibrarySort.updated}): _categoryIds = categoryIds,_tagIds = tagIds,super._();
  

@override@JsonKey() final  String query;
 final  Set<int> _categoryIds;
@override@JsonKey() Set<int> get categoryIds {
  if (_categoryIds is EqualUnmodifiableSetView) return _categoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_categoryIds);
}

 final  Set<int> _tagIds;
@override@JsonKey() Set<int> get tagIds {
  if (_tagIds is EqualUnmodifiableSetView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_tagIds);
}

@override@JsonKey() final  bool onlyFavorites;
@override@JsonKey() final  bool onlyUnread;
@override@JsonKey() final  bool onlyComplete;
/// ダウンロード済みのみ表示。
///
/// `null` は**未指定**で、オフライン（サーバーに確認できない）なら ON として
/// 扱う（#11）。「既定 ON」を状態として書き込まないのは、圏外で開いたあとに
/// オンラインへ戻ったときに、ユーザーが触っていない絞り込みが残って
/// 「本が減った」ように見えるのを避けるため。
@override final  bool? onlyDownloaded;
@override@JsonKey() final  LibrarySort sort;

/// Create a copy of LibraryFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryFilterCopyWith<_LibraryFilter> get copyWith => __$LibraryFilterCopyWithImpl<_LibraryFilter>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryFilter&&(identical(other.query, query) || other.query == query)&&const DeepCollectionEquality().equals(other.categoryIds, _categoryIds)&&const DeepCollectionEquality().equals(other.tagIds, _tagIds)&&(identical(other.onlyFavorites, onlyFavorites) || other.onlyFavorites == onlyFavorites)&&(identical(other.onlyUnread, onlyUnread) || other.onlyUnread == onlyUnread)&&(identical(other.onlyComplete, onlyComplete) || other.onlyComplete == onlyComplete)&&(identical(other.onlyDownloaded, onlyDownloaded) || other.onlyDownloaded == onlyDownloaded)&&(identical(other.sort, sort) || other.sort == sort));
}


@override
int get hashCode {
    return Object.hash(runtimeType,query,const DeepCollectionEquality().hash(_categoryIds),const DeepCollectionEquality().hash(_tagIds),onlyFavorites,onlyUnread,onlyComplete,onlyDownloaded,sort);
}

@override
String toString() {
    return 'LibraryFilter(query: $query, categoryIds: $categoryIds, tagIds: $tagIds, onlyFavorites: $onlyFavorites, onlyUnread: $onlyUnread, onlyComplete: $onlyComplete, onlyDownloaded: $onlyDownloaded, sort: $sort)';
}


}

/// @nodoc
abstract mixin class _$LibraryFilterCopyWith<$Res> implements $LibraryFilterCopyWith<$Res> {
  factory _$LibraryFilterCopyWith(_LibraryFilter value, $Res Function(_LibraryFilter) _then) = __$LibraryFilterCopyWithImpl;
@override @useResult
$Res call({
 String query, Set<int> categoryIds, Set<int> tagIds, bool onlyFavorites, bool onlyUnread, bool onlyComplete, bool? onlyDownloaded, LibrarySort sort
});




}
/// @nodoc
class __$LibraryFilterCopyWithImpl<$Res>
    implements _$LibraryFilterCopyWith<$Res> {
  __$LibraryFilterCopyWithImpl(this._self, this._then);

  final _LibraryFilter _self;
  final $Res Function(_LibraryFilter) _then;

/// Create a copy of LibraryFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? query = null,Object? categoryIds = null,Object? tagIds = null,Object? onlyFavorites = null,Object? onlyUnread = null,Object? onlyComplete = null,Object? onlyDownloaded = freezed,Object? sort = null,}) {
  return _then(_LibraryFilter(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,categoryIds: null == categoryIds ? _self._categoryIds : categoryIds // ignore: cast_nullable_to_non_nullable
as Set<int>,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as Set<int>,onlyFavorites: null == onlyFavorites ? _self.onlyFavorites : onlyFavorites // ignore: cast_nullable_to_non_nullable
as bool,onlyUnread: null == onlyUnread ? _self.onlyUnread : onlyUnread // ignore: cast_nullable_to_non_nullable
as bool,onlyComplete: null == onlyComplete ? _self.onlyComplete : onlyComplete // ignore: cast_nullable_to_non_nullable
as bool,onlyDownloaded: freezed == onlyDownloaded ? _self.onlyDownloaded : onlyDownloaded // ignore: cast_nullable_to_non_nullable
as bool?,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as LibrarySort,
  ));
}


}

// dart format on
