// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metrics_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MetricsPayload {
  EventMetrics get event => throw _privateConstructorUsedError;
  AppMetricsGroup get app => throw _privateConstructorUsedError;
  NodeMetricsGroup get node => throw _privateConstructorUsedError;

  /// Create a copy of MetricsPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MetricsPayloadCopyWith<MetricsPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetricsPayloadCopyWith<$Res> {
  factory $MetricsPayloadCopyWith(
          MetricsPayload value, $Res Function(MetricsPayload) then) =
      _$MetricsPayloadCopyWithImpl<$Res, MetricsPayload>;
  @useResult
  $Res call({EventMetrics event, AppMetricsGroup app, NodeMetricsGroup node});

  $EventMetricsCopyWith<$Res> get event;
  $AppMetricsGroupCopyWith<$Res> get app;
  $NodeMetricsGroupCopyWith<$Res> get node;
}

/// @nodoc
class _$MetricsPayloadCopyWithImpl<$Res, $Val extends MetricsPayload>
    implements $MetricsPayloadCopyWith<$Res> {
  _$MetricsPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MetricsPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? event = null,
    Object? app = null,
    Object? node = null,
  }) {
    return _then(_value.copyWith(
      event: null == event
          ? _value.event
          : event // ignore: cast_nullable_to_non_nullable
              as EventMetrics,
      app: null == app
          ? _value.app
          : app // ignore: cast_nullable_to_non_nullable
              as AppMetricsGroup,
      node: null == node
          ? _value.node
          : node // ignore: cast_nullable_to_non_nullable
              as NodeMetricsGroup,
    ) as $Val);
  }

  /// Create a copy of MetricsPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EventMetricsCopyWith<$Res> get event {
    return $EventMetricsCopyWith<$Res>(_value.event, (value) {
      return _then(_value.copyWith(event: value) as $Val);
    });
  }

  /// Create a copy of MetricsPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppMetricsGroupCopyWith<$Res> get app {
    return $AppMetricsGroupCopyWith<$Res>(_value.app, (value) {
      return _then(_value.copyWith(app: value) as $Val);
    });
  }

  /// Create a copy of MetricsPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NodeMetricsGroupCopyWith<$Res> get node {
    return $NodeMetricsGroupCopyWith<$Res>(_value.node, (value) {
      return _then(_value.copyWith(node: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MetricsPayloadImplCopyWith<$Res>
    implements $MetricsPayloadCopyWith<$Res> {
  factory _$$MetricsPayloadImplCopyWith(_$MetricsPayloadImpl value,
          $Res Function(_$MetricsPayloadImpl) then) =
      __$$MetricsPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({EventMetrics event, AppMetricsGroup app, NodeMetricsGroup node});

  @override
  $EventMetricsCopyWith<$Res> get event;
  @override
  $AppMetricsGroupCopyWith<$Res> get app;
  @override
  $NodeMetricsGroupCopyWith<$Res> get node;
}

/// @nodoc
class __$$MetricsPayloadImplCopyWithImpl<$Res>
    extends _$MetricsPayloadCopyWithImpl<$Res, _$MetricsPayloadImpl>
    implements _$$MetricsPayloadImplCopyWith<$Res> {
  __$$MetricsPayloadImplCopyWithImpl(
      _$MetricsPayloadImpl _value, $Res Function(_$MetricsPayloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of MetricsPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? event = null,
    Object? app = null,
    Object? node = null,
  }) {
    return _then(_$MetricsPayloadImpl(
      event: null == event
          ? _value.event
          : event // ignore: cast_nullable_to_non_nullable
              as EventMetrics,
      app: null == app
          ? _value.app
          : app // ignore: cast_nullable_to_non_nullable
              as AppMetricsGroup,
      node: null == node
          ? _value.node
          : node // ignore: cast_nullable_to_non_nullable
              as NodeMetricsGroup,
    ));
  }
}

/// @nodoc

class _$MetricsPayloadImpl extends _MetricsPayload {
  const _$MetricsPayloadImpl(
      {required this.event, required this.app, required this.node})
      : super._();

  @override
  final EventMetrics event;
  @override
  final AppMetricsGroup app;
  @override
  final NodeMetricsGroup node;

  @override
  String toString() {
    return 'MetricsPayload(event: $event, app: $app, node: $node)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetricsPayloadImpl &&
            (identical(other.event, event) || other.event == event) &&
            (identical(other.app, app) || other.app == app) &&
            (identical(other.node, node) || other.node == node));
  }

  @override
  int get hashCode => Object.hash(runtimeType, event, app, node);

  /// Create a copy of MetricsPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetricsPayloadImplCopyWith<_$MetricsPayloadImpl> get copyWith =>
      __$$MetricsPayloadImplCopyWithImpl<_$MetricsPayloadImpl>(
          this, _$identity);
}

abstract class _MetricsPayload extends MetricsPayload {
  const factory _MetricsPayload(
      {required final EventMetrics event,
      required final AppMetricsGroup app,
      required final NodeMetricsGroup node}) = _$MetricsPayloadImpl;
  const _MetricsPayload._() : super._();

  @override
  EventMetrics get event;
  @override
  AppMetricsGroup get app;
  @override
  NodeMetricsGroup get node;

  /// Create a copy of MetricsPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetricsPayloadImplCopyWith<_$MetricsPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AppMetricsGroup {
  RuntimeMetrics get runtime => throw _privateConstructorUsedError;
  PlatformMetrics? get platform => throw _privateConstructorUsedError;
  DeviceMetrics? get device => throw _privateConstructorUsedError;
  BatteryMetrics? get battery => throw _privateConstructorUsedError;
  NetworkMetrics? get network => throw _privateConstructorUsedError;
  PermissionsMetrics? get permissions => throw _privateConstructorUsedError;
  ForegroundServiceMetrics? get foregroundService =>
      throw _privateConstructorUsedError;

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppMetricsGroupCopyWith<AppMetricsGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppMetricsGroupCopyWith<$Res> {
  factory $AppMetricsGroupCopyWith(
          AppMetricsGroup value, $Res Function(AppMetricsGroup) then) =
      _$AppMetricsGroupCopyWithImpl<$Res, AppMetricsGroup>;
  @useResult
  $Res call(
      {RuntimeMetrics runtime,
      PlatformMetrics? platform,
      DeviceMetrics? device,
      BatteryMetrics? battery,
      NetworkMetrics? network,
      PermissionsMetrics? permissions,
      ForegroundServiceMetrics? foregroundService});

  $RuntimeMetricsCopyWith<$Res> get runtime;
  $PlatformMetricsCopyWith<$Res>? get platform;
  $DeviceMetricsCopyWith<$Res>? get device;
  $BatteryMetricsCopyWith<$Res>? get battery;
  $NetworkMetricsCopyWith<$Res>? get network;
  $PermissionsMetricsCopyWith<$Res>? get permissions;
  $ForegroundServiceMetricsCopyWith<$Res>? get foregroundService;
}

/// @nodoc
class _$AppMetricsGroupCopyWithImpl<$Res, $Val extends AppMetricsGroup>
    implements $AppMetricsGroupCopyWith<$Res> {
  _$AppMetricsGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? runtime = null,
    Object? platform = freezed,
    Object? device = freezed,
    Object? battery = freezed,
    Object? network = freezed,
    Object? permissions = freezed,
    Object? foregroundService = freezed,
  }) {
    return _then(_value.copyWith(
      runtime: null == runtime
          ? _value.runtime
          : runtime // ignore: cast_nullable_to_non_nullable
              as RuntimeMetrics,
      platform: freezed == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as PlatformMetrics?,
      device: freezed == device
          ? _value.device
          : device // ignore: cast_nullable_to_non_nullable
              as DeviceMetrics?,
      battery: freezed == battery
          ? _value.battery
          : battery // ignore: cast_nullable_to_non_nullable
              as BatteryMetrics?,
      network: freezed == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as NetworkMetrics?,
      permissions: freezed == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as PermissionsMetrics?,
      foregroundService: freezed == foregroundService
          ? _value.foregroundService
          : foregroundService // ignore: cast_nullable_to_non_nullable
              as ForegroundServiceMetrics?,
    ) as $Val);
  }

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RuntimeMetricsCopyWith<$Res> get runtime {
    return $RuntimeMetricsCopyWith<$Res>(_value.runtime, (value) {
      return _then(_value.copyWith(runtime: value) as $Val);
    });
  }

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PlatformMetricsCopyWith<$Res>? get platform {
    if (_value.platform == null) {
      return null;
    }

    return $PlatformMetricsCopyWith<$Res>(_value.platform!, (value) {
      return _then(_value.copyWith(platform: value) as $Val);
    });
  }

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeviceMetricsCopyWith<$Res>? get device {
    if (_value.device == null) {
      return null;
    }

    return $DeviceMetricsCopyWith<$Res>(_value.device!, (value) {
      return _then(_value.copyWith(device: value) as $Val);
    });
  }

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BatteryMetricsCopyWith<$Res>? get battery {
    if (_value.battery == null) {
      return null;
    }

    return $BatteryMetricsCopyWith<$Res>(_value.battery!, (value) {
      return _then(_value.copyWith(battery: value) as $Val);
    });
  }

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NetworkMetricsCopyWith<$Res>? get network {
    if (_value.network == null) {
      return null;
    }

    return $NetworkMetricsCopyWith<$Res>(_value.network!, (value) {
      return _then(_value.copyWith(network: value) as $Val);
    });
  }

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PermissionsMetricsCopyWith<$Res>? get permissions {
    if (_value.permissions == null) {
      return null;
    }

    return $PermissionsMetricsCopyWith<$Res>(_value.permissions!, (value) {
      return _then(_value.copyWith(permissions: value) as $Val);
    });
  }

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ForegroundServiceMetricsCopyWith<$Res>? get foregroundService {
    if (_value.foregroundService == null) {
      return null;
    }

    return $ForegroundServiceMetricsCopyWith<$Res>(_value.foregroundService!,
        (value) {
      return _then(_value.copyWith(foregroundService: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AppMetricsGroupImplCopyWith<$Res>
    implements $AppMetricsGroupCopyWith<$Res> {
  factory _$$AppMetricsGroupImplCopyWith(_$AppMetricsGroupImpl value,
          $Res Function(_$AppMetricsGroupImpl) then) =
      __$$AppMetricsGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {RuntimeMetrics runtime,
      PlatformMetrics? platform,
      DeviceMetrics? device,
      BatteryMetrics? battery,
      NetworkMetrics? network,
      PermissionsMetrics? permissions,
      ForegroundServiceMetrics? foregroundService});

  @override
  $RuntimeMetricsCopyWith<$Res> get runtime;
  @override
  $PlatformMetricsCopyWith<$Res>? get platform;
  @override
  $DeviceMetricsCopyWith<$Res>? get device;
  @override
  $BatteryMetricsCopyWith<$Res>? get battery;
  @override
  $NetworkMetricsCopyWith<$Res>? get network;
  @override
  $PermissionsMetricsCopyWith<$Res>? get permissions;
  @override
  $ForegroundServiceMetricsCopyWith<$Res>? get foregroundService;
}

/// @nodoc
class __$$AppMetricsGroupImplCopyWithImpl<$Res>
    extends _$AppMetricsGroupCopyWithImpl<$Res, _$AppMetricsGroupImpl>
    implements _$$AppMetricsGroupImplCopyWith<$Res> {
  __$$AppMetricsGroupImplCopyWithImpl(
      _$AppMetricsGroupImpl _value, $Res Function(_$AppMetricsGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? runtime = null,
    Object? platform = freezed,
    Object? device = freezed,
    Object? battery = freezed,
    Object? network = freezed,
    Object? permissions = freezed,
    Object? foregroundService = freezed,
  }) {
    return _then(_$AppMetricsGroupImpl(
      runtime: null == runtime
          ? _value.runtime
          : runtime // ignore: cast_nullable_to_non_nullable
              as RuntimeMetrics,
      platform: freezed == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as PlatformMetrics?,
      device: freezed == device
          ? _value.device
          : device // ignore: cast_nullable_to_non_nullable
              as DeviceMetrics?,
      battery: freezed == battery
          ? _value.battery
          : battery // ignore: cast_nullable_to_non_nullable
              as BatteryMetrics?,
      network: freezed == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as NetworkMetrics?,
      permissions: freezed == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as PermissionsMetrics?,
      foregroundService: freezed == foregroundService
          ? _value.foregroundService
          : foregroundService // ignore: cast_nullable_to_non_nullable
              as ForegroundServiceMetrics?,
    ));
  }
}

/// @nodoc

class _$AppMetricsGroupImpl extends _AppMetricsGroup {
  const _$AppMetricsGroupImpl(
      {required this.runtime,
      this.platform,
      this.device,
      this.battery,
      this.network,
      this.permissions,
      this.foregroundService})
      : super._();

  @override
  final RuntimeMetrics runtime;
  @override
  final PlatformMetrics? platform;
  @override
  final DeviceMetrics? device;
  @override
  final BatteryMetrics? battery;
  @override
  final NetworkMetrics? network;
  @override
  final PermissionsMetrics? permissions;
  @override
  final ForegroundServiceMetrics? foregroundService;

  @override
  String toString() {
    return 'AppMetricsGroup(runtime: $runtime, platform: $platform, device: $device, battery: $battery, network: $network, permissions: $permissions, foregroundService: $foregroundService)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppMetricsGroupImpl &&
            (identical(other.runtime, runtime) || other.runtime == runtime) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.device, device) || other.device == device) &&
            (identical(other.battery, battery) || other.battery == battery) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.permissions, permissions) ||
                other.permissions == permissions) &&
            (identical(other.foregroundService, foregroundService) ||
                other.foregroundService == foregroundService));
  }

  @override
  int get hashCode => Object.hash(runtimeType, runtime, platform, device,
      battery, network, permissions, foregroundService);

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppMetricsGroupImplCopyWith<_$AppMetricsGroupImpl> get copyWith =>
      __$$AppMetricsGroupImplCopyWithImpl<_$AppMetricsGroupImpl>(
          this, _$identity);
}

abstract class _AppMetricsGroup extends AppMetricsGroup {
  const factory _AppMetricsGroup(
          {required final RuntimeMetrics runtime,
          final PlatformMetrics? platform,
          final DeviceMetrics? device,
          final BatteryMetrics? battery,
          final NetworkMetrics? network,
          final PermissionsMetrics? permissions,
          final ForegroundServiceMetrics? foregroundService}) =
      _$AppMetricsGroupImpl;
  const _AppMetricsGroup._() : super._();

  @override
  RuntimeMetrics get runtime;
  @override
  PlatformMetrics? get platform;
  @override
  DeviceMetrics? get device;
  @override
  BatteryMetrics? get battery;
  @override
  NetworkMetrics? get network;
  @override
  PermissionsMetrics? get permissions;
  @override
  ForegroundServiceMetrics? get foregroundService;

  /// Create a copy of AppMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppMetricsGroupImplCopyWith<_$AppMetricsGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$NodeMetricsGroup {
  IdentityMetrics get identity => throw _privateConstructorUsedError;
  StatusMetrics? get status => throw _privateConstructorUsedError;
  ConsensusMetrics? get consensus => throw _privateConstructorUsedError;
  BlockchainMetrics? get blockchain => throw _privateConstructorUsedError;
  WalletMetrics? get wallet => throw _privateConstructorUsedError;
  List<PeerMetrics>? get peers => throw _privateConstructorUsedError;

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NodeMetricsGroupCopyWith<NodeMetricsGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NodeMetricsGroupCopyWith<$Res> {
  factory $NodeMetricsGroupCopyWith(
          NodeMetricsGroup value, $Res Function(NodeMetricsGroup) then) =
      _$NodeMetricsGroupCopyWithImpl<$Res, NodeMetricsGroup>;
  @useResult
  $Res call(
      {IdentityMetrics identity,
      StatusMetrics? status,
      ConsensusMetrics? consensus,
      BlockchainMetrics? blockchain,
      WalletMetrics? wallet,
      List<PeerMetrics>? peers});

  $IdentityMetricsCopyWith<$Res> get identity;
  $StatusMetricsCopyWith<$Res>? get status;
  $ConsensusMetricsCopyWith<$Res>? get consensus;
  $BlockchainMetricsCopyWith<$Res>? get blockchain;
  $WalletMetricsCopyWith<$Res>? get wallet;
}

/// @nodoc
class _$NodeMetricsGroupCopyWithImpl<$Res, $Val extends NodeMetricsGroup>
    implements $NodeMetricsGroupCopyWith<$Res> {
  _$NodeMetricsGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? identity = null,
    Object? status = freezed,
    Object? consensus = freezed,
    Object? blockchain = freezed,
    Object? wallet = freezed,
    Object? peers = freezed,
  }) {
    return _then(_value.copyWith(
      identity: null == identity
          ? _value.identity
          : identity // ignore: cast_nullable_to_non_nullable
              as IdentityMetrics,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as StatusMetrics?,
      consensus: freezed == consensus
          ? _value.consensus
          : consensus // ignore: cast_nullable_to_non_nullable
              as ConsensusMetrics?,
      blockchain: freezed == blockchain
          ? _value.blockchain
          : blockchain // ignore: cast_nullable_to_non_nullable
              as BlockchainMetrics?,
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as WalletMetrics?,
      peers: freezed == peers
          ? _value.peers
          : peers // ignore: cast_nullable_to_non_nullable
              as List<PeerMetrics>?,
    ) as $Val);
  }

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $IdentityMetricsCopyWith<$Res> get identity {
    return $IdentityMetricsCopyWith<$Res>(_value.identity, (value) {
      return _then(_value.copyWith(identity: value) as $Val);
    });
  }

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StatusMetricsCopyWith<$Res>? get status {
    if (_value.status == null) {
      return null;
    }

    return $StatusMetricsCopyWith<$Res>(_value.status!, (value) {
      return _then(_value.copyWith(status: value) as $Val);
    });
  }

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ConsensusMetricsCopyWith<$Res>? get consensus {
    if (_value.consensus == null) {
      return null;
    }

    return $ConsensusMetricsCopyWith<$Res>(_value.consensus!, (value) {
      return _then(_value.copyWith(consensus: value) as $Val);
    });
  }

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BlockchainMetricsCopyWith<$Res>? get blockchain {
    if (_value.blockchain == null) {
      return null;
    }

    return $BlockchainMetricsCopyWith<$Res>(_value.blockchain!, (value) {
      return _then(_value.copyWith(blockchain: value) as $Val);
    });
  }

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WalletMetricsCopyWith<$Res>? get wallet {
    if (_value.wallet == null) {
      return null;
    }

    return $WalletMetricsCopyWith<$Res>(_value.wallet!, (value) {
      return _then(_value.copyWith(wallet: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$NodeMetricsGroupImplCopyWith<$Res>
    implements $NodeMetricsGroupCopyWith<$Res> {
  factory _$$NodeMetricsGroupImplCopyWith(_$NodeMetricsGroupImpl value,
          $Res Function(_$NodeMetricsGroupImpl) then) =
      __$$NodeMetricsGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {IdentityMetrics identity,
      StatusMetrics? status,
      ConsensusMetrics? consensus,
      BlockchainMetrics? blockchain,
      WalletMetrics? wallet,
      List<PeerMetrics>? peers});

  @override
  $IdentityMetricsCopyWith<$Res> get identity;
  @override
  $StatusMetricsCopyWith<$Res>? get status;
  @override
  $ConsensusMetricsCopyWith<$Res>? get consensus;
  @override
  $BlockchainMetricsCopyWith<$Res>? get blockchain;
  @override
  $WalletMetricsCopyWith<$Res>? get wallet;
}

/// @nodoc
class __$$NodeMetricsGroupImplCopyWithImpl<$Res>
    extends _$NodeMetricsGroupCopyWithImpl<$Res, _$NodeMetricsGroupImpl>
    implements _$$NodeMetricsGroupImplCopyWith<$Res> {
  __$$NodeMetricsGroupImplCopyWithImpl(_$NodeMetricsGroupImpl _value,
      $Res Function(_$NodeMetricsGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? identity = null,
    Object? status = freezed,
    Object? consensus = freezed,
    Object? blockchain = freezed,
    Object? wallet = freezed,
    Object? peers = freezed,
  }) {
    return _then(_$NodeMetricsGroupImpl(
      identity: null == identity
          ? _value.identity
          : identity // ignore: cast_nullable_to_non_nullable
              as IdentityMetrics,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as StatusMetrics?,
      consensus: freezed == consensus
          ? _value.consensus
          : consensus // ignore: cast_nullable_to_non_nullable
              as ConsensusMetrics?,
      blockchain: freezed == blockchain
          ? _value.blockchain
          : blockchain // ignore: cast_nullable_to_non_nullable
              as BlockchainMetrics?,
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as WalletMetrics?,
      peers: freezed == peers
          ? _value._peers
          : peers // ignore: cast_nullable_to_non_nullable
              as List<PeerMetrics>?,
    ));
  }
}

/// @nodoc

class _$NodeMetricsGroupImpl extends _NodeMetricsGroup {
  const _$NodeMetricsGroupImpl(
      {required this.identity,
      this.status,
      this.consensus,
      this.blockchain,
      this.wallet,
      final List<PeerMetrics>? peers})
      : _peers = peers,
        super._();

  @override
  final IdentityMetrics identity;
  @override
  final StatusMetrics? status;
  @override
  final ConsensusMetrics? consensus;
  @override
  final BlockchainMetrics? blockchain;
  @override
  final WalletMetrics? wallet;
  final List<PeerMetrics>? _peers;
  @override
  List<PeerMetrics>? get peers {
    final value = _peers;
    if (value == null) return null;
    if (_peers is EqualUnmodifiableListView) return _peers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'NodeMetricsGroup(identity: $identity, status: $status, consensus: $consensus, blockchain: $blockchain, wallet: $wallet, peers: $peers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NodeMetricsGroupImpl &&
            (identical(other.identity, identity) ||
                other.identity == identity) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.consensus, consensus) ||
                other.consensus == consensus) &&
            (identical(other.blockchain, blockchain) ||
                other.blockchain == blockchain) &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            const DeepCollectionEquality().equals(other._peers, _peers));
  }

  @override
  int get hashCode => Object.hash(runtimeType, identity, status, consensus,
      blockchain, wallet, const DeepCollectionEquality().hash(_peers));

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NodeMetricsGroupImplCopyWith<_$NodeMetricsGroupImpl> get copyWith =>
      __$$NodeMetricsGroupImplCopyWithImpl<_$NodeMetricsGroupImpl>(
          this, _$identity);
}

abstract class _NodeMetricsGroup extends NodeMetricsGroup {
  const factory _NodeMetricsGroup(
      {required final IdentityMetrics identity,
      final StatusMetrics? status,
      final ConsensusMetrics? consensus,
      final BlockchainMetrics? blockchain,
      final WalletMetrics? wallet,
      final List<PeerMetrics>? peers}) = _$NodeMetricsGroupImpl;
  const _NodeMetricsGroup._() : super._();

  @override
  IdentityMetrics get identity;
  @override
  StatusMetrics? get status;
  @override
  ConsensusMetrics? get consensus;
  @override
  BlockchainMetrics? get blockchain;
  @override
  WalletMetrics? get wallet;
  @override
  List<PeerMetrics>? get peers;

  /// Create a copy of NodeMetricsGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NodeMetricsGroupImplCopyWith<_$NodeMetricsGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$EventMetrics {
  String get eventType => throw _privateConstructorUsedError;
  String get timestamp => throw _privateConstructorUsedError;
  Map<String, dynamic>? get eventData => throw _privateConstructorUsedError;

  /// Create a copy of EventMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EventMetricsCopyWith<EventMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EventMetricsCopyWith<$Res> {
  factory $EventMetricsCopyWith(
          EventMetrics value, $Res Function(EventMetrics) then) =
      _$EventMetricsCopyWithImpl<$Res, EventMetrics>;
  @useResult
  $Res call(
      {String eventType, String timestamp, Map<String, dynamic>? eventData});
}

/// @nodoc
class _$EventMetricsCopyWithImpl<$Res, $Val extends EventMetrics>
    implements $EventMetricsCopyWith<$Res> {
  _$EventMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EventMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventType = null,
    Object? timestamp = null,
    Object? eventData = freezed,
  }) {
    return _then(_value.copyWith(
      eventType: null == eventType
          ? _value.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as String,
      eventData: freezed == eventData
          ? _value.eventData
          : eventData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EventMetricsImplCopyWith<$Res>
    implements $EventMetricsCopyWith<$Res> {
  factory _$$EventMetricsImplCopyWith(
          _$EventMetricsImpl value, $Res Function(_$EventMetricsImpl) then) =
      __$$EventMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String eventType, String timestamp, Map<String, dynamic>? eventData});
}

/// @nodoc
class __$$EventMetricsImplCopyWithImpl<$Res>
    extends _$EventMetricsCopyWithImpl<$Res, _$EventMetricsImpl>
    implements _$$EventMetricsImplCopyWith<$Res> {
  __$$EventMetricsImplCopyWithImpl(
      _$EventMetricsImpl _value, $Res Function(_$EventMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of EventMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventType = null,
    Object? timestamp = null,
    Object? eventData = freezed,
  }) {
    return _then(_$EventMetricsImpl(
      eventType: null == eventType
          ? _value.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as String,
      eventData: freezed == eventData
          ? _value._eventData
          : eventData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc

class _$EventMetricsImpl extends _EventMetrics {
  const _$EventMetricsImpl(
      {required this.eventType,
      required this.timestamp,
      final Map<String, dynamic>? eventData})
      : _eventData = eventData,
        super._();

  @override
  final String eventType;
  @override
  final String timestamp;
  final Map<String, dynamic>? _eventData;
  @override
  Map<String, dynamic>? get eventData {
    final value = _eventData;
    if (value == null) return null;
    if (_eventData is EqualUnmodifiableMapView) return _eventData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'EventMetrics(eventType: $eventType, timestamp: $timestamp, eventData: $eventData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventMetricsImpl &&
            (identical(other.eventType, eventType) ||
                other.eventType == eventType) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            const DeepCollectionEquality()
                .equals(other._eventData, _eventData));
  }

  @override
  int get hashCode => Object.hash(runtimeType, eventType, timestamp,
      const DeepCollectionEquality().hash(_eventData));

  /// Create a copy of EventMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EventMetricsImplCopyWith<_$EventMetricsImpl> get copyWith =>
      __$$EventMetricsImplCopyWithImpl<_$EventMetricsImpl>(this, _$identity);
}

abstract class _EventMetrics extends EventMetrics {
  const factory _EventMetrics(
      {required final String eventType,
      required final String timestamp,
      final Map<String, dynamic>? eventData}) = _$EventMetricsImpl;
  const _EventMetrics._() : super._();

  @override
  String get eventType;
  @override
  String get timestamp;
  @override
  Map<String, dynamic>? get eventData;

  /// Create a copy of EventMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EventMetricsImplCopyWith<_$EventMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$IdentityMetrics {
  String? get peerId => throw _privateConstructorUsedError;
  String? get chainId => throw _privateConstructorUsedError;

  /// Create a copy of IdentityMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IdentityMetricsCopyWith<IdentityMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IdentityMetricsCopyWith<$Res> {
  factory $IdentityMetricsCopyWith(
          IdentityMetrics value, $Res Function(IdentityMetrics) then) =
      _$IdentityMetricsCopyWithImpl<$Res, IdentityMetrics>;
  @useResult
  $Res call({String? peerId, String? chainId});
}

/// @nodoc
class _$IdentityMetricsCopyWithImpl<$Res, $Val extends IdentityMetrics>
    implements $IdentityMetricsCopyWith<$Res> {
  _$IdentityMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of IdentityMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? peerId = freezed,
    Object? chainId = freezed,
  }) {
    return _then(_value.copyWith(
      peerId: freezed == peerId
          ? _value.peerId
          : peerId // ignore: cast_nullable_to_non_nullable
              as String?,
      chainId: freezed == chainId
          ? _value.chainId
          : chainId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$IdentityMetricsImplCopyWith<$Res>
    implements $IdentityMetricsCopyWith<$Res> {
  factory _$$IdentityMetricsImplCopyWith(_$IdentityMetricsImpl value,
          $Res Function(_$IdentityMetricsImpl) then) =
      __$$IdentityMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? peerId, String? chainId});
}

/// @nodoc
class __$$IdentityMetricsImplCopyWithImpl<$Res>
    extends _$IdentityMetricsCopyWithImpl<$Res, _$IdentityMetricsImpl>
    implements _$$IdentityMetricsImplCopyWith<$Res> {
  __$$IdentityMetricsImplCopyWithImpl(
      _$IdentityMetricsImpl _value, $Res Function(_$IdentityMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of IdentityMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? peerId = freezed,
    Object? chainId = freezed,
  }) {
    return _then(_$IdentityMetricsImpl(
      peerId: freezed == peerId
          ? _value.peerId
          : peerId // ignore: cast_nullable_to_non_nullable
              as String?,
      chainId: freezed == chainId
          ? _value.chainId
          : chainId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$IdentityMetricsImpl extends _IdentityMetrics {
  const _$IdentityMetricsImpl({this.peerId, this.chainId}) : super._();

  @override
  final String? peerId;
  @override
  final String? chainId;

  @override
  String toString() {
    return 'IdentityMetrics(peerId: $peerId, chainId: $chainId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IdentityMetricsImpl &&
            (identical(other.peerId, peerId) || other.peerId == peerId) &&
            (identical(other.chainId, chainId) || other.chainId == chainId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, peerId, chainId);

  /// Create a copy of IdentityMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IdentityMetricsImplCopyWith<_$IdentityMetricsImpl> get copyWith =>
      __$$IdentityMetricsImplCopyWithImpl<_$IdentityMetricsImpl>(
          this, _$identity);
}

abstract class _IdentityMetrics extends IdentityMetrics {
  const factory _IdentityMetrics(
      {final String? peerId, final String? chainId}) = _$IdentityMetricsImpl;
  const _IdentityMetrics._() : super._();

  @override
  String? get peerId;
  @override
  String? get chainId;

  /// Create a copy of IdentityMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IdentityMetricsImplCopyWith<_$IdentityMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

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
mixin _$PermissionsMetrics {
  bool get permissionExactAlarms => throw _privateConstructorUsedError;
  bool get permissionBatteryOptimizationExempt =>
      throw _privateConstructorUsedError;
  bool get exactAlarmsPermission => throw _privateConstructorUsedError;
  String get notificationPermission => throw _privateConstructorUsedError;

  /// Create a copy of PermissionsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PermissionsMetricsCopyWith<PermissionsMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PermissionsMetricsCopyWith<$Res> {
  factory $PermissionsMetricsCopyWith(
          PermissionsMetrics value, $Res Function(PermissionsMetrics) then) =
      _$PermissionsMetricsCopyWithImpl<$Res, PermissionsMetrics>;
  @useResult
  $Res call(
      {bool permissionExactAlarms,
      bool permissionBatteryOptimizationExempt,
      bool exactAlarmsPermission,
      String notificationPermission});
}

/// @nodoc
class _$PermissionsMetricsCopyWithImpl<$Res, $Val extends PermissionsMetrics>
    implements $PermissionsMetricsCopyWith<$Res> {
  _$PermissionsMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PermissionsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? permissionExactAlarms = null,
    Object? permissionBatteryOptimizationExempt = null,
    Object? exactAlarmsPermission = null,
    Object? notificationPermission = null,
  }) {
    return _then(_value.copyWith(
      permissionExactAlarms: null == permissionExactAlarms
          ? _value.permissionExactAlarms
          : permissionExactAlarms // ignore: cast_nullable_to_non_nullable
              as bool,
      permissionBatteryOptimizationExempt: null ==
              permissionBatteryOptimizationExempt
          ? _value.permissionBatteryOptimizationExempt
          : permissionBatteryOptimizationExempt // ignore: cast_nullable_to_non_nullable
              as bool,
      exactAlarmsPermission: null == exactAlarmsPermission
          ? _value.exactAlarmsPermission
          : exactAlarmsPermission // ignore: cast_nullable_to_non_nullable
              as bool,
      notificationPermission: null == notificationPermission
          ? _value.notificationPermission
          : notificationPermission // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PermissionsMetricsImplCopyWith<$Res>
    implements $PermissionsMetricsCopyWith<$Res> {
  factory _$$PermissionsMetricsImplCopyWith(_$PermissionsMetricsImpl value,
          $Res Function(_$PermissionsMetricsImpl) then) =
      __$$PermissionsMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool permissionExactAlarms,
      bool permissionBatteryOptimizationExempt,
      bool exactAlarmsPermission,
      String notificationPermission});
}

/// @nodoc
class __$$PermissionsMetricsImplCopyWithImpl<$Res>
    extends _$PermissionsMetricsCopyWithImpl<$Res, _$PermissionsMetricsImpl>
    implements _$$PermissionsMetricsImplCopyWith<$Res> {
  __$$PermissionsMetricsImplCopyWithImpl(_$PermissionsMetricsImpl _value,
      $Res Function(_$PermissionsMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of PermissionsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? permissionExactAlarms = null,
    Object? permissionBatteryOptimizationExempt = null,
    Object? exactAlarmsPermission = null,
    Object? notificationPermission = null,
  }) {
    return _then(_$PermissionsMetricsImpl(
      permissionExactAlarms: null == permissionExactAlarms
          ? _value.permissionExactAlarms
          : permissionExactAlarms // ignore: cast_nullable_to_non_nullable
              as bool,
      permissionBatteryOptimizationExempt: null ==
              permissionBatteryOptimizationExempt
          ? _value.permissionBatteryOptimizationExempt
          : permissionBatteryOptimizationExempt // ignore: cast_nullable_to_non_nullable
              as bool,
      exactAlarmsPermission: null == exactAlarmsPermission
          ? _value.exactAlarmsPermission
          : exactAlarmsPermission // ignore: cast_nullable_to_non_nullable
              as bool,
      notificationPermission: null == notificationPermission
          ? _value.notificationPermission
          : notificationPermission // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$PermissionsMetricsImpl extends _PermissionsMetrics {
  const _$PermissionsMetricsImpl(
      {required this.permissionExactAlarms,
      required this.permissionBatteryOptimizationExempt,
      required this.exactAlarmsPermission,
      required this.notificationPermission})
      : super._();

  @override
  final bool permissionExactAlarms;
  @override
  final bool permissionBatteryOptimizationExempt;
  @override
  final bool exactAlarmsPermission;
  @override
  final String notificationPermission;

  @override
  String toString() {
    return 'PermissionsMetrics(permissionExactAlarms: $permissionExactAlarms, permissionBatteryOptimizationExempt: $permissionBatteryOptimizationExempt, exactAlarmsPermission: $exactAlarmsPermission, notificationPermission: $notificationPermission)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PermissionsMetricsImpl &&
            (identical(other.permissionExactAlarms, permissionExactAlarms) ||
                other.permissionExactAlarms == permissionExactAlarms) &&
            (identical(other.permissionBatteryOptimizationExempt,
                    permissionBatteryOptimizationExempt) ||
                other.permissionBatteryOptimizationExempt ==
                    permissionBatteryOptimizationExempt) &&
            (identical(other.exactAlarmsPermission, exactAlarmsPermission) ||
                other.exactAlarmsPermission == exactAlarmsPermission) &&
            (identical(other.notificationPermission, notificationPermission) ||
                other.notificationPermission == notificationPermission));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      permissionExactAlarms,
      permissionBatteryOptimizationExempt,
      exactAlarmsPermission,
      notificationPermission);

  /// Create a copy of PermissionsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PermissionsMetricsImplCopyWith<_$PermissionsMetricsImpl> get copyWith =>
      __$$PermissionsMetricsImplCopyWithImpl<_$PermissionsMetricsImpl>(
          this, _$identity);
}

abstract class _PermissionsMetrics extends PermissionsMetrics {
  const factory _PermissionsMetrics(
      {required final bool permissionExactAlarms,
      required final bool permissionBatteryOptimizationExempt,
      required final bool exactAlarmsPermission,
      required final String notificationPermission}) = _$PermissionsMetricsImpl;
  const _PermissionsMetrics._() : super._();

  @override
  bool get permissionExactAlarms;
  @override
  bool get permissionBatteryOptimizationExempt;
  @override
  bool get exactAlarmsPermission;
  @override
  String get notificationPermission;

  /// Create a copy of PermissionsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PermissionsMetricsImplCopyWith<_$PermissionsMetricsImpl> get copyWith =>
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

/// @nodoc
mixin _$StatusMetrics {
  bool get nodeRunning => throw _privateConstructorUsedError;
  String get nodeState => throw _privateConstructorUsedError;
  String? get nodeSyncStatus => throw _privateConstructorUsedError;
  int? get nodeBestTipSlot => throw _privateConstructorUsedError;
  String? get nodeBestTipHash => throw _privateConstructorUsedError;
  int get nodeConnectedPeers => throw _privateConstructorUsedError;

  /// Create a copy of StatusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatusMetricsCopyWith<StatusMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatusMetricsCopyWith<$Res> {
  factory $StatusMetricsCopyWith(
          StatusMetrics value, $Res Function(StatusMetrics) then) =
      _$StatusMetricsCopyWithImpl<$Res, StatusMetrics>;
  @useResult
  $Res call(
      {bool nodeRunning,
      String nodeState,
      String? nodeSyncStatus,
      int? nodeBestTipSlot,
      String? nodeBestTipHash,
      int nodeConnectedPeers});
}

/// @nodoc
class _$StatusMetricsCopyWithImpl<$Res, $Val extends StatusMetrics>
    implements $StatusMetricsCopyWith<$Res> {
  _$StatusMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeRunning = null,
    Object? nodeState = null,
    Object? nodeSyncStatus = freezed,
    Object? nodeBestTipSlot = freezed,
    Object? nodeBestTipHash = freezed,
    Object? nodeConnectedPeers = null,
  }) {
    return _then(_value.copyWith(
      nodeRunning: null == nodeRunning
          ? _value.nodeRunning
          : nodeRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      nodeState: null == nodeState
          ? _value.nodeState
          : nodeState // ignore: cast_nullable_to_non_nullable
              as String,
      nodeSyncStatus: freezed == nodeSyncStatus
          ? _value.nodeSyncStatus
          : nodeSyncStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      nodeBestTipSlot: freezed == nodeBestTipSlot
          ? _value.nodeBestTipSlot
          : nodeBestTipSlot // ignore: cast_nullable_to_non_nullable
              as int?,
      nodeBestTipHash: freezed == nodeBestTipHash
          ? _value.nodeBestTipHash
          : nodeBestTipHash // ignore: cast_nullable_to_non_nullable
              as String?,
      nodeConnectedPeers: null == nodeConnectedPeers
          ? _value.nodeConnectedPeers
          : nodeConnectedPeers // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StatusMetricsImplCopyWith<$Res>
    implements $StatusMetricsCopyWith<$Res> {
  factory _$$StatusMetricsImplCopyWith(
          _$StatusMetricsImpl value, $Res Function(_$StatusMetricsImpl) then) =
      __$$StatusMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool nodeRunning,
      String nodeState,
      String? nodeSyncStatus,
      int? nodeBestTipSlot,
      String? nodeBestTipHash,
      int nodeConnectedPeers});
}

/// @nodoc
class __$$StatusMetricsImplCopyWithImpl<$Res>
    extends _$StatusMetricsCopyWithImpl<$Res, _$StatusMetricsImpl>
    implements _$$StatusMetricsImplCopyWith<$Res> {
  __$$StatusMetricsImplCopyWithImpl(
      _$StatusMetricsImpl _value, $Res Function(_$StatusMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of StatusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeRunning = null,
    Object? nodeState = null,
    Object? nodeSyncStatus = freezed,
    Object? nodeBestTipSlot = freezed,
    Object? nodeBestTipHash = freezed,
    Object? nodeConnectedPeers = null,
  }) {
    return _then(_$StatusMetricsImpl(
      nodeRunning: null == nodeRunning
          ? _value.nodeRunning
          : nodeRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      nodeState: null == nodeState
          ? _value.nodeState
          : nodeState // ignore: cast_nullable_to_non_nullable
              as String,
      nodeSyncStatus: freezed == nodeSyncStatus
          ? _value.nodeSyncStatus
          : nodeSyncStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      nodeBestTipSlot: freezed == nodeBestTipSlot
          ? _value.nodeBestTipSlot
          : nodeBestTipSlot // ignore: cast_nullable_to_non_nullable
              as int?,
      nodeBestTipHash: freezed == nodeBestTipHash
          ? _value.nodeBestTipHash
          : nodeBestTipHash // ignore: cast_nullable_to_non_nullable
              as String?,
      nodeConnectedPeers: null == nodeConnectedPeers
          ? _value.nodeConnectedPeers
          : nodeConnectedPeers // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$StatusMetricsImpl extends _StatusMetrics {
  const _$StatusMetricsImpl(
      {required this.nodeRunning,
      required this.nodeState,
      this.nodeSyncStatus,
      this.nodeBestTipSlot,
      this.nodeBestTipHash,
      required this.nodeConnectedPeers})
      : super._();

  @override
  final bool nodeRunning;
  @override
  final String nodeState;
  @override
  final String? nodeSyncStatus;
  @override
  final int? nodeBestTipSlot;
  @override
  final String? nodeBestTipHash;
  @override
  final int nodeConnectedPeers;

  @override
  String toString() {
    return 'StatusMetrics(nodeRunning: $nodeRunning, nodeState: $nodeState, nodeSyncStatus: $nodeSyncStatus, nodeBestTipSlot: $nodeBestTipSlot, nodeBestTipHash: $nodeBestTipHash, nodeConnectedPeers: $nodeConnectedPeers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatusMetricsImpl &&
            (identical(other.nodeRunning, nodeRunning) ||
                other.nodeRunning == nodeRunning) &&
            (identical(other.nodeState, nodeState) ||
                other.nodeState == nodeState) &&
            (identical(other.nodeSyncStatus, nodeSyncStatus) ||
                other.nodeSyncStatus == nodeSyncStatus) &&
            (identical(other.nodeBestTipSlot, nodeBestTipSlot) ||
                other.nodeBestTipSlot == nodeBestTipSlot) &&
            (identical(other.nodeBestTipHash, nodeBestTipHash) ||
                other.nodeBestTipHash == nodeBestTipHash) &&
            (identical(other.nodeConnectedPeers, nodeConnectedPeers) ||
                other.nodeConnectedPeers == nodeConnectedPeers));
  }

  @override
  int get hashCode => Object.hash(runtimeType, nodeRunning, nodeState,
      nodeSyncStatus, nodeBestTipSlot, nodeBestTipHash, nodeConnectedPeers);

  /// Create a copy of StatusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatusMetricsImplCopyWith<_$StatusMetricsImpl> get copyWith =>
      __$$StatusMetricsImplCopyWithImpl<_$StatusMetricsImpl>(this, _$identity);
}

abstract class _StatusMetrics extends StatusMetrics {
  const factory _StatusMetrics(
      {required final bool nodeRunning,
      required final String nodeState,
      final String? nodeSyncStatus,
      final int? nodeBestTipSlot,
      final String? nodeBestTipHash,
      required final int nodeConnectedPeers}) = _$StatusMetricsImpl;
  const _StatusMetrics._() : super._();

  @override
  bool get nodeRunning;
  @override
  String get nodeState;
  @override
  String? get nodeSyncStatus;
  @override
  int? get nodeBestTipSlot;
  @override
  String? get nodeBestTipHash;
  @override
  int get nodeConnectedPeers;

  /// Create a copy of StatusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatusMetricsImplCopyWith<_$StatusMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ConsensusMetrics {
  int? get currentEpoch => throw _privateConstructorUsedError;
  int? get currentGlobalSlot => throw _privateConstructorUsedError;
  int? get currentEpochWonSlots => throw _privateConstructorUsedError;
  int? get currentEpochProduced => throw _privateConstructorUsedError;
  int? get currentEpochFailed => throw _privateConstructorUsedError;
  int? get totalWonSlots => throw _privateConstructorUsedError;
  int? get totalBlocksProduced => throw _privateConstructorUsedError;
  int? get totalBlocksFailed => throw _privateConstructorUsedError;
  int? get evaluatedCurrentEpoch => throw _privateConstructorUsedError;
  String? get currentEpochVrfEvaluationStatus =>
      throw _privateConstructorUsedError;
  String? get nextEpochVrfEvaluationStatus =>
      throw _privateConstructorUsedError;
  double? get bpSuccessRate => throw _privateConstructorUsedError;

  /// Create a copy of ConsensusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConsensusMetricsCopyWith<ConsensusMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConsensusMetricsCopyWith<$Res> {
  factory $ConsensusMetricsCopyWith(
          ConsensusMetrics value, $Res Function(ConsensusMetrics) then) =
      _$ConsensusMetricsCopyWithImpl<$Res, ConsensusMetrics>;
  @useResult
  $Res call(
      {int? currentEpoch,
      int? currentGlobalSlot,
      int? currentEpochWonSlots,
      int? currentEpochProduced,
      int? currentEpochFailed,
      int? totalWonSlots,
      int? totalBlocksProduced,
      int? totalBlocksFailed,
      int? evaluatedCurrentEpoch,
      String? currentEpochVrfEvaluationStatus,
      String? nextEpochVrfEvaluationStatus,
      double? bpSuccessRate});
}

/// @nodoc
class _$ConsensusMetricsCopyWithImpl<$Res, $Val extends ConsensusMetrics>
    implements $ConsensusMetricsCopyWith<$Res> {
  _$ConsensusMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConsensusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentEpoch = freezed,
    Object? currentGlobalSlot = freezed,
    Object? currentEpochWonSlots = freezed,
    Object? currentEpochProduced = freezed,
    Object? currentEpochFailed = freezed,
    Object? totalWonSlots = freezed,
    Object? totalBlocksProduced = freezed,
    Object? totalBlocksFailed = freezed,
    Object? evaluatedCurrentEpoch = freezed,
    Object? currentEpochVrfEvaluationStatus = freezed,
    Object? nextEpochVrfEvaluationStatus = freezed,
    Object? bpSuccessRate = freezed,
  }) {
    return _then(_value.copyWith(
      currentEpoch: freezed == currentEpoch
          ? _value.currentEpoch
          : currentEpoch // ignore: cast_nullable_to_non_nullable
              as int?,
      currentGlobalSlot: freezed == currentGlobalSlot
          ? _value.currentGlobalSlot
          : currentGlobalSlot // ignore: cast_nullable_to_non_nullable
              as int?,
      currentEpochWonSlots: freezed == currentEpochWonSlots
          ? _value.currentEpochWonSlots
          : currentEpochWonSlots // ignore: cast_nullable_to_non_nullable
              as int?,
      currentEpochProduced: freezed == currentEpochProduced
          ? _value.currentEpochProduced
          : currentEpochProduced // ignore: cast_nullable_to_non_nullable
              as int?,
      currentEpochFailed: freezed == currentEpochFailed
          ? _value.currentEpochFailed
          : currentEpochFailed // ignore: cast_nullable_to_non_nullable
              as int?,
      totalWonSlots: freezed == totalWonSlots
          ? _value.totalWonSlots
          : totalWonSlots // ignore: cast_nullable_to_non_nullable
              as int?,
      totalBlocksProduced: freezed == totalBlocksProduced
          ? _value.totalBlocksProduced
          : totalBlocksProduced // ignore: cast_nullable_to_non_nullable
              as int?,
      totalBlocksFailed: freezed == totalBlocksFailed
          ? _value.totalBlocksFailed
          : totalBlocksFailed // ignore: cast_nullable_to_non_nullable
              as int?,
      evaluatedCurrentEpoch: freezed == evaluatedCurrentEpoch
          ? _value.evaluatedCurrentEpoch
          : evaluatedCurrentEpoch // ignore: cast_nullable_to_non_nullable
              as int?,
      currentEpochVrfEvaluationStatus: freezed ==
              currentEpochVrfEvaluationStatus
          ? _value.currentEpochVrfEvaluationStatus
          : currentEpochVrfEvaluationStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      nextEpochVrfEvaluationStatus: freezed == nextEpochVrfEvaluationStatus
          ? _value.nextEpochVrfEvaluationStatus
          : nextEpochVrfEvaluationStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      bpSuccessRate: freezed == bpSuccessRate
          ? _value.bpSuccessRate
          : bpSuccessRate // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ConsensusMetricsImplCopyWith<$Res>
    implements $ConsensusMetricsCopyWith<$Res> {
  factory _$$ConsensusMetricsImplCopyWith(_$ConsensusMetricsImpl value,
          $Res Function(_$ConsensusMetricsImpl) then) =
      __$$ConsensusMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? currentEpoch,
      int? currentGlobalSlot,
      int? currentEpochWonSlots,
      int? currentEpochProduced,
      int? currentEpochFailed,
      int? totalWonSlots,
      int? totalBlocksProduced,
      int? totalBlocksFailed,
      int? evaluatedCurrentEpoch,
      String? currentEpochVrfEvaluationStatus,
      String? nextEpochVrfEvaluationStatus,
      double? bpSuccessRate});
}

/// @nodoc
class __$$ConsensusMetricsImplCopyWithImpl<$Res>
    extends _$ConsensusMetricsCopyWithImpl<$Res, _$ConsensusMetricsImpl>
    implements _$$ConsensusMetricsImplCopyWith<$Res> {
  __$$ConsensusMetricsImplCopyWithImpl(_$ConsensusMetricsImpl _value,
      $Res Function(_$ConsensusMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of ConsensusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentEpoch = freezed,
    Object? currentGlobalSlot = freezed,
    Object? currentEpochWonSlots = freezed,
    Object? currentEpochProduced = freezed,
    Object? currentEpochFailed = freezed,
    Object? totalWonSlots = freezed,
    Object? totalBlocksProduced = freezed,
    Object? totalBlocksFailed = freezed,
    Object? evaluatedCurrentEpoch = freezed,
    Object? currentEpochVrfEvaluationStatus = freezed,
    Object? nextEpochVrfEvaluationStatus = freezed,
    Object? bpSuccessRate = freezed,
  }) {
    return _then(_$ConsensusMetricsImpl(
      currentEpoch: freezed == currentEpoch
          ? _value.currentEpoch
          : currentEpoch // ignore: cast_nullable_to_non_nullable
              as int?,
      currentGlobalSlot: freezed == currentGlobalSlot
          ? _value.currentGlobalSlot
          : currentGlobalSlot // ignore: cast_nullable_to_non_nullable
              as int?,
      currentEpochWonSlots: freezed == currentEpochWonSlots
          ? _value.currentEpochWonSlots
          : currentEpochWonSlots // ignore: cast_nullable_to_non_nullable
              as int?,
      currentEpochProduced: freezed == currentEpochProduced
          ? _value.currentEpochProduced
          : currentEpochProduced // ignore: cast_nullable_to_non_nullable
              as int?,
      currentEpochFailed: freezed == currentEpochFailed
          ? _value.currentEpochFailed
          : currentEpochFailed // ignore: cast_nullable_to_non_nullable
              as int?,
      totalWonSlots: freezed == totalWonSlots
          ? _value.totalWonSlots
          : totalWonSlots // ignore: cast_nullable_to_non_nullable
              as int?,
      totalBlocksProduced: freezed == totalBlocksProduced
          ? _value.totalBlocksProduced
          : totalBlocksProduced // ignore: cast_nullable_to_non_nullable
              as int?,
      totalBlocksFailed: freezed == totalBlocksFailed
          ? _value.totalBlocksFailed
          : totalBlocksFailed // ignore: cast_nullable_to_non_nullable
              as int?,
      evaluatedCurrentEpoch: freezed == evaluatedCurrentEpoch
          ? _value.evaluatedCurrentEpoch
          : evaluatedCurrentEpoch // ignore: cast_nullable_to_non_nullable
              as int?,
      currentEpochVrfEvaluationStatus: freezed ==
              currentEpochVrfEvaluationStatus
          ? _value.currentEpochVrfEvaluationStatus
          : currentEpochVrfEvaluationStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      nextEpochVrfEvaluationStatus: freezed == nextEpochVrfEvaluationStatus
          ? _value.nextEpochVrfEvaluationStatus
          : nextEpochVrfEvaluationStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      bpSuccessRate: freezed == bpSuccessRate
          ? _value.bpSuccessRate
          : bpSuccessRate // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc

class _$ConsensusMetricsImpl extends _ConsensusMetrics {
  const _$ConsensusMetricsImpl(
      {this.currentEpoch,
      this.currentGlobalSlot,
      this.currentEpochWonSlots,
      this.currentEpochProduced,
      this.currentEpochFailed,
      this.totalWonSlots,
      this.totalBlocksProduced,
      this.totalBlocksFailed,
      this.evaluatedCurrentEpoch,
      this.currentEpochVrfEvaluationStatus,
      this.nextEpochVrfEvaluationStatus,
      this.bpSuccessRate})
      : super._();

  @override
  final int? currentEpoch;
  @override
  final int? currentGlobalSlot;
  @override
  final int? currentEpochWonSlots;
  @override
  final int? currentEpochProduced;
  @override
  final int? currentEpochFailed;
  @override
  final int? totalWonSlots;
  @override
  final int? totalBlocksProduced;
  @override
  final int? totalBlocksFailed;
  @override
  final int? evaluatedCurrentEpoch;
  @override
  final String? currentEpochVrfEvaluationStatus;
  @override
  final String? nextEpochVrfEvaluationStatus;
  @override
  final double? bpSuccessRate;

  @override
  String toString() {
    return 'ConsensusMetrics(currentEpoch: $currentEpoch, currentGlobalSlot: $currentGlobalSlot, currentEpochWonSlots: $currentEpochWonSlots, currentEpochProduced: $currentEpochProduced, currentEpochFailed: $currentEpochFailed, totalWonSlots: $totalWonSlots, totalBlocksProduced: $totalBlocksProduced, totalBlocksFailed: $totalBlocksFailed, evaluatedCurrentEpoch: $evaluatedCurrentEpoch, currentEpochVrfEvaluationStatus: $currentEpochVrfEvaluationStatus, nextEpochVrfEvaluationStatus: $nextEpochVrfEvaluationStatus, bpSuccessRate: $bpSuccessRate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConsensusMetricsImpl &&
            (identical(other.currentEpoch, currentEpoch) ||
                other.currentEpoch == currentEpoch) &&
            (identical(other.currentGlobalSlot, currentGlobalSlot) ||
                other.currentGlobalSlot == currentGlobalSlot) &&
            (identical(other.currentEpochWonSlots, currentEpochWonSlots) ||
                other.currentEpochWonSlots == currentEpochWonSlots) &&
            (identical(other.currentEpochProduced, currentEpochProduced) ||
                other.currentEpochProduced == currentEpochProduced) &&
            (identical(other.currentEpochFailed, currentEpochFailed) ||
                other.currentEpochFailed == currentEpochFailed) &&
            (identical(other.totalWonSlots, totalWonSlots) ||
                other.totalWonSlots == totalWonSlots) &&
            (identical(other.totalBlocksProduced, totalBlocksProduced) ||
                other.totalBlocksProduced == totalBlocksProduced) &&
            (identical(other.totalBlocksFailed, totalBlocksFailed) ||
                other.totalBlocksFailed == totalBlocksFailed) &&
            (identical(other.evaluatedCurrentEpoch, evaluatedCurrentEpoch) ||
                other.evaluatedCurrentEpoch == evaluatedCurrentEpoch) &&
            (identical(other.currentEpochVrfEvaluationStatus,
                    currentEpochVrfEvaluationStatus) ||
                other.currentEpochVrfEvaluationStatus ==
                    currentEpochVrfEvaluationStatus) &&
            (identical(other.nextEpochVrfEvaluationStatus,
                    nextEpochVrfEvaluationStatus) ||
                other.nextEpochVrfEvaluationStatus ==
                    nextEpochVrfEvaluationStatus) &&
            (identical(other.bpSuccessRate, bpSuccessRate) ||
                other.bpSuccessRate == bpSuccessRate));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      currentEpoch,
      currentGlobalSlot,
      currentEpochWonSlots,
      currentEpochProduced,
      currentEpochFailed,
      totalWonSlots,
      totalBlocksProduced,
      totalBlocksFailed,
      evaluatedCurrentEpoch,
      currentEpochVrfEvaluationStatus,
      nextEpochVrfEvaluationStatus,
      bpSuccessRate);

  /// Create a copy of ConsensusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConsensusMetricsImplCopyWith<_$ConsensusMetricsImpl> get copyWith =>
      __$$ConsensusMetricsImplCopyWithImpl<_$ConsensusMetricsImpl>(
          this, _$identity);
}

abstract class _ConsensusMetrics extends ConsensusMetrics {
  const factory _ConsensusMetrics(
      {final int? currentEpoch,
      final int? currentGlobalSlot,
      final int? currentEpochWonSlots,
      final int? currentEpochProduced,
      final int? currentEpochFailed,
      final int? totalWonSlots,
      final int? totalBlocksProduced,
      final int? totalBlocksFailed,
      final int? evaluatedCurrentEpoch,
      final String? currentEpochVrfEvaluationStatus,
      final String? nextEpochVrfEvaluationStatus,
      final double? bpSuccessRate}) = _$ConsensusMetricsImpl;
  const _ConsensusMetrics._() : super._();

  @override
  int? get currentEpoch;
  @override
  int? get currentGlobalSlot;
  @override
  int? get currentEpochWonSlots;
  @override
  int? get currentEpochProduced;
  @override
  int? get currentEpochFailed;
  @override
  int? get totalWonSlots;
  @override
  int? get totalBlocksProduced;
  @override
  int? get totalBlocksFailed;
  @override
  int? get evaluatedCurrentEpoch;
  @override
  String? get currentEpochVrfEvaluationStatus;
  @override
  String? get nextEpochVrfEvaluationStatus;
  @override
  double? get bpSuccessRate;

  /// Create a copy of ConsensusMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConsensusMetricsImplCopyWith<_$ConsensusMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BlockchainMetrics {
  int? get blockchainHeight => throw _privateConstructorUsedError;
  String? get blockchainLatestBlockHash => throw _privateConstructorUsedError;
  int? get blockchainLatestBlockSlot => throw _privateConstructorUsedError;
  String? get blockchainLatestBlockTimestamp =>
      throw _privateConstructorUsedError;

  /// Create a copy of BlockchainMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BlockchainMetricsCopyWith<BlockchainMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlockchainMetricsCopyWith<$Res> {
  factory $BlockchainMetricsCopyWith(
          BlockchainMetrics value, $Res Function(BlockchainMetrics) then) =
      _$BlockchainMetricsCopyWithImpl<$Res, BlockchainMetrics>;
  @useResult
  $Res call(
      {int? blockchainHeight,
      String? blockchainLatestBlockHash,
      int? blockchainLatestBlockSlot,
      String? blockchainLatestBlockTimestamp});
}

/// @nodoc
class _$BlockchainMetricsCopyWithImpl<$Res, $Val extends BlockchainMetrics>
    implements $BlockchainMetricsCopyWith<$Res> {
  _$BlockchainMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BlockchainMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? blockchainHeight = freezed,
    Object? blockchainLatestBlockHash = freezed,
    Object? blockchainLatestBlockSlot = freezed,
    Object? blockchainLatestBlockTimestamp = freezed,
  }) {
    return _then(_value.copyWith(
      blockchainHeight: freezed == blockchainHeight
          ? _value.blockchainHeight
          : blockchainHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      blockchainLatestBlockHash: freezed == blockchainLatestBlockHash
          ? _value.blockchainLatestBlockHash
          : blockchainLatestBlockHash // ignore: cast_nullable_to_non_nullable
              as String?,
      blockchainLatestBlockSlot: freezed == blockchainLatestBlockSlot
          ? _value.blockchainLatestBlockSlot
          : blockchainLatestBlockSlot // ignore: cast_nullable_to_non_nullable
              as int?,
      blockchainLatestBlockTimestamp: freezed == blockchainLatestBlockTimestamp
          ? _value.blockchainLatestBlockTimestamp
          : blockchainLatestBlockTimestamp // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BlockchainMetricsImplCopyWith<$Res>
    implements $BlockchainMetricsCopyWith<$Res> {
  factory _$$BlockchainMetricsImplCopyWith(_$BlockchainMetricsImpl value,
          $Res Function(_$BlockchainMetricsImpl) then) =
      __$$BlockchainMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? blockchainHeight,
      String? blockchainLatestBlockHash,
      int? blockchainLatestBlockSlot,
      String? blockchainLatestBlockTimestamp});
}

/// @nodoc
class __$$BlockchainMetricsImplCopyWithImpl<$Res>
    extends _$BlockchainMetricsCopyWithImpl<$Res, _$BlockchainMetricsImpl>
    implements _$$BlockchainMetricsImplCopyWith<$Res> {
  __$$BlockchainMetricsImplCopyWithImpl(_$BlockchainMetricsImpl _value,
      $Res Function(_$BlockchainMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of BlockchainMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? blockchainHeight = freezed,
    Object? blockchainLatestBlockHash = freezed,
    Object? blockchainLatestBlockSlot = freezed,
    Object? blockchainLatestBlockTimestamp = freezed,
  }) {
    return _then(_$BlockchainMetricsImpl(
      blockchainHeight: freezed == blockchainHeight
          ? _value.blockchainHeight
          : blockchainHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      blockchainLatestBlockHash: freezed == blockchainLatestBlockHash
          ? _value.blockchainLatestBlockHash
          : blockchainLatestBlockHash // ignore: cast_nullable_to_non_nullable
              as String?,
      blockchainLatestBlockSlot: freezed == blockchainLatestBlockSlot
          ? _value.blockchainLatestBlockSlot
          : blockchainLatestBlockSlot // ignore: cast_nullable_to_non_nullable
              as int?,
      blockchainLatestBlockTimestamp: freezed == blockchainLatestBlockTimestamp
          ? _value.blockchainLatestBlockTimestamp
          : blockchainLatestBlockTimestamp // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$BlockchainMetricsImpl extends _BlockchainMetrics {
  const _$BlockchainMetricsImpl(
      {this.blockchainHeight,
      this.blockchainLatestBlockHash,
      this.blockchainLatestBlockSlot,
      this.blockchainLatestBlockTimestamp})
      : super._();

  @override
  final int? blockchainHeight;
  @override
  final String? blockchainLatestBlockHash;
  @override
  final int? blockchainLatestBlockSlot;
  @override
  final String? blockchainLatestBlockTimestamp;

  @override
  String toString() {
    return 'BlockchainMetrics(blockchainHeight: $blockchainHeight, blockchainLatestBlockHash: $blockchainLatestBlockHash, blockchainLatestBlockSlot: $blockchainLatestBlockSlot, blockchainLatestBlockTimestamp: $blockchainLatestBlockTimestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlockchainMetricsImpl &&
            (identical(other.blockchainHeight, blockchainHeight) ||
                other.blockchainHeight == blockchainHeight) &&
            (identical(other.blockchainLatestBlockHash,
                    blockchainLatestBlockHash) ||
                other.blockchainLatestBlockHash == blockchainLatestBlockHash) &&
            (identical(other.blockchainLatestBlockSlot,
                    blockchainLatestBlockSlot) ||
                other.blockchainLatestBlockSlot == blockchainLatestBlockSlot) &&
            (identical(other.blockchainLatestBlockTimestamp,
                    blockchainLatestBlockTimestamp) ||
                other.blockchainLatestBlockTimestamp ==
                    blockchainLatestBlockTimestamp));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      blockchainHeight,
      blockchainLatestBlockHash,
      blockchainLatestBlockSlot,
      blockchainLatestBlockTimestamp);

  /// Create a copy of BlockchainMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlockchainMetricsImplCopyWith<_$BlockchainMetricsImpl> get copyWith =>
      __$$BlockchainMetricsImplCopyWithImpl<_$BlockchainMetricsImpl>(
          this, _$identity);
}

abstract class _BlockchainMetrics extends BlockchainMetrics {
  const factory _BlockchainMetrics(
      {final int? blockchainHeight,
      final String? blockchainLatestBlockHash,
      final int? blockchainLatestBlockSlot,
      final String? blockchainLatestBlockTimestamp}) = _$BlockchainMetricsImpl;
  const _BlockchainMetrics._() : super._();

  @override
  int? get blockchainHeight;
  @override
  String? get blockchainLatestBlockHash;
  @override
  int? get blockchainLatestBlockSlot;
  @override
  String? get blockchainLatestBlockTimestamp;

  /// Create a copy of BlockchainMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlockchainMetricsImplCopyWith<_$BlockchainMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$WalletMetrics {
  BigInt? get walletBalance => throw _privateConstructorUsedError;
  String? get walletAddress => throw _privateConstructorUsedError;

  /// Create a copy of WalletMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WalletMetricsCopyWith<WalletMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletMetricsCopyWith<$Res> {
  factory $WalletMetricsCopyWith(
          WalletMetrics value, $Res Function(WalletMetrics) then) =
      _$WalletMetricsCopyWithImpl<$Res, WalletMetrics>;
  @useResult
  $Res call({BigInt? walletBalance, String? walletAddress});
}

/// @nodoc
class _$WalletMetricsCopyWithImpl<$Res, $Val extends WalletMetrics>
    implements $WalletMetricsCopyWith<$Res> {
  _$WalletMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WalletMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? walletBalance = freezed,
    Object? walletAddress = freezed,
  }) {
    return _then(_value.copyWith(
      walletBalance: freezed == walletBalance
          ? _value.walletBalance
          : walletBalance // ignore: cast_nullable_to_non_nullable
              as BigInt?,
      walletAddress: freezed == walletAddress
          ? _value.walletAddress
          : walletAddress // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WalletMetricsImplCopyWith<$Res>
    implements $WalletMetricsCopyWith<$Res> {
  factory _$$WalletMetricsImplCopyWith(
          _$WalletMetricsImpl value, $Res Function(_$WalletMetricsImpl) then) =
      __$$WalletMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({BigInt? walletBalance, String? walletAddress});
}

/// @nodoc
class __$$WalletMetricsImplCopyWithImpl<$Res>
    extends _$WalletMetricsCopyWithImpl<$Res, _$WalletMetricsImpl>
    implements _$$WalletMetricsImplCopyWith<$Res> {
  __$$WalletMetricsImplCopyWithImpl(
      _$WalletMetricsImpl _value, $Res Function(_$WalletMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of WalletMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? walletBalance = freezed,
    Object? walletAddress = freezed,
  }) {
    return _then(_$WalletMetricsImpl(
      walletBalance: freezed == walletBalance
          ? _value.walletBalance
          : walletBalance // ignore: cast_nullable_to_non_nullable
              as BigInt?,
      walletAddress: freezed == walletAddress
          ? _value.walletAddress
          : walletAddress // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$WalletMetricsImpl extends _WalletMetrics {
  const _$WalletMetricsImpl({this.walletBalance, this.walletAddress})
      : super._();

  @override
  final BigInt? walletBalance;
  @override
  final String? walletAddress;

  @override
  String toString() {
    return 'WalletMetrics(walletBalance: $walletBalance, walletAddress: $walletAddress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletMetricsImpl &&
            (identical(other.walletBalance, walletBalance) ||
                other.walletBalance == walletBalance) &&
            (identical(other.walletAddress, walletAddress) ||
                other.walletAddress == walletAddress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, walletBalance, walletAddress);

  /// Create a copy of WalletMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletMetricsImplCopyWith<_$WalletMetricsImpl> get copyWith =>
      __$$WalletMetricsImplCopyWithImpl<_$WalletMetricsImpl>(this, _$identity);
}

abstract class _WalletMetrics extends WalletMetrics {
  const factory _WalletMetrics(
      {final BigInt? walletBalance,
      final String? walletAddress}) = _$WalletMetricsImpl;
  const _WalletMetrics._() : super._();

  @override
  BigInt? get walletBalance;
  @override
  String? get walletAddress;

  /// Create a copy of WalletMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WalletMetricsImplCopyWith<_$WalletMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PeerMetrics {
  String get peerId => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  String? get bestTip => throw _privateConstructorUsedError;
  int? get bestTipHeight => throw _privateConstructorUsedError;
  int? get bestTipGlobalSlot => throw _privateConstructorUsedError;
  int? get bestTipTimestamp => throw _privateConstructorUsedError;
  String get connectionStatus => throw _privateConstructorUsedError;
  String? get connectingDetails => throw _privateConstructorUsedError;
  bool get incoming => throw _privateConstructorUsedError;
  int get time => throw _privateConstructorUsedError;

  /// Create a copy of PeerMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PeerMetricsCopyWith<PeerMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PeerMetricsCopyWith<$Res> {
  factory $PeerMetricsCopyWith(
          PeerMetrics value, $Res Function(PeerMetrics) then) =
      _$PeerMetricsCopyWithImpl<$Res, PeerMetrics>;
  @useResult
  $Res call(
      {String peerId,
      String? address,
      String? bestTip,
      int? bestTipHeight,
      int? bestTipGlobalSlot,
      int? bestTipTimestamp,
      String connectionStatus,
      String? connectingDetails,
      bool incoming,
      int time});
}

/// @nodoc
class _$PeerMetricsCopyWithImpl<$Res, $Val extends PeerMetrics>
    implements $PeerMetricsCopyWith<$Res> {
  _$PeerMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PeerMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? peerId = null,
    Object? address = freezed,
    Object? bestTip = freezed,
    Object? bestTipHeight = freezed,
    Object? bestTipGlobalSlot = freezed,
    Object? bestTipTimestamp = freezed,
    Object? connectionStatus = null,
    Object? connectingDetails = freezed,
    Object? incoming = null,
    Object? time = null,
  }) {
    return _then(_value.copyWith(
      peerId: null == peerId
          ? _value.peerId
          : peerId // ignore: cast_nullable_to_non_nullable
              as String,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      bestTip: freezed == bestTip
          ? _value.bestTip
          : bestTip // ignore: cast_nullable_to_non_nullable
              as String?,
      bestTipHeight: freezed == bestTipHeight
          ? _value.bestTipHeight
          : bestTipHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      bestTipGlobalSlot: freezed == bestTipGlobalSlot
          ? _value.bestTipGlobalSlot
          : bestTipGlobalSlot // ignore: cast_nullable_to_non_nullable
              as int?,
      bestTipTimestamp: freezed == bestTipTimestamp
          ? _value.bestTipTimestamp
          : bestTipTimestamp // ignore: cast_nullable_to_non_nullable
              as int?,
      connectionStatus: null == connectionStatus
          ? _value.connectionStatus
          : connectionStatus // ignore: cast_nullable_to_non_nullable
              as String,
      connectingDetails: freezed == connectingDetails
          ? _value.connectingDetails
          : connectingDetails // ignore: cast_nullable_to_non_nullable
              as String?,
      incoming: null == incoming
          ? _value.incoming
          : incoming // ignore: cast_nullable_to_non_nullable
              as bool,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PeerMetricsImplCopyWith<$Res>
    implements $PeerMetricsCopyWith<$Res> {
  factory _$$PeerMetricsImplCopyWith(
          _$PeerMetricsImpl value, $Res Function(_$PeerMetricsImpl) then) =
      __$$PeerMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String peerId,
      String? address,
      String? bestTip,
      int? bestTipHeight,
      int? bestTipGlobalSlot,
      int? bestTipTimestamp,
      String connectionStatus,
      String? connectingDetails,
      bool incoming,
      int time});
}

/// @nodoc
class __$$PeerMetricsImplCopyWithImpl<$Res>
    extends _$PeerMetricsCopyWithImpl<$Res, _$PeerMetricsImpl>
    implements _$$PeerMetricsImplCopyWith<$Res> {
  __$$PeerMetricsImplCopyWithImpl(
      _$PeerMetricsImpl _value, $Res Function(_$PeerMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of PeerMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? peerId = null,
    Object? address = freezed,
    Object? bestTip = freezed,
    Object? bestTipHeight = freezed,
    Object? bestTipGlobalSlot = freezed,
    Object? bestTipTimestamp = freezed,
    Object? connectionStatus = null,
    Object? connectingDetails = freezed,
    Object? incoming = null,
    Object? time = null,
  }) {
    return _then(_$PeerMetricsImpl(
      peerId: null == peerId
          ? _value.peerId
          : peerId // ignore: cast_nullable_to_non_nullable
              as String,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      bestTip: freezed == bestTip
          ? _value.bestTip
          : bestTip // ignore: cast_nullable_to_non_nullable
              as String?,
      bestTipHeight: freezed == bestTipHeight
          ? _value.bestTipHeight
          : bestTipHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      bestTipGlobalSlot: freezed == bestTipGlobalSlot
          ? _value.bestTipGlobalSlot
          : bestTipGlobalSlot // ignore: cast_nullable_to_non_nullable
              as int?,
      bestTipTimestamp: freezed == bestTipTimestamp
          ? _value.bestTipTimestamp
          : bestTipTimestamp // ignore: cast_nullable_to_non_nullable
              as int?,
      connectionStatus: null == connectionStatus
          ? _value.connectionStatus
          : connectionStatus // ignore: cast_nullable_to_non_nullable
              as String,
      connectingDetails: freezed == connectingDetails
          ? _value.connectingDetails
          : connectingDetails // ignore: cast_nullable_to_non_nullable
              as String?,
      incoming: null == incoming
          ? _value.incoming
          : incoming // ignore: cast_nullable_to_non_nullable
              as bool,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$PeerMetricsImpl extends _PeerMetrics {
  const _$PeerMetricsImpl(
      {required this.peerId,
      this.address,
      this.bestTip,
      this.bestTipHeight,
      this.bestTipGlobalSlot,
      this.bestTipTimestamp,
      required this.connectionStatus,
      this.connectingDetails,
      required this.incoming,
      required this.time})
      : super._();

  @override
  final String peerId;
  @override
  final String? address;
  @override
  final String? bestTip;
  @override
  final int? bestTipHeight;
  @override
  final int? bestTipGlobalSlot;
  @override
  final int? bestTipTimestamp;
  @override
  final String connectionStatus;
  @override
  final String? connectingDetails;
  @override
  final bool incoming;
  @override
  final int time;

  @override
  String toString() {
    return 'PeerMetrics(peerId: $peerId, address: $address, bestTip: $bestTip, bestTipHeight: $bestTipHeight, bestTipGlobalSlot: $bestTipGlobalSlot, bestTipTimestamp: $bestTipTimestamp, connectionStatus: $connectionStatus, connectingDetails: $connectingDetails, incoming: $incoming, time: $time)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PeerMetricsImpl &&
            (identical(other.peerId, peerId) || other.peerId == peerId) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.bestTip, bestTip) || other.bestTip == bestTip) &&
            (identical(other.bestTipHeight, bestTipHeight) ||
                other.bestTipHeight == bestTipHeight) &&
            (identical(other.bestTipGlobalSlot, bestTipGlobalSlot) ||
                other.bestTipGlobalSlot == bestTipGlobalSlot) &&
            (identical(other.bestTipTimestamp, bestTipTimestamp) ||
                other.bestTipTimestamp == bestTipTimestamp) &&
            (identical(other.connectionStatus, connectionStatus) ||
                other.connectionStatus == connectionStatus) &&
            (identical(other.connectingDetails, connectingDetails) ||
                other.connectingDetails == connectingDetails) &&
            (identical(other.incoming, incoming) ||
                other.incoming == incoming) &&
            (identical(other.time, time) || other.time == time));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      peerId,
      address,
      bestTip,
      bestTipHeight,
      bestTipGlobalSlot,
      bestTipTimestamp,
      connectionStatus,
      connectingDetails,
      incoming,
      time);

  /// Create a copy of PeerMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PeerMetricsImplCopyWith<_$PeerMetricsImpl> get copyWith =>
      __$$PeerMetricsImplCopyWithImpl<_$PeerMetricsImpl>(this, _$identity);
}

abstract class _PeerMetrics extends PeerMetrics {
  const factory _PeerMetrics(
      {required final String peerId,
      final String? address,
      final String? bestTip,
      final int? bestTipHeight,
      final int? bestTipGlobalSlot,
      final int? bestTipTimestamp,
      required final String connectionStatus,
      final String? connectingDetails,
      required final bool incoming,
      required final int time}) = _$PeerMetricsImpl;
  const _PeerMetrics._() : super._();

  @override
  String get peerId;
  @override
  String? get address;
  @override
  String? get bestTip;
  @override
  int? get bestTipHeight;
  @override
  int? get bestTipGlobalSlot;
  @override
  int? get bestTipTimestamp;
  @override
  String get connectionStatus;
  @override
  String? get connectingDetails;
  @override
  bool get incoming;
  @override
  int get time;

  /// Create a copy of PeerMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PeerMetricsImplCopyWith<_$PeerMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
