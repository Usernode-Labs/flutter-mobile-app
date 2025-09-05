import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/theme/app_theme.dart';
import 'package:bip39/bip39.dart' as bip39;
import '../../services/accounts_repository.dart';
import '../../models/account_creation_result.dart';
import '../main_app.dart';

class AccountOnboardingScreen extends StatefulWidget {
  const AccountOnboardingScreen({super.key});

  @override
  State<AccountOnboardingScreen> createState() =>
      _AccountOnboardingScreenState();
}

class _AccountOnboardingScreenState extends State<AccountOnboardingScreen> {
  bool _generating = false;
  bool _ack = false;
  String? _mnemonic;
  String? _err;
  final _nameCtrl = TextEditingController(text: 'Account 1');
  AccountCreationResult? _result;
  String? _createdAccountId;
  bool _hasExistingAccounts = false;

  @override
  void initState() {
    super.initState();
    _guardAndGenerate();
  }

  Future<void> _guardAndGenerate() async {
    final repo = await AccountsRepository.create();
    _hasExistingAccounts = await repo.hasAny();
    await _startGeneration();
  }

  Future<void> _startGeneration() async {
    setState(() {
      _generating = true;
      _err = null;
    });
    try {
      final seed = bip39.generateMnemonic();
      setState(() {
        _mnemonic = seed;
        _generating = false;
      });
    } catch (e) {
      setState(() {
        _err = 'Failed to generate recovery phrase';
        _generating = false;
      });
    }
  }

  Future<void> _complete() async {
    if (!_ack || _mnemonic == null || _mnemonic!.isEmpty) return;
    final repo = await AccountsRepository.create();
    final newName =
        _nameCtrl.text.trim().isEmpty ? 'Account 1' : _nameCtrl.text.trim();
    await repo.importFromMnemonic(name: newName, mnemonic: _mnemonic!);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainApp()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async => _hasExistingAccounts,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Account'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: _hasExistingAccounts && Navigator.of(context).canPop()
              ? const BackButton()
              : null,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _generating
                ? const Center(child: CircularProgressIndicator())
                : _err != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Error: $_err',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _startGeneration,
                            child: const Text('Retry'),
                          )
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your recovery phrase',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer
                                    .withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: theme.colorScheme.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This recovery phrase is the ONLY way to restore your keys and regain access to this account if something goes wrong. Store it securely and never share it.',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Write these words down and store them securely. '
                              'They will NOT be stored by the app and cannot be recovered.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            if (_mnemonic != null)
                              Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(0),
                                  child: _MnemonicGrid(mnemonic: _mnemonic!),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text('Account name',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g., Account 1',
                            border: OutlineInputBorder(),
                          ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This name is only stored on your device to help you identify the account. '
                              'It does not affect your blockchain address or keys.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Checkbox(
                                    value: _ack,
                                    onChanged: (v) =>
                                        setState(() => _ack = v ?? false)),
                                const Expanded(
                                  child: Text(
                                      'I have securely stored my recovery phrase.'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _ack ? _complete : null,
                                child: const Text('Continue'),
                              ),
                            )
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}

class _MnemonicGrid extends StatelessWidget {
  final String mnemonic;
  const _MnemonicGrid({required this.mnemonic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words =
        mnemonic.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return LayoutBuilder(builder: (ctx, constraints) {
      // 2 columns on narrow, 3 on wider screens
      final isWide = constraints.maxWidth > 360;
      final columns = isWide ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 4.0,
        ),
        itemCount: words.length,
        itemBuilder: (_, i) {
          final idx = i + 1;
          final w = words[i];
          return Container(
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(0),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$idx',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    w,
                    style: theme.textTheme.titleMedium,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
