// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'push_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PushStatus {

 PushAvailability get availability;/// 「新刊通知」の設定。読み込むまでは `null`。
 bool? get enabled;/// 通知の許可。まだ確かめていなければ `null`。
 PushPermission? get permission;/// このセッションでサーバーへの登録を確かめたか（登録した / 控えと一致した）。
 bool get registered;/// 直近の登録の失敗（画面に出す文言）。成功したら消える。
 String? get failure;
/// Create a copy of PushStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PushStatusCopyWith<PushStatus> get copyWith => _$PushStatusCopyWithImpl<PushStatus>(this as PushStatus, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PushStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PushStatus&&(identical(other.availability, _this.availability) || other.availability == _this.availability)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.permission, _this.permission) || other.permission == _this.permission)&&(identical(other.registered, _this.registered) || other.registered == _this.registered)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}


@override
int get hashCode {
  final _this = this as PushStatus;
  return Object.hash(runtimeType,_this.availability,_this.enabled,_this.permission,_this.registered,_this.failure);
}

@override
String toString() {
  final _this = this as PushStatus;
  return 'PushStatus(availability: ${_this.availability}, enabled: ${_this.enabled}, permission: ${_this.permission}, registered: ${_this.registered}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $PushStatusCopyWith<$Res>  {
  factory $PushStatusCopyWith(PushStatus value, $Res Function(PushStatus) _then) = _$PushStatusCopyWithImpl;
@useResult
$Res call({
 PushAvailability availability, bool? enabled, PushPermission? permission, bool registered, String? failure
});




}
/// @nodoc
class _$PushStatusCopyWithImpl<$Res>
    implements $PushStatusCopyWith<$Res> {
  _$PushStatusCopyWithImpl(this._self, this._then);

  final PushStatus _self;
  final $Res Function(PushStatus) _then;

/// Create a copy of PushStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? availability = null,Object? enabled = freezed,Object? permission = freezed,Object? registered = null,Object? failure = freezed,}) {
  return _then(PushStatus(
availability: null == availability ? _self.availability : availability // ignore: cast_nullable_to_non_nullable
as PushAvailability,enabled: freezed == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool?,permission: freezed == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as PushPermission?,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PushStatus].
extension PushStatusPatterns on PushStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PushStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PushStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PushStatus value)  $default,){
final _that = this;
switch (_that) {
case _PushStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PushStatus value)?  $default,){
final _that = this;
switch (_that) {
case _PushStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PushAvailability availability,  bool? enabled,  PushPermission? permission,  bool registered,  String? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PushStatus() when $default != null:
return $default(_that.availability,_that.enabled,_that.permission,_that.registered,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PushAvailability availability,  bool? enabled,  PushPermission? permission,  bool registered,  String? failure)  $default,) {final _that = this;
switch (_that) {
case _PushStatus():
return $default(_that.availability,_that.enabled,_that.permission,_that.registered,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PushAvailability availability,  bool? enabled,  PushPermission? permission,  bool registered,  String? failure)?  $default,) {final _that = this;
switch (_that) {
case _PushStatus() when $default != null:
return $default(_that.availability,_that.enabled,_that.permission,_that.registered,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _PushStatus implements PushStatus {
  const _PushStatus({this.availability = PushAvailability.checking, this.enabled, this.permission, this.registered = false, this.failure});
  

@override@JsonKey() final  PushAvailability availability;
/// 「新刊通知」の設定。読み込むまでは `null`。
@override final  bool? enabled;
/// 通知の許可。まだ確かめていなければ `null`。
@override final  PushPermission? permission;
/// このセッションでサーバーへの登録を確かめたか（登録した / 控えと一致した）。
@override@JsonKey() final  bool registered;
/// 直近の登録の失敗（画面に出す文言）。成功したら消える。
@override final  String? failure;

/// Create a copy of PushStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PushStatusCopyWith<_PushStatus> get copyWith => __$PushStatusCopyWithImpl<_PushStatus>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PushStatus&&(identical(other.availability, availability) || other.availability == availability)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.permission, permission) || other.permission == permission)&&(identical(other.registered, registered) || other.registered == registered)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,availability,enabled,permission,registered,failure);
}

@override
String toString() {
    return 'PushStatus(availability: $availability, enabled: $enabled, permission: $permission, registered: $registered, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$PushStatusCopyWith<$Res> implements $PushStatusCopyWith<$Res> {
  factory _$PushStatusCopyWith(_PushStatus value, $Res Function(_PushStatus) _then) = __$PushStatusCopyWithImpl;
@override @useResult
$Res call({
 PushAvailability availability, bool? enabled, PushPermission? permission, bool registered, String? failure
});




}
/// @nodoc
class __$PushStatusCopyWithImpl<$Res>
    implements _$PushStatusCopyWith<$Res> {
  __$PushStatusCopyWithImpl(this._self, this._then);

  final _PushStatus _self;
  final $Res Function(_PushStatus) _then;

/// Create a copy of PushStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? availability = null,Object? enabled = freezed,Object? permission = freezed,Object? registered = null,Object? failure = freezed,}) {
  return _then(_PushStatus(
availability: null == availability ? _self.availability : availability // ignore: cast_nullable_to_non_nullable
as PushAvailability,enabled: freezed == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool?,permission: freezed == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as PushPermission?,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
