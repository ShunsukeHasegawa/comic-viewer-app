// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_detail_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookDetailData {

 BookDetail get detail;/// サーバーに確認できず、端末に控えてある内容を表示している（#11）。
///
/// この間は未ダウンロードの巻を開けないので、画面側は無効表示にする。
 bool get isStale;
/// Create a copy of BookDetailData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookDetailDataCopyWith<BookDetailData> get copyWith => _$BookDetailDataCopyWithImpl<BookDetailData>(this as BookDetailData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookDetailData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookDetailData&&(identical(other.detail, _this.detail) || other.detail == _this.detail)&&(identical(other.isStale, _this.isStale) || other.isStale == _this.isStale));
}


@override
int get hashCode {
  final _this = this as BookDetailData;
  return Object.hash(runtimeType,_this.detail,_this.isStale);
}

@override
String toString() {
  final _this = this as BookDetailData;
  return 'BookDetailData(detail: ${_this.detail}, isStale: ${_this.isStale})';
}


}

/// @nodoc
abstract mixin class $BookDetailDataCopyWith<$Res>  {
  factory $BookDetailDataCopyWith(BookDetailData value, $Res Function(BookDetailData) _then) = _$BookDetailDataCopyWithImpl;
@useResult
$Res call({
 BookDetail detail, bool isStale
});


$BookDetailCopyWith<$Res> get detail;

}
/// @nodoc
class _$BookDetailDataCopyWithImpl<$Res>
    implements $BookDetailDataCopyWith<$Res> {
  _$BookDetailDataCopyWithImpl(this._self, this._then);

  final BookDetailData _self;
  final $Res Function(BookDetailData) _then;

/// Create a copy of BookDetailData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? detail = null,Object? isStale = null,}) {
  return _then(BookDetailData(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as BookDetail,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of BookDetailData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookDetailCopyWith<$Res> get detail {
  
  return $BookDetailCopyWith<$Res>(_self.detail, (value) {
    return _then(_self.copyWith(detail: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookDetailData].
extension BookDetailDataPatterns on BookDetailData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookDetailData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookDetailData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookDetailData value)  $default,){
final _that = this;
switch (_that) {
case _BookDetailData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookDetailData value)?  $default,){
final _that = this;
switch (_that) {
case _BookDetailData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BookDetail detail,  bool isStale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookDetailData() when $default != null:
return $default(_that.detail,_that.isStale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BookDetail detail,  bool isStale)  $default,) {final _that = this;
switch (_that) {
case _BookDetailData():
return $default(_that.detail,_that.isStale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BookDetail detail,  bool isStale)?  $default,) {final _that = this;
switch (_that) {
case _BookDetailData() when $default != null:
return $default(_that.detail,_that.isStale);case _:
  return null;

}
}

}

/// @nodoc


class _BookDetailData implements BookDetailData {
  const _BookDetailData({required this.detail, this.isStale = false});
  

@override final  BookDetail detail;
/// サーバーに確認できず、端末に控えてある内容を表示している（#11）。
///
/// この間は未ダウンロードの巻を開けないので、画面側は無効表示にする。
@override@JsonKey() final  bool isStale;

/// Create a copy of BookDetailData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookDetailDataCopyWith<_BookDetailData> get copyWith => __$BookDetailDataCopyWithImpl<_BookDetailData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookDetailData&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.isStale, isStale) || other.isStale == isStale));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail,isStale);
}

@override
String toString() {
    return 'BookDetailData(detail: $detail, isStale: $isStale)';
}


}

/// @nodoc
abstract mixin class _$BookDetailDataCopyWith<$Res> implements $BookDetailDataCopyWith<$Res> {
  factory _$BookDetailDataCopyWith(_BookDetailData value, $Res Function(_BookDetailData) _then) = __$BookDetailDataCopyWithImpl;
@override @useResult
$Res call({
 BookDetail detail, bool isStale
});


@override $BookDetailCopyWith<$Res> get detail;

}
/// @nodoc
class __$BookDetailDataCopyWithImpl<$Res>
    implements _$BookDetailDataCopyWith<$Res> {
  __$BookDetailDataCopyWithImpl(this._self, this._then);

  final _BookDetailData _self;
  final $Res Function(_BookDetailData) _then;

/// Create a copy of BookDetailData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detail = null,Object? isStale = null,}) {
  return _then(_BookDetailData(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as BookDetail,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of BookDetailData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookDetailCopyWith<$Res> get detail {
  
  return $BookDetailCopyWith<$Res>(_self.detail, (value) {
    return _then(_self.copyWith(detail: value));
  });
}
}

// dart format on
