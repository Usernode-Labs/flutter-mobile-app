import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/sync_status_provider.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  final String? accountId;

  const IdentityVerificationScreen({
    super.key,
    this.accountId,
  });

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  bool _processing = false;
  bool _loadingStatus = false;

  // Identity status (beta mocked)
  String? _uidHex;
  bool _present = false;
  int? _version;
  String? _registeredPkHash; // normalized display
  String? _registeredPkHex; // hex form for comparisons
  String? _walletPkHex; // active wallet address (hex)
  bool _mismatch = false; // registered vs wallet
  bool _alreadyVerified = false; // from local account metadata

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _refreshIdentityStatus());
  }

  String _short(String s) {
    if (s.length <= 12) return s;
    return '${s.substring(0, 6)}…${s.substring(s.length - 6)}';
  }

  Future<void> _refreshIdentityStatus() async {
    if (_loadingStatus) return;
    setState(() => _loadingStatus = true);
    try {
      final repo = await AccountsRepository.create();
      final active = await repo.getActive();
      if (active == null) {
        setState(() {
          _loadingStatus = false;
          _uidHex = null;
          _present = false;
          _version = null;
          _registeredPkHash = null;
          _registeredPkHex = null;
          _walletPkHex = null;
          _mismatch = false;
        });
        return;
      }
      final already = active.identityVerified;
      // Derive UID deterministically from the active address (snapshot behavior)
      final uid = active.address.replaceFirst(RegExp(r'^0x'), '').toLowerCase();
      // Query the app's own local backend HTTP server
      final seedUrl = (Platform.isIOS || Platform.isMacOS)
          ? 'http://127.0.0.1:39000'
          : 'http://10.0.2.2:39000';
      final resp = await RustBackendService.instance.identityGetHttp(
        baseUrl: seedUrl,
        uniqueIdHex: uid,
      );
      final present = resp != null && resp['leaf'] != null;
      String? regPkDisplay;
      String? regPkHex;
      int? ver;
      if (present) {
        final leaf = resp!['leaf'] as Map<String, dynamic>;
        ver = (leaf['version'] as num).toInt();
        // Prefer server-provided hex for robust compare
        regPkHex = (resp['leaf_pk_hash_hex'] as String?)
            ?.replaceFirst(RegExp(r'^0x'), '')
            .toLowerCase();
        regPkDisplay = regPkHex ?? (leaf['pk_hash'] as String);
      }
      final walletHex =
          active.address.replaceFirst(RegExp(r'^0x'), '').toLowerCase();
      final mismatch = present && (regPkHex != null && regPkHex != walletHex);
      if (!mounted) return;
      setState(() {
        _uidHex = uid;
        _present = present;
        _version = ver;
        _registeredPkHash = regPkDisplay;
        _registeredPkHex = regPkHex;
        _walletPkHex = walletHex;
        _mismatch = mismatch;
        _alreadyVerified = already || present;
      });
    } catch (e, st) {
      LoggingService.instance.error('refresh identity failed',
          tag: 'IDENTITY_VERIFICATION', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<String?> _promptReRegisterChoice({
    required String currentRegistered,
    required String walletAddress,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Identity already registered'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registered to: ${_short(currentRegistered)}'),
            const SizedBox(height: 8),
            Text('Wallet address: ${_short(walletAddress)}'),
            const SizedBox(height: 12),
            const Text(
                'Do you want to keep the registered address or change it to your current wallet address?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(currentRegistered),
            child: const Text('Keep same'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(walletAddress),
            child: const Text('Change to wallet'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerOrUpdate() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final repo = await AccountsRepository.create();
      final active = await repo.getActive();
      if (active == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active account found')),
        );
        return;
      }
      final uid = active.address.replaceFirst(RegExp(r'^0x'), '').toLowerCase();

      String stakingPk = active.address;
      if (_present && _registeredPkHex != null) {
        final choice = await _promptReRegisterChoice(
          currentRegistered: _registeredPkHex!,
          walletAddress: active.address,
        );
        if (choice == null) return; // cancelled
        stakingPk = choice;
      }
      // Submit registration to the app's local backend (non-batcher mempool submit)
      final seedUrl = (Platform.isIOS || Platform.isMacOS)
          ? 'http://127.0.0.1:39000'
          : 'http://10.0.2.2:39000';
      final ok = await RustBackendService.instance.registerIdentityHttp(
        baseUrl: seedUrl,
        uniqueIdHex: uid,
        stakingPkHash: stakingPk,
        feePayer: active.address,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Identity queued' : 'Register failed')),
      );
      // Poll for confirmation for up to ~15s
      if (ok) {
        for (int i = 0; i < 15; i++) {
          await Future.delayed(const Duration(seconds: 1));
          await _refreshIdentityStatus();
          if (_present) break;
        }
      } else {
        await _refreshIdentityStatus();
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _proceedWithVerification() async {
    await _registerOrUpdate();
  }

  Future<void> _skipForLater() async {
    ref.invalidate(hasAnyAccountProvider);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    context.go('/main/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sync = ref.watch(syncStatusProvider);

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppAppBar(
          title: 'Identity Verification',
          automaticallyImplyLeading: true,
          showNotifications: false,
          showNodeStatus: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/main/home'),
            tooltip: 'Back',
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_present)
                    Text(
                      'Verify Your Identity',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (!_present)
                    Text(
                      'Verify your identity using zkPassport to increase your reward multiplier and unlock block production features.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (!_present)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BenefitItem(
                                icon: Icons.verified_user,
                                text: 'Identity linked to your staking key',
                                theme: theme),
                            const SizedBox(height: 12),
                            _BenefitItem(
                                icon: Icons.how_to_vote,
                                text: 'Eligible for participation flows',
                                theme: theme),
                            const SizedBox(height: 12),
                            _BenefitItem(
                                icon: Icons.privacy_tip,
                                text: 'No personal data on-chain',
                                theme: theme),
                            const SizedBox(height: 16),
                            Divider(color: colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.shield,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Your personal information is encrypted and never shared.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Registered / syncing / not-registered indicator and details
                  if (_uidHex != null) ...[
                    Row(
                      children: [
                        Icon(
                          _present
                              ? Icons.verified
                              : (sync.isSynced ? Icons.pending : Icons.sync),
                          color: _present
                              ? Colors.green
                              : (sync.isSynced
                                  ? Colors.orange
                                  : colorScheme.primary),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _present
                              ? 'Registered (v${_version ?? 1})'
                              : (sync.isSynced
                                  ? 'Not registered yet'
                                  : 'Syncing… ' + sync.label),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'UID: ${_short(_uidHex!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (!_present && !sync.isSynced) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Node is syncing. On-chain status may be stale. You can still register now.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (_registeredPkHash != null) ...[
                      const SizedBox(height: 4),
                      SelectableText(
                        'Registered key: ${_short(_registeredPkHash!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (_mismatch &&
                        _registeredPkHex != null &&
                        _walletPkHex != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Warning: Wallet address differs from registered key.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.orange),
                      ),
                    ],
                  ],
                  if (_uidHex != null) const SizedBox(height: 12),
                  if (_uidHex != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed:
                            _loadingStatus ? null : _refreshIdentityStatus,
                        child: _loadingStatus
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Refresh Status'),
                      ),
                    ),

                  // Register / Update controls
                  if (!_present) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _processing ? null : _proceedWithVerification,
                        child: _processing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Register Identity'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _processing ? null : _skipForLater,
                        child: const Text('Skip for now'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _processing ? null : _registerOrUpdate,
                        child: _processing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Register Again (increment version)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;

  const _BenefitItem({
    required this.icon,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
