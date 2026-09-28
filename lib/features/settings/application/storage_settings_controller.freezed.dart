// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'storage_settings_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StorageSettingsState {

 CacheSettings get settings; CacheUsage get usage;
/// Create a copy of StorageSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageSettingsStateCopyWith<StorageSettingsState> get copyWith => _$StorageSettingsStateCopyWithImpl<StorageSettingsState>(this as StorageSettingsState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StorageSettingsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageSettingsState&&(identical(other.settings, _this.settings) || other.settings == _this.settings)&&(identical(other.usage, _this.usage) || other.usage == _this.usage));
}


@override
int get hashCode {
  final _this = this as StorageSettingsState;
  return Object.hash(runtimeType,_this.settings,_this.usage);
}

@override
String toString() {
  final _this = this as StorageSettingsState;
  return 'StorageSettingsState(settings: ${_this.settings}, usage: ${_this.usage})';
}


}

/// @nodoc
abstract mixin class $StorageSettingsStateCopyWith<$Res>  {
  factory $StorageSettingsStateCopyWith(StorageSettingsState value, $Res Function(StorageSettingsState) _then) = _$StorageSettingsStateCopyWithImpl;
@useResult
$Res call({
 CacheSettings settings, CacheUsage usage
});


$CacheSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class _$StorageSettingsStateCopyWithImpl<$Res>
    implements $StorageSettingsStateCopyWith<$Res> {
  _$StorageSettingsStateCopyWithImpl(this._self, this._then);

  final StorageSettingsState _self;
  final $Res Function(StorageSettingsState) _then;

/// Create a copy of StorageSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? settings = null,Object? usage = null,}) {
  return _then(StorageSettingsState(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as CacheSettings,usage: null == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as CacheUsage,
  ));
}
/// Create a copy of StorageSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CacheSettingsCopyWith<$Res> get settings {
  
  return $CacheSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [StorageSettingsState].
extension StorageSettingsStatePatterns on StorageSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StorageSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StorageSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StorageSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _StorageSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StorageSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _StorageSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CacheSettings settings,  CacheUsage usage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StorageSettingsState() when $default != null:
return $default(_that.settings,_that.usage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CacheSettings settings,  CacheUsage usage)  $default,) {final _that = this;
switch (_that) {
case _StorageSettingsState():
return $default(_that.settings,_that.usage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CacheSettings settings,  CacheUsage usage)?  $default,) {final _that = this;
switch (_that) {
case _StorageSettingsState() when $default != null:
return $default(_that.settings,_that.usage);case _:
  return null;

}
}

}

/// @nodoc


class _StorageSettingsState implements StorageSettingsState {
  const _StorageSettingsState({required this.settings, required this.usage});
  

@override final  CacheSettings settings;
@override final  CacheUsage usage;

/// Create a copy of StorageSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StorageSettingsStateCopyWith<_StorageSettingsState> get copyWith => __$StorageSettingsStateCopyWithImpl<_StorageSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StorageSettingsState&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.usage, usage) || other.usage == usage));
}


@override
int get hashCode {
    return Object.hash(runtimeType,settings,usage);
}

@override
String toString() {
    return 'StorageSettingsState(settings: $settings, usage: $usage)';
}


}

/// @nodoc
abstract mixin class _$StorageSettingsStateCopyWith<$Res> implements $StorageSettingsStateCopyWith<$Res> {
  factory _$StorageSettingsStateCopyWith(_StorageSettingsState value, $Res Function(_StorageSettingsState) _then) = __$StorageSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 CacheSettings settings, CacheUsage usage
});


@override $CacheSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class __$StorageSettingsStateCopyWithImpl<$Res>
    implements _$StorageSettingsStateCopyWith<$Res> {
  __$StorageSettingsStateCopyWithImpl(this._self, this._then);

  final _StorageSettingsState _self;
  final $Res Function(_StorageSettingsState) _then;

/// Create a copy of StorageSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? settings = null,Object? usage = null,}) {
  return _then(_StorageSettingsState(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as CacheSettings,usage: null == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as CacheUsage,
  ));
}

/// Create a copy of StorageSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CacheSettingsCopyWith<$Res> get settings {
  
  return $CacheSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}

// dart format on
