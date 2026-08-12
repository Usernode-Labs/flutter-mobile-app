part of '../dapp_webview_screen.dart';

/// Wallet-facing bridge methods: `getWalletState`, `sendTransaction`
/// (with the native confirmation flow and receipt records), and
/// `signMessage` (identity capture-and-revalidate around the
/// user-paced confirmation).
mixin _BridgeWallet on _DappWebViewScreenStateBase, _BridgeTxRecords {
  Future<void> _handleGetWalletState(String id) async {
    // Unavailable-shaped response (all nulls) unless the identity owns a
    // wallet: mid-reconcile and guest sessions must not be served the
    // registry's active account or its cached balance.
    final identity = _bridgeWalletIdentity();
    if (identity == null) {
      await _resolveJsPromise(
        id: id,
        value: {
          'address': null,
          'balance': null,
          'tokenAmount': null,
          'tokenSymbol': null,
          'lastUpdatedMs': null,
          'staking': null,
        },
        error: null,
      );
      return;
    }
    final address = identity.address;
    // The bridge snapshot must not expose the controller's optimistic default
    // before the identity-scoped preference/backend state has hydrated.
    try {
      await ref
          .read(stakingProvider.notifier)
          .ready
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Wallet data remains usable if delegation reconciliation is offline.
    }
    // First read lazily initializes the provider; wait briefly for the
    // initial load so a fresh page doesn't always see nulls, but never
    // hang the page's promise on a slow node.
    WalletState? wallet;
    try {
      wallet = await ref
          .read(walletProvider.future)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      wallet = ref.read(walletProvider).valueOrNull;
    }
    final balance = wallet?.balance;
    await _resolveJsPromise(
      id: id,
      value: {
        'address': address,
        // Base units as a string (BigInt-safe for JS consumers).
        'balance': balance?.totalBalance.toString(),
        'tokenAmount': balance?.tokenAmount,
        'tokenSymbol': balance?.tokenSymbol,
        'lastUpdatedMs': balance?.lastUpdated?.millisecondsSinceEpoch,
        'staking': ref.read(stakingProvider).toBridgeJson(),
      },
      error: null,
    );
  }

  Future<void> _handleManageStaking(String id) async {
    final identity = _bridgeWalletIdentity();
    if (identity == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Delegation requires a ready authenticated wallet.',
      );
      return;
    }

    if (!await _revalidatePrivilegedBridgeLease(id, 'manageStaking')) return;
    if (!mounted) return;
    await context.push(AppRoutes.walletStaking);

    if (!mounted ||
        !identity.sameScopeAs(IdentitySnapshots.current) ||
        _bridgeWalletIdentity() == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The signed-in account changed; refresh wallet state.',
      );
      return;
    }

    await _resolveJsPromise(
      id: id,
      value: ref.read(stakingProvider).toBridgeJson(),
      error: null,
    );
  }

  Future<void> _handleSendTransaction(
      String id, Map<String, dynamic> payload) async {
    // Route-level gating cannot cover this bridge (every dApp webview can
    // request a send) — enforce identity readiness at the signing chokepoint
    // itself. While a reconcile is pending the active account may still
    // belong to a previous user; guests never sign. The snapshot is CAPTURED
    // here and revalidated right before the RPC send: this handler spans a
    // user-paced confirmation dialog, during which a login/logout/rollover
    // can replace the identity out from under the entry check.
    final signingIdentity = _bridgeWalletIdentity();
    if (signingIdentity == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Account is being set up; please retry in a moment.',
      );
      return;
    }
    final args = payload['args'];
    if (args is! Map<String, dynamic>) {
      await _resolveJsPromise(id: id, value: null, error: 'Missing args');
      return;
    }

    final destinationPubkey = (args['destination_pubkey'] as String?)?.trim();
    final amountRaw = args['amount'];
    final memoString = _parseMemoString(args['memo']);
    final confirmTitle = (args['confirm_title'] as String?)?.trim();
    final confirmSubtitle = (args['confirm_subtitle'] as String?)?.trim();

    if (destinationPubkey == null || destinationPubkey.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'destination_pubkey is required',
      );
      return;
    }

    final amount = _parseAmountToBigInt(amountRaw);
    if (amount == null) {
      await _resolveJsPromise(id: id, value: null, error: 'Invalid amount');
      return;
    }

    if (memoString == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Invalid memo; expected UTF-8 string',
      );
      return;
    }
    final memo = frb_types.Memo.fromUtf8Str(s: memoString);

    // The sender is the CAPTURED identity's confirmed address — never the
    // registry's active account, which a mid-transition reconcile may have
    // already switched to another user's.
    final fromAddress = signingIdentity.address;
    if (fromAddress == null || fromAddress.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'No active account/address available',
      );
      return;
    }

    final userConfirmed = await _requestTransactionConfirmation(
      from: fromAddress,
      to: destinationPubkey,
      amount: amount,
      memo: memoString,
      confirmTitle: confirmTitle,
      confirmSubtitle: confirmSubtitle,
    );

    if (!userConfirmed) {
      _addRecord(_TxRecord(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        sentAt: DateTime.now(),
        from: fromAddress,
        to: destinationPubkey,
        amount: amount,
        memo: memoString,
        status: _TxStatus.denied,
      ));
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'User denied the transaction',
      );
      return;
    }

    if (AppConfig.viewOnly) {
      const errorMessage = 'Transactions are disabled in view-only mode.';
      _addRecord(_TxRecord(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        sentAt: DateTime.now(),
        from: fromAddress,
        to: destinationPubkey,
        amount: amount,
        memo: memoString,
        status: _TxStatus.error,
        errorMessage: errorMessage,
      ));
      await _resolveJsPromise(
        id: id,
        value: null,
        error: errorMessage,
      );
      return;
    }

    // Effect-point revalidation: the confirmation dialog above is unbounded
    // user time. If the identity transitioned since capture, the runtime's
    // wallet signer no longer (or may no longer) belong to the identity the
    // user confirmed for — refuse instead of signing as someone else.
    if (IdentitySnapshots.current.epoch != signingIdentity.epoch) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The signed-in account changed; please retry the transaction.',
      );
      return;
    }

    final fromPkHash = frb_types.publicKeyHashFromString(s: fromAddress);
    final toPkHash = frb_types.publicKeyHashFromString(s: destinationPubkey);

    final rpc = RustBackendService.instance.rpc;
    if (rpc == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Node RPC unavailable',
      );
      return;
    }

    final resp = await rpc.wallet().txSendResult(
          fromPkHash: fromPkHash,
          amount: amount,
          toPkHash: toPkHash,
          memo: memo,
        );

    final rpcError = resp?.error;
    final isQueued = resp?.queued ?? false;
    final recordId =
        resp?.txId ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
    _addRecord(_TxRecord(
      id: recordId,
      sentAt: DateTime.now(),
      from: fromAddress,
      to: destinationPubkey,
      amount: amount,
      memo: memoString,
      status: isQueued ? _TxStatus.queued : _TxStatus.error,
      errorMessage: rpcError,
    ));

    if (isQueued && resp?.txId != null) {
      _ensureConfirmPoller();
    }

    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        'queued': isQueued,
        'error': rpcError,
      },
      error: null,
    );
  }

  Future<void> _handleSignMessage(
      String id, Map<String, dynamic> payload) async {
    // Same identity gate as _handleSendTransaction: this handler loads the
    // active account's private key, which must never happen while account
    // ownership is unsettled or for a guest. Captured once, revalidated at
    // the key-load effect point below.
    final signingIdentity = _bridgeWalletIdentity();
    if (signingIdentity == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Account is being set up; please retry in a moment.',
      );
      return;
    }
    final args = payload['args'];
    if (args is! Map<String, dynamic>) {
      await _resolveJsPromise(id: id, value: null, error: 'Missing args');
      return;
    }

    final message = (args['message'] as String?)?.trim();
    if (message == null || message.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'message is required',
      );
      return;
    }

    final repo = await _providers.read(accountsProvider.future);
    final active = await repo.getActive();
    if (active == null || active.address != signingIdentity.address) {
      // The registry's active account must be the captured identity's — a
      // mismatch means a transition is mutating the registry mid-request.
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'No active account available',
      );
      return;
    }

    final confirmed = await _requestSignatureConfirmation();
    if (!confirmed) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'User denied the signature request',
      );
      return;
    }

    // Effect-point revalidation after the user-paced confirmation dialog —
    // the private key is loaded on the next line.
    if (IdentitySnapshots.current.epoch != signingIdentity.epoch) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The signed-in account changed; please retry the request.',
      );
      return;
    }

    final secretKey = await repo.getSecretKey(active.id);
    if (secretKey == null || secretKey.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Secret key unavailable',
      );
      return;
    }

    if (!signingIdentity.sameScopeAs(IdentitySnapshots.current)) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The signed-in account changed; please retry the request.',
      );
      return;
    }

    try {
      final signature = frb_account.signMessage(
        secretKey: secretKey,
        message: message,
      );
      await _resolveJsPromise(
        id: id,
        value: <String, dynamic>{
          'pubkey': active.address,
          'publicKey': active.publicKey,
          'signature': signature,
        },
        error: null,
      );
    } catch (e) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Signing failed: $e',
      );
    }
  }

  Future<bool> _requestSignatureConfirmation() async {
    if (!mounted) return false;
    final theme = Theme.of(context);

    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder<bool>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, _, __) {
          final spacing = Theme.of(ctx).extension<AppSpacing>()!;
          final sizing = Theme.of(ctx).extension<AppSizing>()!;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(ctx, false),
                icon: const Icon(Symbols.close),
              ),
              title: const Text('Verify Identity'),
              titleSpacing: 0,
            ),
            body: Padding(
              padding: EdgeInsets.all(spacing.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Symbols.verified_user,
                    size: sizing.iconDisplay,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: spacing.space16),
                  Text(
                    '${widget.name} is requesting to verify your identity',
                    style: Theme.of(ctx).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.space12),
                  Text(
                    'This will sign a challenge with your private key to '
                    'prove you own this wallet. No transaction will be sent '
                    'and no tokens will be spent.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Button(
                          label: 'Deny',
                          variant: ButtonVariant.outlined,
                          onTap: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      SizedBox(width: spacing.space12),
                      Expanded(
                        child: Button(
                          label: 'Approve',
                          variant: ButtonVariant.primary,
                          onTap: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: child,
          );
        },
      ),
    );
    return result ?? false;
  }

  /// Pushes a full-screen opaque route for transaction confirmation.
  /// Returns `true` if confirmed, `false` if denied.
  Future<bool> _requestTransactionConfirmation({
    required String from,
    required String to,
    required BigInt amount,
    required String memo,
    String? confirmTitle,
    String? confirmSubtitle,
  }) async {
    if (!mounted) return false;

    return requestTransactionConfirmation(
      context,
      from: from,
      to: to,
      amount: amount,
      memo: memo,
      confirmTitle: confirmTitle,
      confirmSubtitle: confirmSubtitle,
    );
  }

  BigInt? _parseAmountToBigInt(Object? amountRaw) {
    if (amountRaw is num) return BigInt.from(amountRaw.round());
    if (amountRaw is String) {
      final trimmed = amountRaw.trim();
      if (trimmed.isEmpty) return null;
      final parsed = double.tryParse(trimmed);
      if (parsed == null) return null;
      return BigInt.from(parsed.round());
    }
    return null;
  }

  String? _parseMemoString(Object? memoRaw) {
    if (memoRaw is String) return memoRaw.trim();
    if (memoRaw == null) return '';
    return null;
  }
}
