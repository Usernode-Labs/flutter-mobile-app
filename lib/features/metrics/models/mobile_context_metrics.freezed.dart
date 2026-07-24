// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mobile_context_metrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RuntimeMetrics {
  String get appState => throw _privateConstructorUsedError;
  String get appVersion => throw _privateConstructorUsedError;
  String get appBuildNumber => throw _privateConstructorUsedError;
  int get appUptimeMs => throw _privateConstructorUsedError;
  bool get keepAliveModeActive => throw _privateConstructorUsedError;
  bool get notificationsEnabled => throw _privateConstructorUsedError;

  /// Create a copy of RuntimeMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RuntimeMetricsCopyWith<RuntimeMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuntimeMetricsCopyWith<$Res> {
  factory $RuntimeMetricsCopyWith(
          RuntimeMetrics value, $Res Function(RuntimeMetrics) then) =
      _$RuntimeMetricsCopyWithImpl<$Res, RuntimeMetrics>;
  @useResult
  $Res call(
      {String appState,
      String appVersion,
      String appBuildNumber,
      int appUptimeMs,
      bool keepAliveModeActive,
      bool notificationsEnabled});
}

/// @nodoc
class _$RuntimeMetricsCopyWithImpl<$Res, $Val extends RuntimeMetrics>
    implements $RuntimeMetricsCopyWith<$Res> {
  _$RuntimeMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RuntimeMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appState = null,
    Object? appVersion = null,
    Object? appBuildNumber = null,
    Object? appUptimeMs = null,
    Object? keepAliveModeActive = null,
    Object? notificationsEnabled = null,
  }) {
    return _then(_value.copyWith(
      appState: null == appState
          ? _value.appState
          : appState // ignore: cast_nullable_to_non_nullable
              as String,
      appVersion: null == appVersion
          ? _value.appVersion
          : appVersion // ignore: cast_nullable_to_non_nullable
              as String,
      appBuildNumber: null == appBuildNumber
          ? _value.appBuildNumber
          : appBuildNumber // ignore: cast_nullable_to_non_nullable
              as String,
      appUptimeMs: null == appUptimeMs
          ? _value.appUptimeMs
          : appUptimeMs // ignore: cast_nullable_to_non_nullable
              as int,
      keepAliveModeActive: null == keepAliveModeActive
          ? _value.keepAliveModeActive
          : keepAliveModeActive // ignore: cast_nullable_to_non_nullable
              as bool,
      notificationsEnabled: null == notificationsEnabled
          ? _value.notificationsEnabled
          : notificationsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuntimeMetricsImplCopyWith<$Res>
    implements $RuntimeMetricsCopyWith<$Res> {
  factory _$$RuntimeMetricsImplCopyWith(_$RuntimeMetricsImpl value,
          $Res Function(_$RuntimeMetricsImpl) then) =
      __$$RuntimeMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String appState,
      String appVersion,
      String appBuildNumber,
      int appUptimeMs,
      bool keepAliveModeActive,
      bool notificationsEnabled});
}

/// @nodoc
class __$$RuntimeMetricsImplCopyWithImpl<$Res>
    extends _$RuntimeMetricsCopyWithImpl<$Res, _$RuntimeMetricsImpl>
    implements _$$RuntimeMetricsImplCopyWith<$Res> {
  __$$RuntimeMetricsImplCopyWithImpl(
      _$RuntimeMetricsImpl _value, $Res Function(_$RuntimeMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of RuntimeMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appState = null,
    Object? appVersion = null,
    Object? appBuildNumber = null,
    Object? appUptimeMs = null,
    Object? keepAliveModeActive = null,
    Object? notificationsEnabled = null,
  }) {
    return _then(_$RuntimeMetricsImpl(
      appState: null == appState
          ? _value.appState
          : appState // ignore: cast_nullable_to_non_nullable
              as String,
      appVersion: null == appVersion
          ? _value.appVersion
          : appVersion // ignore: cast_nullable_to_non_nullable
              as String,
      appBuildNumber: null == appBuildNumber
          ? _value.appBuildNumber
          : appBuildNumber // ignore: cast_nullable_to_non_nullable
              as String,
      appUptimeMs: null == appUptimeMs
          ? _value.appUptimeMs
          : appUptimeMs // ignore: cast_nullable_to_non_nullable
              as int,
      keepAliveModeActive: null == keepAliveModeActive
          ? _value.keepAliveModeActive
          : keepAliveModeActive // ignore: cast_nullable_to_non_nullable
              as bool,
      notificationsEnabled: null == notificationsEnabled
          ? _value.notificationsEnabled
          : notificationsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$RuntimeMetricsImpl extends _RuntimeMetrics {
  const _$RuntimeMetricsImpl(
      {required this.appState,
      required this.appVersion,
      required this.appBuildNumber,
      required this.appUptimeMs,
      required this.keepAliveModeActive,
      required this.notificationsEnabled})
      : super._();

  @override
  final String appState;
  @override
  final String appVersion;
  @override
  final String appBuildNumber;
  @override
  final int appUptimeMs;
  @override
  final bool keepAliveModeActive;
  @override
  final bool notificationsEnabled;

  @override
  String toString() {
    return 'RuntimeMetrics(appState: $appState, appVersion: $appVersion, appBuildNumber: $appBuildNumber, appUptimeMs: $appUptimeMs, keepAliveModeActive: $keepAliveModeActive, notificationsEnabled: $notificationsEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuntimeMetricsImpl &&
            (identical(other.appState, appState) ||
                other.appState == appState) &&
            (identical(other.appVersion, appVersion) ||
                other.appVersion == appVersion) &&
            (identical(other.appBuildNumber, appBuildNumber) ||
                other.appBuildNumber == appBuildNumber) &&
            (identical(other.appUptimeMs, appUptimeMs) ||
                other.appUptimeMs == appUptimeMs) &&
            (identical(other.keepAliveModeActive, keepAliveModeActive) ||
                other.keepAliveModeActive == keepAliveModeActive) &&
            (identical(other.notificationsEnabled, notificationsEnabled) ||
                other.notificationsEnabled == notificationsEnabled));
  }

  @override
  int get hashCode => Object.hash(runtimeType, appState, appVersion,
      appBuildNumber, appUptimeMs, keepAliveModeActive, notificationsEnabled);

  /// Create a copy of RuntimeMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RuntimeMetricsImplCopyWith<_$RuntimeMetricsImpl> get copyWith =>
      __$$RuntimeMetricsImplCopyWithImpl<_$RuntimeMetricsImpl>(
          this, _$identity);
}

abstract class _RuntimeMetrics extends RuntimeMetrics {
  const factory _RuntimeMetrics(
      {required final String appState,
      required final String appVersion,
      required final String appBuildNumber,
      required final int appUptimeMs,
      required final bool keepAliveModeActive,
      required final bool notificationsEnabled}) = _$RuntimeMetricsImpl;
  const _RuntimeMetrics._() : super._();

  @override
  String get appState;
  @override
  String get appVersion;
  @override
  String get appBuildNumber;
  @override
  int get appUptimeMs;
  @override
  bool get keepAliveModeActive;
  @override
  bool get notificationsEnabled;

  /// Create a copy of RuntimeMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RuntimeMetricsImplCopyWith<_$RuntimeMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PlatformMetrics {
  String get platform => throw _privateConstructorUsedError;
  String get platformVersion => throw _privateConstructorUsedError;
  String? get systemArchitecture => throw _privateConstructorUsedError;

  /// Create a copy of PlatformMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlatformMetricsCopyWith<PlatformMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlatformMetricsCopyWith<$Res> {
  factory $PlatformMetricsCopyWith(
          PlatformMetrics value, $Res Function(PlatformMetrics) then) =
      _$PlatformMetricsCopyWithImpl<$Res, PlatformMetrics>;
  @useResult
  $Res call(
      {String platform, String platformVersion, String? systemArchitecture});
}

/// @nodoc
class _$PlatformMetricsCopyWithImpl<$Res, $Val extends PlatformMetrics>
    implements $PlatformMetricsCopyWith<$Res> {
  _$PlatformMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlatformMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? platform = null,
    Object? platformVersion = null,
    Object? systemArchitecture = freezed,
  }) {
    return _then(_value.copyWith(
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      platformVersion: null == platformVersion
          ? _value.platformVersion
          : platformVersion // ignore: cast_nullable_to_non_nullable
              as String,
      systemArchitecture: freezed == systemArchitecture
          ? _value.systemArchitecture
          : systemArchitecture // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlatformMetricsImplCopyWith<$Res>
    implements $PlatformMetricsCopyWith<$Res> {
  factory _$$PlatformMetricsImplCopyWith(_$PlatformMetricsImpl value,
          $Res Function(_$PlatformMetricsImpl) then) =
      __$$PlatformMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String platform, String platformVersion, String? systemArchitecture});
}

/// @nodoc
class __$$PlatformMetricsImplCopyWithImpl<$Res>
    extends _$PlatformMetricsCopyWithImpl<$Res, _$PlatformMetricsImpl>
    implements _$$PlatformMetricsImplCopyWith<$Res> {
  __$$PlatformMetricsImplCopyWithImpl(
      _$PlatformMetricsImpl _value, $Res Function(_$PlatformMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlatformMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? platform = null,
    Object? platformVersion = null,
    Object? systemArchitecture = freezed,
  }) {
    return _then(_$PlatformMetricsImpl(
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      platformVersion: null == platformVersion
          ? _value.platformVersion
          : platformVersion // ignore: cast_nullable_to_non_nullable
              as String,
      systemArchitecture: freezed == systemArchitecture
          ? _value.systemArchitecture
          : systemArchitecture // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$PlatformMetricsImpl extends _PlatformMetrics {
  const _$PlatformMetricsImpl(
      {required this.platform,
      required this.platformVersion,
      this.systemArchitecture})
      : super._();

  @override
  final String platform;
  @override
  final String platformVersion;
  @override
  final String? systemArchitecture;

  @override
  String toString() {
    return 'PlatformMetrics(platform: $platform, platformVersion: $platformVersion, systemArchitecture: $systemArchitecture)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlatformMetricsImpl &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.platformVersion, platformVersion) ||
                other.platformVersion == platformVersion) &&
            (identical(other.systemArchitecture, systemArchitecture) ||
                other.systemArchitecture == systemArchitecture));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, platform, platformVersion, systemArchitecture);

  /// Create a copy of PlatformMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlatformMetricsImplCopyWith<_$PlatformMetricsImpl> get copyWith =>
      __$$PlatformMetricsImplCopyWithImpl<_$PlatformMetricsImpl>(
          this, _$identity);
}

abstract class _PlatformMetrics extends PlatformMetrics {
  const factory _PlatformMetrics(
      {required final String platform,
      required final String platformVersion,
      final String? systemArchitecture}) = _$PlatformMetricsImpl;
  const _PlatformMetrics._() : super._();

  @override
  String get platform;
  @override
  String get platformVersion;
  @override
  String? get systemArchitecture;

  /// Create a copy of PlatformMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlatformMetricsImplCopyWith<_$PlatformMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DeviceMetrics {
  String get deviceId => throw _privateConstructorUsedError;
  String get deviceManufacturer => throw _privateConstructorUsedError;
  String get deviceModel => throw _privateConstructorUsedError;
  bool get isPhysicalDevice => throw _privateConstructorUsedError;

  /// Create a copy of DeviceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceMetricsCopyWith<DeviceMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceMetricsCopyWith<$Res> {
  factory $DeviceMetricsCopyWith(
          DeviceMetrics value, $Res Function(DeviceMetrics) then) =
      _$DeviceMetricsCopyWithImpl<$Res, DeviceMetrics>;
  @useResult
  $Res call(
      {String deviceId,
      String deviceManufacturer,
      String deviceModel,
      bool isPhysicalDevice});
}

/// @nodoc
class _$DeviceMetricsCopyWithImpl<$Res, $Val extends DeviceMetrics>
    implements $DeviceMetricsCopyWith<$Res> {
  _$DeviceMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? deviceManufacturer = null,
    Object? deviceModel = null,
    Object? isPhysicalDevice = null,
  }) {
    return _then(_value.copyWith(
      deviceId: null == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String,
      deviceManufacturer: null == deviceManufacturer
          ? _value.deviceManufacturer
          : deviceManufacturer // ignore: cast_nullable_to_non_nullable
              as String,
      deviceModel: null == deviceModel
          ? _value.deviceModel
          : deviceModel // ignore: cast_nullable_to_non_nullable
              as String,
      isPhysicalDevice: null == isPhysicalDevice
          ? _value.isPhysicalDevice
          : isPhysicalDevice // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DeviceMetricsImplCopyWith<$Res>
    implements $DeviceMetricsCopyWith<$Res> {
  factory _$$DeviceMetricsImplCopyWith(
          _$DeviceMetricsImpl value, $Res Function(_$DeviceMetricsImpl) then) =
      __$$DeviceMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String deviceId,
      String deviceManufacturer,
      String deviceModel,
      bool isPhysicalDevice});
}

/// @nodoc
class __$$DeviceMetricsImplCopyWithImpl<$Res>
    extends _$DeviceMetricsCopyWithImpl<$Res, _$DeviceMetricsImpl>
    implements _$$DeviceMetricsImplCopyWith<$Res> {
  __$$DeviceMetricsImplCopyWithImpl(
      _$DeviceMetricsImpl _value, $Res Function(_$DeviceMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DeviceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? deviceManufacturer = null,
    Object? deviceModel = null,
    Object? isPhysicalDevice = null,
  }) {
    return _then(_$DeviceMetricsImpl(
      deviceId: null == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String,
      deviceManufacturer: null == deviceManufacturer
          ? _value.deviceManufacturer
          : deviceManufacturer // ignore: cast_nullable_to_non_nullable
              as String,
      deviceModel: null == deviceModel
          ? _value.deviceModel
          : deviceModel // ignore: cast_nullable_to_non_nullable
              as String,
      isPhysicalDevice: null == isPhysicalDevice
          ? _value.isPhysicalDevice
          : isPhysicalDevice // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$DeviceMetricsImpl extends _DeviceMetrics {
  const _$DeviceMetricsImpl(
      {required this.deviceId,
      required this.deviceManufacturer,
      required this.deviceModel,
      required this.isPhysicalDevice})
      : super._();

  @override
  final String deviceId;
  @override
  final String deviceManufacturer;
  @override
  final String deviceModel;
  @override
  final bool isPhysicalDevice;

  @override
  String toString() {
    return 'DeviceMetrics(deviceId: $deviceId, deviceManufacturer: $deviceManufacturer, deviceModel: $deviceModel, isPhysicalDevice: $isPhysicalDevice)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceMetricsImpl &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.deviceManufacturer, deviceManufacturer) ||
                other.deviceManufacturer == deviceManufacturer) &&
            (identical(other.deviceModel, deviceModel) ||
                other.deviceModel == deviceModel) &&
            (identical(other.isPhysicalDevice, isPhysicalDevice) ||
                other.isPhysicalDevice == isPhysicalDevice));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, deviceId, deviceManufacturer, deviceModel, isPhysicalDevice);

  /// Create a copy of DeviceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceMetricsImplCopyWith<_$DeviceMetricsImpl> get copyWith =>
      __$$DeviceMetricsImplCopyWithImpl<_$DeviceMetricsImpl>(this, _$identity);
}

abstract class _DeviceMetrics extends DeviceMetrics {
  const factory _DeviceMetrics(
      {required final String deviceId,
      required final String deviceManufacturer,
      required final String deviceModel,
      required final bool isPhysicalDevice}) = _$DeviceMetricsImpl;
  const _DeviceMetrics._() : super._();

  @override
  String get deviceId;
  @override
  String get deviceManufacturer;
  @override
  String get deviceModel;
  @override
  bool get isPhysicalDevice;

  /// Create a copy of DeviceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceMetricsImplCopyWith<_$DeviceMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BatteryMetrics {
  int? get batteryLevel => throw _privateConstructorUsedError;
  String get batteryState => throw _privateConstructorUsedError;
  bool get batteryOptimizationDisabled => throw _privateConstructorUsedError;
  bool get powerSaveMode => throw _privateConstructorUsedError;
  bool get lowPowerMode => throw _privateConstructorUsedError;

  /// Create a copy of BatteryMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BatteryMetricsCopyWith<BatteryMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BatteryMetricsCopyWith<$Res> {
  factory $BatteryMetricsCopyWith(
          BatteryMetrics value, $Res Function(BatteryMetrics) then) =
      _$BatteryMetricsCopyWithImpl<$Res, BatteryMetrics>;
  @useResult
  $Res call(
      {int? batteryLevel,
      String batteryState,
      bool batteryOptimizationDisabled,
      bool powerSaveMode,
      bool lowPowerMode});
}

/// @nodoc
class _$BatteryMetricsCopyWithImpl<$Res, $Val extends BatteryMetrics>
    implements $BatteryMetricsCopyWith<$Res> {
  _$BatteryMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BatteryMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? batteryLevel = freezed,
    Object? batteryState = null,
    Object? batteryOptimizationDisabled = null,
    Object? powerSaveMode = null,
    Object? lowPowerMode = null,
  }) {
    return _then(_value.copyWith(
      batteryLevel: freezed == batteryLevel
          ? _value.batteryLevel
          : batteryLevel // ignore: cast_nullable_to_non_nullable
              as int?,
      batteryState: null == batteryState
          ? _value.batteryState
          : batteryState // ignore: cast_nullable_to_non_nullable
              as String,
      batteryOptimizationDisabled: null == batteryOptimizationDisabled
          ? _value.batteryOptimizationDisabled
          : batteryOptimizationDisabled // ignore: cast_nullable_to_non_nullable
              as bool,
      powerSaveMode: null == powerSaveMode
          ? _value.powerSaveMode
          : powerSaveMode // ignore: cast_nullable_to_non_nullable
              as bool,
      lowPowerMode: null == lowPowerMode
          ? _value.lowPowerMode
          : lowPowerMode // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BatteryMetricsImplCopyWith<$Res>
    implements $BatteryMetricsCopyWith<$Res> {
  factory _$$BatteryMetricsImplCopyWith(_$BatteryMetricsImpl value,
          $Res Function(_$BatteryMetricsImpl) then) =
      __$$BatteryMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? batteryLevel,
      String batteryState,
      bool batteryOptimizationDisabled,
      bool powerSaveMode,
      bool lowPowerMode});
}

/// @nodoc
class __$$BatteryMetricsImplCopyWithImpl<$Res>
    extends _$BatteryMetricsCopyWithImpl<$Res, _$BatteryMetricsImpl>
    implements _$$BatteryMetricsImplCopyWith<$Res> {
  __$$BatteryMetricsImplCopyWithImpl(
      _$BatteryMetricsImpl _value, $Res Function(_$BatteryMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of BatteryMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? batteryLevel = freezed,
    Object? batteryState = null,
    Object? batteryOptimizationDisabled = null,
    Object? powerSaveMode = null,
    Object? lowPowerMode = null,
  }) {
    return _then(_$BatteryMetricsImpl(
      batteryLevel: freezed == batteryLevel
          ? _value.batteryLevel
          : batteryLevel // ignore: cast_nullable_to_non_nullable
              as int?,
      batteryState: null == batteryState
          ? _value.batteryState
          : batteryState // ignore: cast_nullable_to_non_nullable
              as String,
      batteryOptimizationDisabled: null == batteryOptimizationDisabled
          ? _value.batteryOptimizationDisabled
          : batteryOptimizationDisabled // ignore: cast_nullable_to_non_nullable
              as bool,
      powerSaveMode: null == powerSaveMode
          ? _value.powerSaveMode
          : powerSaveMode // ignore: cast_nullable_to_non_nullable
              as bool,
      lowPowerMode: null == lowPowerMode
          ? _value.lowPowerMode
          : lowPowerMode // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$BatteryMetricsImpl extends _BatteryMetrics {
  const _$BatteryMetricsImpl(
      {this.batteryLevel,
      required this.batteryState,
      required this.batteryOptimizationDisabled,
      required this.powerSaveMode,
      required this.lowPowerMode})
      : super._();

  @override
  final int? batteryLevel;
  @override
  final String batteryState;
  @override
  final bool batteryOptimizationDisabled;
  @override
  final bool powerSaveMode;
  @override
  final bool lowPowerMode;

  @override
  String toString() {
    return 'BatteryMetrics(batteryLevel: $batteryLevel, batteryState: $batteryState, batteryOptimizationDisabled: $batteryOptimizationDisabled, powerSaveMode: $powerSaveMode, lowPowerMode: $lowPowerMode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BatteryMetricsImpl &&
            (identical(other.batteryLevel, batteryLevel) ||
                other.batteryLevel == batteryLevel) &&
            (identical(other.batteryState, batteryState) ||
                other.batteryState == batteryState) &&
            (identical(other.batteryOptimizationDisabled,
                    batteryOptimizationDisabled) ||
                other.batteryOptimizationDisabled ==
                    batteryOptimizationDisabled) &&
            (identical(other.powerSaveMode, powerSaveMode) ||
                other.powerSaveMode == powerSaveMode) &&
            (identical(other.lowPowerMode, lowPowerMode) ||
                other.lowPowerMode == lowPowerMode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, batteryLevel, batteryState,
      batteryOptimizationDisabled, powerSaveMode, lowPowerMode);

  /// Create a copy of BatteryMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BatteryMetricsImplCopyWith<_$BatteryMetricsImpl> get copyWith =>
      __$$BatteryMetricsImplCopyWithImpl<_$BatteryMetricsImpl>(
          this, _$identity);
}

abstract class _BatteryMetrics extends BatteryMetrics {
  const factory _BatteryMetrics(
      {final int? batteryLevel,
      required final String batteryState,
      required final bool batteryOptimizationDisabled,
      required final bool powerSaveMode,
      required final bool lowPowerMode}) = _$BatteryMetricsImpl;
  const _BatteryMetrics._() : super._();

  @override
  int? get batteryLevel;
  @override
  String get batteryState;
  @override
  bool get batteryOptimizationDisabled;
  @override
  bool get powerSaveMode;
  @override
  bool get lowPowerMode;

  /// Create a copy of BatteryMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BatteryMetricsImplCopyWith<_$BatteryMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$NetworkMetrics {
  String get networkType => throw _privateConstructorUsedError;
  bool get networkConnected => throw _privateConstructorUsedError;

  /// Create a copy of NetworkMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NetworkMetricsCopyWith<NetworkMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NetworkMetricsCopyWith<$Res> {
  factory $NetworkMetricsCopyWith(
          NetworkMetrics value, $Res Function(NetworkMetrics) then) =
      _$NetworkMetricsCopyWithImpl<$Res, NetworkMetrics>;
  @useResult
  $Res call({String networkType, bool networkConnected});
}

/// @nodoc
class _$NetworkMetricsCopyWithImpl<$Res, $Val extends NetworkMetrics>
    implements $NetworkMetricsCopyWith<$Res> {
  _$NetworkMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NetworkMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? networkType = null,
    Object? networkConnected = null,
  }) {
    return _then(_value.copyWith(
      networkType: null == networkType
          ? _value.networkType
          : networkType // ignore: cast_nullable_to_non_nullable
              as String,
      networkConnected: null == networkConnected
          ? _value.networkConnected
          : networkConnected // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NetworkMetricsImplCopyWith<$Res>
    implements $NetworkMetricsCopyWith<$Res> {
  factory _$$NetworkMetricsImplCopyWith(_$NetworkMetricsImpl value,
          $Res Function(_$NetworkMetricsImpl) then) =
      __$$NetworkMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String networkType, bool networkConnected});
}

/// @nodoc
class __$$NetworkMetricsImplCopyWithImpl<$Res>
    extends _$NetworkMetricsCopyWithImpl<$Res, _$NetworkMetricsImpl>
    implements _$$NetworkMetricsImplCopyWith<$Res> {
  __$$NetworkMetricsImplCopyWithImpl(
      _$NetworkMetricsImpl _value, $Res Function(_$NetworkMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? networkType = null,
    Object? networkConnected = null,
  }) {
    return _then(_$NetworkMetricsImpl(
      networkType: null == networkType
          ? _value.networkType
          : networkType // ignore: cast_nullable_to_non_nullable
              as String,
      networkConnected: null == networkConnected
          ? _value.networkConnected
          : networkConnected // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$NetworkMetricsImpl extends _NetworkMetrics {
  const _$NetworkMetricsImpl(
      {required this.networkType, required this.networkConnected})
      : super._();

  @override
  final String networkType;
  @override
  final bool networkConnected;

  @override
  String toString() {
    return 'NetworkMetrics(networkType: $networkType, networkConnected: $networkConnected)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkMetricsImpl &&
            (identical(other.networkType, networkType) ||
                other.networkType == networkType) &&
            (identical(other.networkConnected, networkConnected) ||
                other.networkConnected == networkConnected));
  }

  @override
  int get hashCode => Object.hash(runtimeType, networkType, networkConnected);

  /// Create a copy of NetworkMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkMetricsImplCopyWith<_$NetworkMetricsImpl> get copyWith =>
      __$$NetworkMetricsImplCopyWithImpl<_$NetworkMetricsImpl>(
          this, _$identity);
}

abstract class _NetworkMetrics extends NetworkMetrics {
  const factory _NetworkMetrics(
      {required final String networkType,
      required final bool networkConnected}) = _$NetworkMetricsImpl;
  const _NetworkMetrics._() : super._();

  @override
  String get networkType;
  @override
  bool get networkConnected;

  /// Create a copy of NetworkMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkMetricsImplCopyWith<_$NetworkMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ForegroundServiceMetrics {
  bool get foregroundServiceRunning => throw _privateConstructorUsedError;
  bool get wakelockHeld => throw _privateConstructorUsedError;

  /// Create a copy of ForegroundServiceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ForegroundServiceMetricsCopyWith<ForegroundServiceMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ForegroundServiceMetricsCopyWith<$Res> {
  factory $ForegroundServiceMetricsCopyWith(ForegroundServiceMetrics value,
          $Res Function(ForegroundServiceMetrics) then) =
      _$ForegroundServiceMetricsCopyWithImpl<$Res, ForegroundServiceMetrics>;
  @useResult
  $Res call({bool foregroundServiceRunning, bool wakelockHeld});
}

/// @nodoc
class _$ForegroundServiceMetricsCopyWithImpl<$Res,
        $Val extends ForegroundServiceMetrics>
    implements $ForegroundServiceMetricsCopyWith<$Res> {
  _$ForegroundServiceMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ForegroundServiceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? foregroundServiceRunning = null,
    Object? wakelockHeld = null,
  }) {
    return _then(_value.copyWith(
      foregroundServiceRunning: null == foregroundServiceRunning
          ? _value.foregroundServiceRunning
          : foregroundServiceRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      wakelockHeld: null == wakelockHeld
          ? _value.wakelockHeld
          : wakelockHeld // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ForegroundServiceMetricsImplCopyWith<$Res>
    implements $ForegroundServiceMetricsCopyWith<$Res> {
  factory _$$ForegroundServiceMetricsImplCopyWith(
          _$ForegroundServiceMetricsImpl value,
          $Res Function(_$ForegroundServiceMetricsImpl) then) =
      __$$ForegroundServiceMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool foregroundServiceRunning, bool wakelockHeld});
}

/// @nodoc
class __$$ForegroundServiceMetricsImplCopyWithImpl<$Res>
    extends _$ForegroundServiceMetricsCopyWithImpl<$Res,
        _$ForegroundServiceMetricsImpl>
    implements _$$ForegroundServiceMetricsImplCopyWith<$Res> {
  __$$ForegroundServiceMetricsImplCopyWithImpl(
      _$ForegroundServiceMetricsImpl _value,
      $Res Function(_$ForegroundServiceMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of ForegroundServiceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? foregroundServiceRunning = null,
    Object? wakelockHeld = null,
  }) {
    return _then(_$ForegroundServiceMetricsImpl(
      foregroundServiceRunning: null == foregroundServiceRunning
          ? _value.foregroundServiceRunning
          : foregroundServiceRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      wakelockHeld: null == wakelockHeld
          ? _value.wakelockHeld
          : wakelockHeld // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ForegroundServiceMetricsImpl extends _ForegroundServiceMetrics {
  const _$ForegroundServiceMetricsImpl(
      {required this.foregroundServiceRunning, required this.wakelockHeld})
      : super._();

  @override
  final bool foregroundServiceRunning;
  @override
  final bool wakelockHeld;

  @override
  String toString() {
    return 'ForegroundServiceMetrics(foregroundServiceRunning: $foregroundServiceRunning, wakelockHeld: $wakelockHeld)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ForegroundServiceMetricsImpl &&
            (identical(
                    other.foregroundServiceRunning, foregroundServiceRunning) ||
                other.foregroundServiceRunning == foregroundServiceRunning) &&
            (identical(other.wakelockHeld, wakelockHeld) ||
                other.wakelockHeld == wakelockHeld));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, foregroundServiceRunning, wakelockHeld);

  /// Create a copy of ForegroundServiceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ForegroundServiceMetricsImplCopyWith<_$ForegroundServiceMetricsImpl>
      get copyWith => __$$ForegroundServiceMetricsImplCopyWithImpl<
          _$ForegroundServiceMetricsImpl>(this, _$identity);
}

abstract class _ForegroundServiceMetrics extends ForegroundServiceMetrics {
  const factory _ForegroundServiceMetrics(
      {required final bool foregroundServiceRunning,
      required final bool wakelockHeld}) = _$ForegroundServiceMetricsImpl;
  const _ForegroundServiceMetrics._() : super._();

  @override
  bool get foregroundServiceRunning;
  @override
  bool get wakelockHeld;

  /// Create a copy of ForegroundServiceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ForegroundServiceMetricsImplCopyWith<_$ForegroundServiceMetricsImpl>
      get copyWith => throw _privateConstructorUsedError;
}
