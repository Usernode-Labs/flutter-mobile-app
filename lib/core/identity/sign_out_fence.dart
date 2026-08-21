import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

final _log = LoggingService.instance.withTag('usernode/SignOutFence');

/// The durable "a sign-out started and has not finished" journal.
///
/// Sign-out retires the bearer and the identity namespace as a PAIR: a boot
/// that finds one gone and the other present resolves the previous user's
/// active account and publishes it as a locally-signable identity. The fence
/// is what makes that pair crash-atomic, so it has to survive an unclean
/// process death that happens microseconds after it is raised.
///
/// `SharedPreferences` cannot back it: its own documentation says a completed
/// write is not guaranteed to have reached disk and that it must not be used
/// for critical data. This writes a file with `flush: true` (an fsync on the
/// file itself) and then re-reads it before reporting success, so a fence this
/// class says is raised really is on disk.
abstract class SignOutFence {
  /// Whether an unfinished sign-out is recorded for the current network.
  Future<bool> isRaised();

  /// Makes the fence durable. Returns false when that could not be confirmed —
  /// callers must then refuse to clear the bearer and fail closed, since the
  /// pair would no longer be crash-atomic.
  Future<bool> raise();

  /// Removes the fence once the boundary has fully settled. Returns false when
  /// removal could not be confirmed; a stale fence only costs one redundant
  /// repair on the next boot, so callers may proceed.
  Future<bool> lower();
}

/// File-backed [SignOutFence] in the application support directory.
class DurableSignOutFence implements SignOutFence {
  DurableSignOutFence({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  /// Set once the host has proved it has no application directory, so a
  /// process that cannot have a fence does not log the same error on every
  /// identity transition.
  bool _locationUnavailable = false;

  static const _fileName = 'signout_pending';

  Future<File> _file() async {
    final directory = await _directory();
    // Network-scoped like every other identity key: switching networks is a
    // terminal boundary, and a fence must never leak across one.
    return File('${directory.path}/${NetworkPrefs.currentNetwork}.$_fileName');
  }

  @override
  Future<bool> isRaised() async {
    if (_locationUnavailable) return false;
    final File file;
    try {
      file = await _file();
    } catch (error) {
      _locationUnavailable = true;
      // No app directory on this host, so [raise] could never have succeeded
      // either — and a sign-out that cannot raise the fence fails closed into
      // the terminal reset rather than leaving one behind. Reporting "raised"
      // here would instead repair a sign-out that never happened, on every
      // single boot.
      _log.error('Could not resolve the sign-out fence location: $error');
      return false;
    }
    try {
      return await file.exists();
    } catch (error) {
      // The location resolved but its state is unreadable. Repeating a
      // completed sign-out is harmless; skipping an interrupted one is not.
      _log.error('Could not read the sign-out fence: $error');
      return true;
    }
  }

  @override
  Future<bool> raise() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString('1', flush: true);
      // Verified rather than assumed: the whole point of this class is that a
      // write reporting success is not proof the fence exists.
      return await file.exists();
    } catch (error, stackTrace) {
      _log.error(
        'Could not make the sign-out fence durable',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<bool> lower() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
      return !await file.exists();
    } catch (error) {
      _log.error('Could not remove the sign-out fence: $error');
      return false;
    }
  }
}

/// In-memory [SignOutFence] for tests and for hosts with no app directory.
@visibleForTesting
class InMemorySignOutFence implements SignOutFence {
  InMemorySignOutFence({this.raised = false, this.raiseSucceeds = true});

  bool raised;
  bool raiseSucceeds;
  var raiseCount = 0;
  var lowerCount = 0;

  @override
  Future<bool> isRaised() async => raised;

  @override
  Future<bool> raise() async {
    raiseCount += 1;
    if (!raiseSucceeds) return false;
    raised = true;
    return true;
  }

  @override
  Future<bool> lower() async {
    lowerCount += 1;
    raised = false;
    return true;
  }
}
