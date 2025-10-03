import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bip39/bip39.dart' as bip39;
import '../../gen_l10n/app_localizations.dart';

class ImportSeedData {
  final String name;
  final String mnemonic;
  ImportSeedData({required this.name, required this.mnemonic});
}

class ImportPrivateKeyData {
  final String name;
  final String privateKey;
  ImportPrivateKeyData({required this.name, required this.privateKey});
}

class ImportSeedSheet extends StatefulWidget {
  final String initialName;
  const ImportSeedSheet({super.key, required this.initialName});

  @override
  State<ImportSeedSheet> createState() => _ImportSeedSheetState();
}

class _ImportSeedSheetState extends State<ImportSeedSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _seedCtrl = TextEditingController();
  bool _valid = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName;
    _seedCtrl.addListener(_revalidate);
  }

  @override
  void dispose() {
    _seedCtrl.removeListener(_revalidate);
    _nameCtrl.dispose();
    _seedCtrl.dispose();
    super.dispose();
  }

  void _revalidate() {
    final phrase = _normalizedMnemonic(_seedCtrl.text);
    String? err;
    bool ok = phrase.isNotEmpty && bip39.validateMnemonic(phrase);
    if (_seedCtrl.text.trim().isNotEmpty && !ok) {
      err = 'Invalid BIP39 seed phrase';
    }
    setState(() {
      _valid = ok;
      _errorText = err;
    });
  }

  String _normalizedMnemonic(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  // Removed unused _wordCount helper

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _seedCtrl.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Import from seed phrase',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Import adds an existing account to this app. "Create new" generates a brand new account and recovery phrase.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Account name',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppLocalizations.of(context).accountNameExplain,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _seedCtrl,
                    minLines: 6,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: 'Seed phrase',
                      hintText: 'Enter 12–24 space-separated words',
                      errorText: _errorText,
                      prefixIcon: const Icon(Icons.password_outlined),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_seedCtrl.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _seedCtrl.clear()),
                            ),
                          IconButton(
                            tooltip: 'Paste',
                            icon: const Icon(Icons.paste),
                            onPressed: _pasteFromClipboard,
                          ),
                        ],
                      ),
                      helperText: 'Never share your seed phrase',
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                    ),
                    onChanged: (_) => _revalidate(),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Words are separated by single spaces, usually lowercase. We never transmit your recovery phrase.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _valid
                        ? () {
                            final name = _nameCtrl.text.trim().isEmpty
                                ? 'Imported'
                                : _nameCtrl.text.trim();
                            final phrase = _normalizedMnemonic(_seedCtrl.text);
                            Navigator.pop(
                              context,
                              ImportSeedData(name: name, mnemonic: phrase),
                            );
                          }
                        : null,
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ImportPrivateKeySheet extends StatefulWidget {
  final String initialName;
  const ImportPrivateKeySheet({super.key, required this.initialName});

  @override
  State<ImportPrivateKeySheet> createState() => _ImportPrivateKeySheetState();
}

class _ImportPrivateKeySheetState extends State<ImportPrivateKeySheet> {
  final _nameCtrl = TextEditingController();
  final _pkCtrl = TextEditingController();
  bool _valid = false;
  bool _obscure = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName;
    _pkCtrl.addListener(_revalidate);
  }

  @override
  void dispose() {
    _pkCtrl.removeListener(_revalidate);
    _nameCtrl.dispose();
    _pkCtrl.dispose();
    super.dispose();
  }

  void _revalidate() {
    var pk = _pkCtrl.text.trim();
    if (pk.startsWith('0x')) pk = pk.substring(2);
    final isHex64 = RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(pk);
    String? err;
    if (_pkCtrl.text.trim().isNotEmpty && !isHex64) {
      err = 'Invalid private key format';
    }
    setState(() {
      _valid = isHex64;
      _errorText = err;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _pkCtrl.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pkRaw = _pkCtrl.text.trim();
    var pk = pkRaw.startsWith('0x') ? pkRaw.substring(2) : pkRaw;
    final len = pk.length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Import from private key',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Import adds an existing account to this app. "Create new" generates a brand new account and private key.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Account name',
                prefixIcon: Icon(Icons.account_circle_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context).accountNameExplain,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pkCtrl,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Private key (hex)',
                hintText: '64 characters, optional 0x prefix',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_pkCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _pkCtrl.clear()),
                      ),
                    IconButton(
                      tooltip: _obscure ? 'Show' : 'Hide',
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    IconButton(
                      tooltip: 'Paste',
                      icon: const Icon(Icons.paste),
                      onPressed: _pasteFromClipboard,
                    ),
                  ],
                ),
                helperText: '$len / 64 hex chars',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
              ),
              onChanged: (_) => _revalidate(),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'We never transmit your private key. Keep it confidential and never share it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _valid
                        ? () {
                            final name = _nameCtrl.text.trim().isEmpty
                                ? 'Imported'
                                : _nameCtrl.text.trim();
                            var pk = _pkCtrl.text.trim();
                            if (pk.startsWith('0x')) pk = pk.substring(2);
                            Navigator.pop(
                              context,
                              ImportPrivateKeyData(
                                name: name,
                                privateKey: pk,
                              ),
                            );
                          }
                        : null,
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
