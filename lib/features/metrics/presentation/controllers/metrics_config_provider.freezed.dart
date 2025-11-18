// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metrics_config_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MetricsConfig {
  /// Whether metrics collection is enabled
  bool get enabled => throw _privateConstructorUsedError;

  /// Direct metrics endpoint URL (e.g., https://api.example.com/v1/metrics)
  String get apiMetricsEndpoint => throw _privateConstructorUsedError;

  /// Reporting interval in seconds
  int get intervalSeconds => throw _privateConstructorUsedError;

  /// Create a copy of MetricsConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MetricsConfigCopyWith<MetricsConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetricsConfigCopyWith<$Res> {
  factory $MetricsConfigCopyWith(
          MetricsConfig value, $Res Function(MetricsConfig) then) =
      _$MetricsConfigCopyWithImpl<$Res, MetricsConfig>;
  @useResult
  $Res call({bool enabled, String apiMetricsEndpoint, int intervalSeconds});
}

/// @nodoc
class _$MetricsConfigCopyWithImpl<$Res, $Val extends MetricsConfig>
    implements $MetricsConfigCopyWith<$Res> {
  _$MetricsConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MetricsConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? apiMetricsEndpoint = null,
    Object? intervalSeconds = null,
  }) {
    return _then(_value.copyWith(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      apiMetricsEndpoint: null == apiMetricsEndpoint
          ? _value.apiMetricsEndpoint
          : apiMetricsEndpoint // ignore: cast_nullable_to_non_nullable
              as String,
      intervalSeconds: null == intervalSeconds
          ? _value.intervalSeconds
          : intervalSeconds // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MetricsConfigImplCopyWith<$Res>
    implements $MetricsConfigCopyWith<$Res> {
  factory _$$MetricsConfigImplCopyWith(
          _$MetricsConfigImpl value, $Res Function(_$MetricsConfigImpl) then) =
      __$$MetricsConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool enabled, String apiMetricsEndpoint, int intervalSeconds});
}

/// @nodoc
class __$$MetricsConfigImplCopyWithImpl<$Res>
    extends _$MetricsConfigCopyWithImpl<$Res, _$MetricsConfigImpl>
    implements _$$MetricsConfigImplCopyWith<$Res> {
  __$$MetricsConfigImplCopyWithImpl(
      _$MetricsConfigImpl _value, $Res Function(_$MetricsConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of MetricsConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? apiMetricsEndpoint = null,
    Object? intervalSeconds = null,
  }) {
    return _then(_$MetricsConfigImpl(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      apiMetricsEndpoint: null == apiMetricsEndpoint
          ? _value.apiMetricsEndpoint
          : apiMetricsEndpoint // ignore: cast_nullable_to_non_nullable
              as String,
      intervalSeconds: null == intervalSeconds
          ? _value.intervalSeconds
          : intervalSeconds // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$MetricsConfigImpl extends _MetricsConfig {
  const _$MetricsConfigImpl(
      {required this.enabled,
      required this.apiMetricsEndpoint,
      required this.intervalSeconds})
      : super._();

  /// Whether metrics collection is enabled
  @override
  final bool enabled;

  /// Direct metrics endpoint URL (e.g., https://api.example.com/v1/metrics)
  @override
  final String apiMetricsEndpoint;

  /// Reporting interval in seconds
  @override
  final int intervalSeconds;

  @override
  String toString() {
    return 'MetricsConfig(enabled: $enabled, apiMetricsEndpoint: $apiMetricsEndpoint, intervalSeconds: $intervalSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetricsConfigImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.apiMetricsEndpoint, apiMetricsEndpoint) ||
                other.apiMetricsEndpoint == apiMetricsEndpoint) &&
            (identical(other.intervalSeconds, intervalSeconds) ||
                other.intervalSeconds == intervalSeconds));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, enabled, apiMetricsEndpoint, intervalSeconds);

  /// Create a copy of MetricsConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetricsConfigImplCopyWith<_$MetricsConfigImpl> get copyWith =>
      __$$MetricsConfigImplCopyWithImpl<_$MetricsConfigImpl>(this, _$identity);
}

abstract class _MetricsConfig extends MetricsConfig {
  const factory _MetricsConfig(
      {required final bool enabled,
      required final String apiMetricsEndpoint,
      required final int intervalSeconds}) = _$MetricsConfigImpl;
  const _MetricsConfig._() : super._();

  /// Whether metrics collection is enabled
  @override
  bool get enabled;

  /// Direct metrics endpoint URL (e.g., https://api.example.com/v1/metrics)
  @override
  String get apiMetricsEndpoint;

  /// Reporting interval in seconds
  @override
  int get intervalSeconds;

  /// Create a copy of MetricsConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetricsConfigImplCopyWith<_$MetricsConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
