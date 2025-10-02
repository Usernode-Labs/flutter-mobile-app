import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:flutter/foundation.dart' as fnd;
import '../../gen_l10n/app_localizations.dart';
import '../../gen_l10n/localization_extensions.dart';
import '../../services/nfc/nfc_service.dart';

class MrzCameraScanScreen extends StatefulWidget {
  const MrzCameraScanScreen({super.key});

  @override
  State<MrzCameraScanScreen> createState() => _MrzCameraScanScreenState();
}

class _MrzCameraScanScreenState extends State<MrzCameraScanScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _processing = false;
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final ctrl = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) return;
      setState(() { _controller = ctrl; _initializing = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _initializing = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  Future<void> _captureAndRecognize() async {
      final ctrl = _controller;
      if (ctrl == null || _processing) return;
      setState(() { _processing = true; });
      fnd.debugPrint('[NFC] MRZ step: start capture');
      try {
        final xfile = await ctrl.takePicture();
        fnd.debugPrint('[NFC] MRZ step: image captured at ${xfile.path}');
        final input = InputImage.fromFilePath(xfile.path);
        fnd.debugPrint('[NFC] MRZ step: OCR processing...');
        final res = await _recognizer.processImage(input);
        fnd.debugPrint('[NFC] MRZ step: OCR done. text length=${res.text.length}');
        final mrz = _extractMrz(res);
        if (mrz != null) {
          fnd.debugPrint('[NFC] Camera MRZ extracted: L1="${mrz.line1}", L2="${mrz.line2}"${mrz.line3 != null ? ", L3=\"${mrz.line3}\"" : ''}');
          if (!mounted) return;
          Navigator.pop(context, mrz);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No MRZ detected. Try again.')));
        }
      } finally {
        setState(() { _processing = false; });
      }
  }

  MrzData? _extractMrz(RecognizedText result) {
    // Collect candidate lines (normalized)
    final rawLines = result.text.split('\n');
    fnd.debugPrint('[NFC] MRZ step: OCR split into ${rawLines.length} raw lines');
    final cleaned = <String>[];
    for (final raw in rawLines) {
      final norm = _normalizeMrz(raw);
      if (norm.isEmpty) continue;
      if (RegExp(r'^[A-Z0-9<]{20,60}$').hasMatch(norm) && norm.contains('<')) {
        cleaned.add(norm);
      }
    }
    if (cleaned.isEmpty) {
      fnd.debugPrint('[NFC] MRZ step: no MRZ-like lines after cleaning');
      return null;
    }
    for (int i = 0; i < cleaned.length; i++) {
      fnd.debugPrint('[NFC] MRZ cleaned['+i.toString()+'] len=${cleaned[i].length}: "${cleaned[i]}"');
    }

    // Keep last up to 6 lines; try TD3 (2 lines) and TD1 (3 lines) windows from the bottom
    final tail = cleaned.sublist(cleaned.length >= 6 ? cleaned.length - 6 : 0);
    fnd.debugPrint('[NFC] MRZ step: tail size=${tail.length}');

    MrzData? fromLines(List<String> lines, {required String label}) {
      String fmt(List<String> ls) => ls.map((s) => '"'+s+'"('+s.length.toString()+')').join(' | ');
      try {
        fnd.debugPrint('[NFC] Try '+label+' RAW: '+fmt(lines));
        final parsed = MRZParser.parse(lines);
        fnd.debugPrint('[NFC] MRZParser validated ('+label+'-raw): type=${parsed.documentType} doc=${parsed.documentNumber}');
        return _toMrzData(lines);
      } catch (e1) {
        fnd.debugPrint('[NFC] MRZParser.parse failed ('+label+'-raw): '+e1.toString());
        final fixedLen = _fitLengths(lines);
        try {
          fnd.debugPrint('[NFC] Try '+label+' FIT: '+fmt(fixedLen));
          final parsed2 = MRZParser.parse(fixedLen);
          fnd.debugPrint('[NFC] MRZParser validated ('+label+'-fit): type=${parsed2.documentType} doc=${parsed2.documentNumber}');
          return _toMrzData(fixedLen);
        } catch (e2) {
          fnd.debugPrint('[NFC] MRZParser.parse failed ('+label+'-fit): '+e2.toString());
          final subst = _commonOcrFix(lines);
          try {
            fnd.debugPrint('[NFC] Try '+label+' SUBST: '+fmt(subst));
            final parsed3 = MRZParser.parse(subst);
            fnd.debugPrint('[NFC] MRZParser validated ('+label+'-subst): type=${parsed3.documentType} doc=${parsed3.documentNumber}');
            return _toMrzData(subst);
          } catch (e3) {
            fnd.debugPrint('[NFC] MRZParser.parse failed ('+label+'-subst): '+e3.toString());
            final substFit = _fitLengths(subst);
            try {
              fnd.debugPrint('[NFC] Try '+label+' SUBST+FIT: '+fmt(substFit));
              final parsed4 = MRZParser.parse(substFit);
              fnd.debugPrint('[NFC] MRZParser validated ('+label+'-subst+fit): type=${parsed4.documentType} doc=${parsed4.documentNumber}');
              return _toMrzData(substFit);
            } catch (e4) {
              fnd.debugPrint('[NFC] MRZParser.parse failed ('+label+'-subst+fit): '+e4.toString());
            }
          }
        }
      }
      return null;
    }

    // Try TD3 windows (2 lines) from bottom upwards
    for (int i = tail.length - 2; i >= 0; i--) {
      final mrz = fromLines([tail[i], tail[i + 1]], label: 'TD3@'+i.toString());
      if (mrz != null) return mrz;
    }
    // Try TD1 windows (3 lines)
    for (int i = tail.length - 3; i >= 0; i--) {
      final mrz = fromLines([tail[i], tail[i + 1], tail[i + 2]], label: 'TD1@'+i.toString());
      if (mrz != null) return mrz;
    }
    fnd.debugPrint('[NFC] MRZ step: no valid MRZ window parsed');
    return null;
  }

  MrzData _toMrzData(List<String> lines) {
    if (lines.length == 2) {
      final l1 = _padTo(lines[0], 44);
      final l2 = _padTo(lines[1], 44);
      return MrzData(line1: l1, line2: l2);
    }
    final l1 = _padTo(lines[0], 30);
    final l2 = _padTo(lines[1], 30);
    final l3 = _padTo(lines[2], 30);
    return MrzData(line1: l1, line2: l2, line3: l3);
  }

  List<String> _fitLengths(List<String> lines) {
    if (lines.length == 2) {
      return [
        lines[0].length >= 44 ? lines[0].substring(0, 44) : lines[0].padRight(44, '<'),
        lines[1].length >= 44 ? lines[1].substring(0, 44) : lines[1].padRight(44, '<'),
      ];
    }
    return [
      lines[0].length >= 30 ? lines[0].substring(0, 30) : lines[0].padRight(30, '<'),
      lines[1].length >= 30 ? lines[1].substring(0, 30) : lines[1].padRight(30, '<'),
      lines[2].length >= 30 ? lines[2].substring(0, 30) : lines[2].padRight(30, '<'),
    ];
  }

  List<String> _commonOcrFix(List<String> lines) {
    String fix(String s) => s
        .replaceAll('«', '<')
        .replaceAll('»', '<')
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8')
        .replaceAll('G', '6');
    return lines.map(fix).toList();
  }

  String _normalizeMrz(String s) {
    var t = s.toUpperCase();
    // Convert any non-MRZ characters to '<' rather than dropping them
    t = t.replaceAll(RegExp(r'[^A-Z0-9<]'), '<');
    // Remove spaces
    t = t.replaceAll(' ', '');
    return t;
  }

  String _padTo(String s, int len) => s.length >= len ? s.substring(0, len) : s.padRight(len, '<');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mrzTitle)),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (_controller == null)
              ? Center(child: Text('Camera unavailable'))
              : Stack(
                  children: [
                    CameraPreview(_controller!),
                    // Simple mask with guidance
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 120,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Align the MRZ (bottom lines) in view. Avoid glare.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: FilledButton.icon(
                          onPressed: _processing ? null : _captureAndRecognize,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: Text(_processing ? 'Processing...' : 'Scan MRZ'),
                        ),
                      ),
                    )
                  ],
                ),
    );
  }
}

class _ScannedLine {
  final String text;
  final double bottom;
  _ScannedLine({required this.text, required this.bottom});
}
