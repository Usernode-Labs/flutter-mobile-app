part of '../dapp_webview_screen.dart';

/// Realm- and session-bound node-awake guards requested by trusted Social UI.
mixin _BridgeNodeRequirement on _DappWebViewScreenStateBase {
  Future<void> _handleRequiresNode(
    String id,
    Map<String, dynamic> payload,
  ) async {
    late final NodeRequirementRequest request;
    try {
      request = NodeRequirementRequest.fromBridgeArgs(payload['args']);
    } on FormatException catch (error) {
      await _resolveJsPromise(id: id, value: null, error: error.message);
      return;
    }

    final realm = _activePrivilegedBridgeLease;
    if (realm == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'requiresNode requires a trusted top-frame capability',
      );
      return;
    }

    switch (request) {
      case NodeRequirementAcquire():
        await _resolveClaimedSessionOperation(
          id: id,
          payload: payload,
          method: 'requiresNode',
          body: (_, operation) async {
            final guardId = await _nodeRequirementGuards.acquire(
              scope: request.scope,
              realmMarker: realm.marker,
              acquireLease: () => operation.acquireNodeAwakeLease(
                SessionNodeAwakeReason.bridgeRequirement,
              ),
            );
            if (guardId == null) {
              throw const NativeSessionException(
                'node_requirement_cancelled',
                'The page changed while acquiring its node requirement.',
              );
            }
            debugPrint(
              '[Usernode JS-channel] node requirement acquired '
              'scope=${request.scope}',
            );
            return <String, Object>{
              'guardId': guardId,
              'scope': request.scope,
            };
          },
          onResponseUndelivered: (value) async {
            if (value
                case {
                  'guardId': final String guardId,
                  'scope': final String scope,
                }) {
              await _nodeRequirementGuards.release(
                guardId: guardId,
                scope: scope,
                realmMarker: realm.marker,
              );
            }
          },
        );
      case NodeRequirementRelease():
        if (!await _revalidatePrivilegedBridgeLease(id, 'requiresNode')) return;
        final released = await _nodeRequirementGuards.release(
          guardId: request.guardId,
          scope: request.scope,
          realmMarker: realm.marker,
        );
        debugPrint(
          '[Usernode JS-channel] node requirement release '
          'scope=${request.scope} released=$released',
        );
        await _resolveJsPromise(
          id: id,
          value: <String, Object>{'released': released},
          error: null,
        );
    }
  }
}
