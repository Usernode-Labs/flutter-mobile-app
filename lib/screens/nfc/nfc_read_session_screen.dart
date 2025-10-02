import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../gen_l10n/localization_extensions.dart';
import '../../models/nfc_doc.dart';
import '../../services/nfc/nfc_service.dart';
import '../../services/nfc/document_storage_service.dart';
import 'package:flutter/services.dart';

class NfcReadSessionScreen extends StatefulWidget {
  final MrzData mrz;
  const NfcReadSessionScreen({super.key, required this.mrz});

  @override
  State<NfcReadSessionScreen> createState() => _NfcReadSessionScreenState();
}

class _NfcReadSessionScreenState extends State<NfcReadSessionScreen> {
  String? _error;
  bool _saving = false;
  NfcDoc? _result;
  String _status = '';
  int _percent = 0;
  int _currentStep = -1; // -1 before start
  late List<_StepProgress> _steps;
  bool _sessionActive = false;

  @override
  void initState() {
    super.initState();
    _steps = _defaultSteps();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _result = null;
      _status = '';
      _percent = 0;
      _currentStep = -1;
      _steps = _defaultSteps();
      _sessionActive = true;
    });
    try {
      final doc = await NfcService.instance.readDocumentFromMrz(widget.mrz, onProgress: (msg, p) {
        if (!mounted) return;
        setState(() {
          _status = msg;
          _percent = p.clamp(0, 100);
          _updateStepsFromMessage(msg, _percent);
        });
        if (msg.toLowerCase().contains('tag detected')) {
          HapticFeedback.mediumImpact();
        }
      });
      setState(() => _result = doc);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() { _sessionActive = false; });
  }

  Future<void> _save() async {
    final r = _result;
    if (r == null) return;
    setState(() => _saving = true);
    try {
      final key = DocumentStorageService.keyFor(r.type, r.documentNumber);
      final exists = DocumentStorageService.instance.getAll().any((d) =>
          DocumentStorageService.keyFor(d.type, d.documentNumber) == key);
      await DocumentStorageService.instance.saveOrUpdate(r);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exists ? AppLocalizations.of(context).nfcUpdated : AppLocalizations.of(context).nfcSaved)),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nfcReader)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            if (_error == null && _result == null) ...[
              if (_sessionActive) _ActiveBanner(message: _status.toLowerCase().contains('tag detected') ? 'NFC session active — tag detected' : 'NFC session active — hold steady'),
              if (_sessionActive) const SizedBox(height: 8),
              Center(child: Icon(Icons.nfc_rounded, size: 72, color: theme.colorScheme.primary)),
              const SizedBox(height: 8),
              Center(child: Text(_status.isNotEmpty ? _status : l10n.nfcReading)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _percent == 0 || _percent == 100 ? null : _percent / 100),
              const SizedBox(height: 16),
              _ProgressStepsWidget(steps: _steps, currentIndex: _currentStep),
            ] else if (_error != null) ...[
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(l10n.nfcReadFailed),
              const SizedBox(height: 8),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Row(children: [
                OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), label: Text(l10n.cancel)),
                const SizedBox(width: 12),
                FilledButton.icon(onPressed: _start, icon: const Icon(Icons.refresh), label: Text(l10n.refresh)),
              ]),
            ] else if (_result != null) ...[
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(_result!.alias.isNotEmpty ? _result!.alias : '${_result!.givenNames} ${_result!.surname}'.trim()),
                subtitle: Text('${_result!.type.name.toUpperCase()} · ${_result!.documentNumber}'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(l10n.nfcSave),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepProgress {
  final String key;
  final String label;
  _StepProgress(this.key, this.label);
}

List<_StepProgress> _defaultSteps() => [
  _StepProgress('cardaccess', 'Read EF.CardAccess'),
  _StepProgress('session', 'Start secure session'),
  _StepProgress('com', 'Read EF.COM'),
  _StepProgress('dg1', 'Read DG1 (MRZ)'),
  _StepProgress('dg2', 'Read DG2 (Face)'),
  _StepProgress('sod', 'Read EF.SOD'),
  _StepProgress('finish', 'Finished'),
];

class _ProgressStepsWidget extends StatelessWidget {
  final List<_StepProgress> steps;
  final int currentIndex;
  const _ProgressStepsWidget({required this.steps, required this.currentIndex});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _iconFor(i, currentIndex, theme),
                const SizedBox(width: 8),
                Expanded(child: Text(steps[i].label, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _iconFor(int index, int current, ThemeData theme) {
    if (current >= index + 1) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (current == index) {
      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Icon(Icons.radio_button_unchecked, color: theme.colorScheme.onSurfaceVariant);
  }
}

extension on _NfcReadSessionScreenState {
  void _updateStepsFromMessage(String msg, int percent) {
    final m = msg.toLowerCase();
    int idx = _currentStep;
    if (m.contains('cardaccess')) idx = 0;
    else if (m.contains('secure session')) idx = 1;
    else if (m.contains('ef.com')) idx = 2;
    else if (m.contains('dg1')) idx = 3;
    else if (m.contains('dg2')) idx = 4;
    else if (m.contains('ef.sod')) idx = 5;
    else if (m.contains('finished')) idx = 6;

    if (idx != -1) {
      _currentStep = idx;
      // If finished or percent 100, mark as completed visually by setting current to last+1
      if (idx == _steps.length - 1 || percent >= 100) {
        _currentStep = _steps.length; // all done
      }
    }
  }
}

class _ActiveBanner extends StatelessWidget {
  final String message;
  const _ActiveBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.contactless, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary))),
        ],
      ),
    );
  }
}
