import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

/// Identity- and network-scoped persistence for the selected delegation
/// target. An absent address means the account self-stakes.
class StakingPreferenceStore {
  const StakingPreferenceStore({required this.bucket});

  static const _delegateAddressKey = 'staking:delegate_address';

  final String bucket;

  factory StakingPreferenceStore.active() =>
      StakingPreferenceStore(bucket: NetworkPrefs.activeBucket);

  String get _key =>
      NetworkPrefs.prefixAccountKeyFor(_delegateAddressKey, bucket);

  Future<String?> loadDelegateAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<bool> isDelegated() async => (await loadDelegateAddress()) != null;

  Future<void> setDelegateAddress(String? address) async {
    final normalized = address?.trim();
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, normalized);
    }
  }
}
