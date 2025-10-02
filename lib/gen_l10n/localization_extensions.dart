import 'app_localizations.dart';

extension AppLocalizationsNfcExt on AppLocalizations {
  String get nfcReader => 'NFC Reader';
  String get nfcEmptyTitle => 'Scan your ID';
  String get nfcEmptySubtitle => 'Use your phone to read your ePassport or eID via NFC.';
  String get nfcScanAnother => 'Scan another';
  String get nfcManualMrz => 'Enter MRZ manually';
  String get nfcStartScan => 'Start NFC scan';
  String get mrzTitle => 'Enter MRZ';
  String get mrzLine1 => 'MRZ line 1';
  String get mrzLine2 => 'MRZ line 2';
  String get mrzLine3 => 'MRZ line 3 (optional)';
  String get mrzContinue => 'Continue';
  String get nfcReading => 'Hold document to the phone...';
  String get nfcSave => 'Save';
  String get nfcRename => 'Rename';
  String get nfcDelete => 'Delete';
  String get nfcConfirmDelete => 'Delete this document?';
  String get unlockToView => 'Unlock to view private data';
  String get biometricsNotAvailable => 'Biometrics not available';
  String get nfcNotSupported => 'This device does not support NFC.';
  String get nfcTurnOn => 'Please enable NFC in settings.';
  String get nfcReadFailed => 'Failed to read document. Check MRZ and try again.';
  String get nfcUpdated => 'Document updated';
  String get nfcSaved => 'Document saved';
}

