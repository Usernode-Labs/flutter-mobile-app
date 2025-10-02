import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../gen_l10n/localization_extensions.dart';
import 'package:flutter/foundation.dart' as fnd;
import '../../services/nfc/nfc_service.dart';
import 'nfc_read_session_screen.dart';

class MrzInputScreen extends StatefulWidget {
  const MrzInputScreen({super.key});

  @override
  State<MrzInputScreen> createState() => _MrzInputScreenState();
}

class _MrzInputScreenState extends State<MrzInputScreen> {
  final _l1 = TextEditingController();
  final _l2 = TextEditingController();
  final _l3 = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _l1.dispose();
    _l2.dispose();
    _l3.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final mrz = MrzData(line1: _l1.text.trim(), line2: _l2.text.trim(), line3: _l3.text.trim().isEmpty ? null : _l3.text.trim());
    fnd.debugPrint('[NFC] Manual MRZ submitted: L1="${mrz.line1}", L2="${mrz.line2}"${mrz.line3 != null ? ", L3=\"${mrz.line3}\"" : ''}');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NfcReadSessionScreen(mrz: mrz)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mrzTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _l1,
                decoration: InputDecoration(labelText: l10n.mrzLine1),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _l2,
                decoration: InputDecoration(labelText: l10n.mrzLine2),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _l3,
                decoration: InputDecoration(labelText: l10n.mrzLine3),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _continue,
                  child: Text(l10n.mrzContinue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
