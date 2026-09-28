// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cache_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CacheSettings {

 CacheLimit get pageLimit; CacheLimit get thumbnailLimit; CacheRetention get retention;
/// Create a copy of CacheSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CacheSettingsCopyWith<CacheSettings> get copyWith => _$CacheSettingsCopyWithImpl<CacheSettings>(this as CacheSettings, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CacheSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CacheSettings&&(identical(other.pageLimit, _this.pageLimit) || other.pageLimit == _this.pageLimit)&&(identical(other.thumbnailLimit, _this.thumbnailLimit) || other.thumbnailLimit == _this.thumbnailLimit)&&(identical(other.retention, _this.retention) || other.retention == _this.retention));
}


@override
int get hashCode {
  final _this = this as CacheSettings;
  return Object.hash(runtimeType,_this.pageLimit,_this.thumbnailLimit,_this.retention);
}

@override
String toString() {
  final _this = this as CacheSettings;
  return 'CacheSettings(pageLimit: ${_this.pageLimit}, thumbnailLimit: ${_this.thumbnailLimit}, retention: ${_this.retention})';
}


}

/// @nodoc
abstract mixin class $CacheSettingsCopyWith<$Res>  {
  factory $CacheSettingsCopyWith(CacheSettings value, $Res Function(CacheSettings) _then) = _$CacheSettingsCopyWithImpl;
@useResult
$Res call({
 CacheLimit pageLimit, CacheLimit thumbnailLimit, CacheRetention retention
});




}
/// @nodoc
class _$CacheSettingsCopyWithImpl<$Res>
    implements $CacheSettingsCopyWith<$Res> {
  _$CacheSettingsCopyWithImpl(this._self, this._then);

  final CacheSettings _self;
  final $Res Function(CacheSettings) _then;

/// Create a copy of CacheSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageLimit = null,Object? thumbnailLimit = null,Object? retention = null,}) {
  return _then(CacheSettings(
pageLimit: null == pageLimit ? _self.pageLimit : pageLimit // ignore: cast_nullable_to_non_nullable
as CacheLimit,thumbnailLimit: null == thumbnailLimit ? _self.thumbnailLimit : thumbnailLimit // ignore: cast_nullable_to_non_nullable
as CacheLimit,retention: null == retention ? _self.retention : retention // ignore: cast_nullable_to_non_nullable
as CacheRetention,
  ));
}

}


/// Adds pattern-matching-related methods to [CacheSettings].
extension CacheSettingsPatterns on CacheSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CacheSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CacheSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CacheSettings value)  $default,){
final _that = this;
switch (_that) {
case _CacheSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CacheSettings value)?  $default,){
final _that = this;
switch (_that) {
case _CacheSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CacheLimit pageLimit,  CacheLimit thumbnailLimit,  CacheRetention retention)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CacheSettings() when $default != null:
return $default(_that.pageLimit,_that.thumbnailLimit,_that.retention);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CacheLimit pageLimit,  CacheLimit thumbnailLimit,  CacheRetention retention)  $default,) {final _that = this;
switch (_that) {
case _CacheSettings():
return $default(_that.pageLimit,_that.thumbnailLimit,_that.retention);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CacheLimit pageLimit,  CacheLimit thumbnailLimit,  CacheRetention retention)?  $default,) {final _that = this;
switch (_that) {
case _CacheSettings() when $default != null:
return $default(_that.pageLimit,_that.thumbnailLimit,_that.retention);case _:
  return null;

}
}

}

/// @nodoc


class _CacheSettings implements CacheSettings {
  const _CacheSettings({this.pageLimit = CacheLimit.gb1, this.thumbnailLimit = CacheLimit.mb256, this.retention = CacheRetention.days30});
  

@override@JsonKey() final  CacheLimit pageLimit;
@override@JsonKey() final  CacheLimit thumbnailLimit;
@override@JsonKey() final  CacheRetention retention;

/// Create a copy of CacheSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CacheSettingsCopyWith<_CacheSettings> get copyWith => __$CacheSettingsCopyWithImpl<_CacheSettings>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CacheSettings&&(identical(other.pageLimit, pageLimit) || other.pageLimit == pageLimit)&&(identical(other.thumbnailLimit, thumbnailLimit) || other.thumbnailLimit == thumbnailLimit)&&(identical(other.retention, retention) || other.retention == retention));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pageLimit,thumbnailLimit,retention);
}

@override
String toString() {
    return 'CacheSettings(pageLimit: $pageLimit, thumbnailLimit: $thumbnailLimit, retention: $retention)';
}


}

/// @nodoc
abstract mixin class _$CacheSettingsCopyWith<$Res> implements $CacheSettingsCopyWith<$Res> {
  factory _$CacheSettingsCopyWith(_CacheSettings value, $Res Function(_CacheSettings) _then) = __$CacheSettingsCopyWithImpl;
@override @useResult
$Res call({
 CacheLimit pageLimit, CacheLimit thumbnailLimit, CacheRetention retention
});




}
/// @nodoc
class __$CacheSettingsCopyWithImpl<$Res>
    implements _$CacheSettingsCopyWith<$Res> {
  __$CacheSettingsCopyWithImpl(this._self, this._then);

  final _CacheSettings _self;
  final $Res Function(_CacheSettings) _then;

/// Create a copy of CacheSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageLimit = null,Object? thumbnailLimit = null,Object? retention = null,}) {
  return _then(_CacheSettings(
pageLimit: null == pageLimit ? _self.pageLimit : pageLimit // ignore: cast_nullable_to_non_nullable
as CacheLimit,thumbnailLimit: null == thumbnailLimit ? _self.thumbnailLimit : thumbnailLimit // ignore: cast_nullable_to_non_nullable
as CacheLimit,retention: null == retention ? _self.retention : retention // ignore: cast_nullable_to_non_nullable
as CacheRetention,
  ));
}


}

// dart format on
