// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'viewer_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ViewerState {

 ReadVolume get volume;/// 表示中のページ（1 始まり）。`volume.files.length + 1` は巻末オーバーレイ。
 int get currentPage;/// ヘッダ / シークバーを表示しているか。
 bool get isMenuVisible;/// サーバーに確認できず、端末の控えで開いている（#11）。
///
/// この間に次巻へ進めるのは、次巻もダウンロード済みのときだけ。
 bool get isStale;
/// Create a copy of ViewerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ViewerStateCopyWith<ViewerState> get copyWith => _$ViewerStateCopyWithImpl<ViewerState>(this as ViewerState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ViewerState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ViewerState&&(identical(other.volume, _this.volume) || other.volume == _this.volume)&&(identical(other.currentPage, _this.currentPage) || other.currentPage == _this.currentPage)&&(identical(other.isMenuVisible, _this.isMenuVisible) || other.isMenuVisible == _this.isMenuVisible)&&(identical(other.isStale, _this.isStale) || other.isStale == _this.isStale));
}


@override
int get hashCode {
  final _this = this as ViewerState;
  return Object.hash(runtimeType,_this.volume,_this.currentPage,_this.isMenuVisible,_this.isStale);
}

@override
String toString() {
  final _this = this as ViewerState;
  return 'ViewerState(volume: ${_this.volume}, currentPage: ${_this.currentPage}, isMenuVisible: ${_this.isMenuVisible}, isStale: ${_this.isStale})';
}


}

/// @nodoc
abstract mixin class $ViewerStateCopyWith<$Res>  {
  factory $ViewerStateCopyWith(ViewerState value, $Res Function(ViewerState) _then) = _$ViewerStateCopyWithImpl;
@useResult
$Res call({
 ReadVolume volume, int currentPage, bool isMenuVisible, bool isStale
});


$ReadVolumeCopyWith<$Res> get volume;

}
/// @nodoc
class _$ViewerStateCopyWithImpl<$Res>
    implements $ViewerStateCopyWith<$Res> {
  _$ViewerStateCopyWithImpl(this._self, this._then);

  final ViewerState _self;
  final $Res Function(ViewerState) _then;

/// Create a copy of ViewerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? volume = null,Object? currentPage = null,Object? isMenuVisible = null,Object? isStale = null,}) {
  return _then(ViewerState(
volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as ReadVolume,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,isMenuVisible: null == isMenuVisible ? _self.isMenuVisible : isMenuVisible // ignore: cast_nullable_to_non_nullable
as bool,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ViewerState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadVolumeCopyWith<$Res> get volume {
  
  return $ReadVolumeCopyWith<$Res>(_self.volume, (value) {
    return _then(_self.copyWith(volume: value));
  });
}
}


/// Adds pattern-matching-related methods to [ViewerState].
extension ViewerStatePatterns on ViewerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ViewerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ViewerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ViewerState value)  $default,){
final _that = this;
switch (_that) {
case _ViewerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ViewerState value)?  $default,){
final _that = this;
switch (_that) {
case _ViewerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReadVolume volume,  int currentPage,  bool isMenuVisible,  bool isStale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ViewerState() when $default != null:
return $default(_that.volume,_that.currentPage,_that.isMenuVisible,_that.isStale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReadVolume volume,  int currentPage,  bool isMenuVisible,  bool isStale)  $default,) {final _that = this;
switch (_that) {
case _ViewerState():
return $default(_that.volume,_that.currentPage,_that.isMenuVisible,_that.isStale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReadVolume volume,  int currentPage,  bool isMenuVisible,  bool isStale)?  $default,) {final _that = this;
switch (_that) {
case _ViewerState() when $default != null:
return $default(_that.volume,_that.currentPage,_that.isMenuVisible,_that.isStale);case _:
  return null;

}
}

}

/// @nodoc


class _ViewerState extends ViewerState {
  const _ViewerState({required this.volume, required this.currentPage, this.isMenuVisible = false, this.isStale = false}): super._();
  

@override final  ReadVolume volume;
/// 表示中のページ（1 始まり）。`volume.files.length + 1` は巻末オーバーレイ。
@override final  int currentPage;
/// ヘッダ / シークバーを表示しているか。
@override@JsonKey() final  bool isMenuVisible;
/// サーバーに確認できず、端末の控えで開いている（#11）。
///
/// この間に次巻へ進めるのは、次巻もダウンロード済みのときだけ。
@override@JsonKey() final  bool isStale;

/// Create a copy of ViewerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ViewerStateCopyWith<_ViewerState> get copyWith => __$ViewerStateCopyWithImpl<_ViewerState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ViewerState&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.isMenuVisible, isMenuVisible) || other.isMenuVisible == isMenuVisible)&&(identical(other.isStale, isStale) || other.isStale == isStale));
}


@override
int get hashCode {
    return Object.hash(runtimeType,volume,currentPage,isMenuVisible,isStale);
}

@override
String toString() {
    return 'ViewerState(volume: $volume, currentPage: $currentPage, isMenuVisible: $isMenuVisible, isStale: $isStale)';
}


}

/// @nodoc
abstract mixin class _$ViewerStateCopyWith<$Res> implements $ViewerStateCopyWith<$Res> {
  factory _$ViewerStateCopyWith(_ViewerState value, $Res Function(_ViewerState) _then) = __$ViewerStateCopyWithImpl;
@override @useResult
$Res call({
 ReadVolume volume, int currentPage, bool isMenuVisible, bool isStale
});


@override $ReadVolumeCopyWith<$Res> get volume;

}
/// @nodoc
class __$ViewerStateCopyWithImpl<$Res>
    implements _$ViewerStateCopyWith<$Res> {
  __$ViewerStateCopyWithImpl(this._self, this._then);

  final _ViewerState _self;
  final $Res Function(_ViewerState) _then;

/// Create a copy of ViewerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? volume = null,Object? currentPage = null,Object? isMenuVisible = null,Object? isStale = null,}) {
  return _then(_ViewerState(
volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as ReadVolume,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,isMenuVisible: null == isMenuVisible ? _self.isMenuVisible : isMenuVisible // ignore: cast_nullable_to_non_nullable
as bool,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ViewerState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadVolumeCopyWith<$Res> get volume {
  
  return $ReadVolumeCopyWith<$Res>(_self.volume, (value) {
    return _then(_self.copyWith(volume: value));
  });
}
}

// dart format on
