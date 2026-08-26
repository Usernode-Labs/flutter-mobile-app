import 'dart:io' show Platform;

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/legacy_zk_completion_api.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = LoggingService.instance.withTag('usernode/ZkPassportLaunch');
const _iosAlarmChannel = MethodChannel('com.usernode.app/alarm');
const _androidZkPassportChannel = MethodChannel('com.usernode.app/zkpassport');

const _androidMarketUrl = 'market://details?id=app.zkpassport.zkpassport';
const _androidWebUrl =
    'https://play.google.com/store/apps/details?id=app.zkpassport.zkpassport';
const _iosStoreUrl = 'https://apps.apple.com/us/app/zkpassport/id6477371975';

/// True when a backend completion response can never succeed on retry.
bool isTerminalZkCompletionRejection(Object? error) {
  return error is LegacyZkCompletionException &&
      error.statusCode >= 400 &&
      error.statusCode < 500 &&
      error.statusCode != 401 &&
      error.statusCode != 408 &&
      error.statusCode != 429;
}

/// Enforces outbox-before-registration ordering for optimistic completions.
Future<void> persistZkCompletionInOrder({
  required Future<void> Function() persistOutbox,
  required Future<void> Function() persistRegistration,
}) async {
  await persistOutbox();
  await persistRegistration();
}

class ZkPassportLaunchService {
  ZkPassportLaunchService();

  Future<bool> launchOrOpenStore(Uri launchUri) async {
    try {
      await _beginIosTransientBackgroundTask();
      final launched = await _launchApp(launchUri);
      if (launched) {
        _log.info('Launched zkPassport app');
        return true;
      }
      _log.warn('zkPassport launch failed, opening store');
    } catch (e) {
      _log.warn('zkPassport launch threw error: $e');
    }
    return openStoreListing();
  }

  Future<bool> isInstalled() async {
    if (Platform.isAndroid) {
      try {
        return await _androidZkPassportChannel.invokeMethod<bool>(
              'isInstalled',
            ) ??
            false;
      } catch (e) {
        _log.warn('zkPassport install check threw error: $e');
        return false;
      }
    }

    try {
      return canLaunchUrl(Uri.parse('zkpassport://'));
    } catch (e) {
      _log.warn('zkPassport install check threw error: $e');
      return false;
    }
  }

  Future<bool> _launchApp(Uri launchUri) async {
    if (Platform.isAndroid) {
      try {
        return await _androidZkPassportChannel.invokeMethod<bool>(
              'launch',
              {'url': launchUri.toString()},
            ) ??
            false;
      } catch (e) {
        _log.warn('Android zkPassport launch threw error: $e');
        return false;
      }
    }

    return launchUrl(
      launchUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _beginIosTransientBackgroundTask() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _iosAlarmChannel.invokeMethod<bool>('beginTransientBackgroundTask');
    } catch (e) {
      _log.warn('Failed to begin iOS transient background task: $e');
    }
  }

  Future<bool> openStoreListing() async {
    if (Platform.isAndroid) {
      final marketUri = Uri.parse(_androidMarketUrl);
      if (await launchUrl(marketUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
      final webUri = Uri.parse(_androidWebUrl);
      return launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
    if (Platform.isIOS) {
      final iosUri = Uri.parse(_iosStoreUrl);
      return launchUrl(iosUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

class ZkPassportRequestPolicy {
  // Demo mode: keep the zkPassport request bound to a fixed chain identifier.
  // This avoids coupling the integration flow to any chain/network config.
  static const String boundChainId = 'local';

  // Client-side timeout window for waiting/polling the zkPassport bridge.
  // This is NOT sent to zkPassport and does not affect proof validity.
  static const int clientSessionTimeoutSeconds = 1800;
}
