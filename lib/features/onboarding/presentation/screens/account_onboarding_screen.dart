import 'package:flutter/material.dart';
// import 'package:crypto_mobile_app/theme/app_theme.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
// import 'package:crypto_mobile_app/features/wallet/data/models/account_creation_result.dart';
import 'package:crypto_mobile_app/app/main_app.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';

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
  // AccountCreationResult? _result; // unused
  // String? _createdAccountId; // unused
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
      MaterialPageRoute(
          builder: (_) => const MainApp(initialFeature: AppFeature.wallet)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _hasExistingAccounts,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).createAccountTitle),
          elevation: 0,
          centerTitle: false,
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
                            Text(
                                AppLocalizations.of(context)
                                    .recoveryPhraseTitle,
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)
                                          .recoveryPhraseWarning,
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
                              AppLocalizations.of(context)
                                  .recoveryPhraseInstruction,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_mnemonic != null)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _MnemonicGrid(mnemonic: _mnemonic!),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text(AppLocalizations.of(context).accountNameLabel,
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)
                                    .accountNameHint,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).accountNameExplain,
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
                                Expanded(
                                  child: Text(AppLocalizations.of(context)
                                      .seedStoredCheckbox),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _ack ? _complete : null,
                                child: Text(AppLocalizations.of(context)
                                    .continueButton),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$idx',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
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
                    overflow: TextOverflow.ellipsis,
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
