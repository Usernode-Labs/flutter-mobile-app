part of '../dapp_webview_screen.dart';

/// Wallet and delegation bridge methods. Every native effect is admitted by
/// the exact realm/session runner; Flutter owns only the user confirmation UI.
mixin _BridgeWallet on _DappWebViewScreenStateBase {
  Future<void> _handleGetWalletState(
    String id,
    Map<String, dynamic> payload,
  ) =>
      _resolveClaimedSessionOperation(
        id: id,
        payload: payload,
        method: 'getWalletState',
        body: (_, operation) async =>
            (await operation.readWallet()).toBridgeJson(),
      );

  Future<void> _handleManageStaking(
    String id,
    Map<String, dynamic> payload,
  ) =>
      _resolveClaimedSessionOperation(
        id: id,
        payload: payload,
        method: 'manageStaking',
        body: (_, operation) async {
          if (!mounted) {
            throw const NativeSessionException(
              'native_ui_unavailable',
              'Delegation UI is unavailable.',
            );
          }
          await context.push(AppRoutes.walletStaking);
          return (await operation.readDelegation()).toBridgeJson();
        },
      );

  Future<void> _handleSubmitTransaction(
    String id,
    Map<String, dynamic> payload,
  ) async {
    late final SubmitTransactionRequest request;
    try {
      request = SubmitTransactionRequest.fromBridgeArgs(payload['args']);
    } on FormatException catch (error) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: error.message.toString(),
      );
      return;
    }

    await _resolveClaimedSessionOperation(
      id: id,
      payload: payload,
      method: 'submitTransaction',
      body: (identity, operation) async {
        final from = identity.address;
        if (from == null || from.isEmpty) {
          throw const NativeSessionException(
            'native_wallet_unavailable',
            'No active account/address is available.',
          );
        }
        final confirmed = await _requestTransactionConfirmation(
          from: from,
          to: request.destinationPubkey,
          amount: request.amount,
          memo: request.memo,
          confirmTitle: request.confirmation?.title,
          confirmSubtitle: request.confirmation?.subtitle,
        );
        if (!confirmed) {
          throw const NativeSessionException(
            'native_user_denied',
            'User denied the transaction.',
          );
        }
        if (AppConfig.viewOnly) {
          throw const NativeSessionException(
            'native_view_only',
            'Transactions are disabled in view-only mode.',
          );
        }
        final result = await operation.submitTransaction(
          destinationAddress: request.destinationPubkey,
          amount: request.amount,
          memo: request.memo,
        );
        return SubmitTransactionResult(
          txId: result.transactionId,
        ).toBridgeJson();
      },
    );
  }

  Future<void> _handleSignMessage(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final args = payload['args'];
    final message = args is Map<String, dynamic> ? args['message'] : null;
    if (message is! String || message.trim().isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'message is required',
      );
      return;
    }
    await _resolveClaimedSessionOperation(
      id: id,
      payload: payload,
      method: 'signMessage',
      body: (identity, operation) async {
        final confirmed = await _requestSignatureConfirmation();
        if (!confirmed) {
          throw const NativeSessionException(
            'native_user_denied',
            'User denied the signature request.',
          );
        }
        final result = await operation.signMessage(message);
        return <String, Object?>{
          'pubkey': identity.address,
          'publicKey': result.publicKey,
          'signature': result.signature,
        };
      },
    );
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
}
