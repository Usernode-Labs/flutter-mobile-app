import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../gen_l10n/localization_extensions.dart';
import '../../models/nfc_doc.dart';
import '../../services/biometrics_service.dart';

class NfcDocDetailScreen extends StatefulWidget {
  final NfcDoc doc;
  const NfcDocDetailScreen({super.key, required this.doc});

  @override
  State<NfcDocDetailScreen> createState() => _NfcDocDetailScreenState();
}

class _NfcDocDetailScreenState extends State<NfcDocDetailScreen> {
  bool _unlocked = false;
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    setState(() { _checking = true; _error = null; });
    final can = await BiometricsService.instance.canCheck();
    if (!can) {
      setState(() { _checking = false; _error = AppLocalizations.of(context).biometricsNotAvailable; });
      return;
    }
    final ok = await BiometricsService.instance.authenticate(reason: AppLocalizations.of(context).unlockToView);
    setState(() { _checking = false; _unlocked = ok; if (!ok) _error = 'Authentication failed'; });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = widget.doc;
    final fmt = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(title: Text(d.alias.isNotEmpty ? d.alias : '${d.givenNames} ${d.surname}'.trim())),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : (!_unlocked)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 64),
                      const SizedBox(height: 8),
                      Text(_error ?? l10n.unlockToView),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _unlock, child: Text('Unlock')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (d.faceImageJpeg != null)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(Uint8List.fromList(d.faceImageJpeg!), width: 160, height: 160, fit: BoxFit.cover),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _InfoRow(label: 'Type', value: d.type.name.toUpperCase()),
                    _InfoRow(label: 'Document No.', value: d.documentNumber),
                    _InfoRow(label: 'Issuer', value: d.issuer),
                    _InfoRow(label: 'Surname', value: d.surname),
                    _InfoRow(label: 'Given names', value: d.givenNames),
                    _InfoRow(label: 'Nationality', value: d.nationality),
                    _InfoRow(label: 'Sex', value: d.sex),
                    _InfoRow(label: 'Date of birth', value: fmt.format(d.dateOfBirth)),
                    _InfoRow(label: 'Expiry', value: fmt.format(d.dateOfExpiry)),
                    const SizedBox(height: 16),
                    Text('MRZ', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d.mrzFullText, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
