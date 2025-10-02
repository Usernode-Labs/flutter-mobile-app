import 'dart:async';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart' as kit;
import 'dart:io' show Platform;
import 'package:dmrtd/dmrtd.dart' as emrtd;
import 'package:flutter/foundation.dart' as fnd;
import 'dart:typed_data';
import '../../models/nfc_doc.dart';
import 'mrz_utils.dart';

class NfcAvailability {
  final bool supported;
  final bool enabled;
  NfcAvailability({required this.supported, required this.enabled});
}

class MrzData {
  final String line1;
  final String line2;
  final String? line3;
  const MrzData({required this.line1, required this.line2, this.line3});
}

typedef ProgressCallback = void Function(String message, int percent);

class NfcService {
  NfcService._();
  static final instance = NfcService._();

  Future<NfcAvailability> checkAvailability() async {
    try {
      _log('Checking NFC availability ...');
      // For iOS: during test phase (MRZ-only flow), assume NFC support to avoid misleading banner.
      // Real chip access will still require the NFC entitlement in Xcode.
      if (Platform.isIOS) {
        _log('iOS platform — assuming NFC supported (entitlements still required).');
        final res = NfcAvailability(supported: true, enabled: true);
        _log('Availability: supported=${res.supported}, enabled=${res.enabled}');
        return res;
      }
      final avail = await kit.FlutterNfcKit.nfcAvailability;
      switch (avail) {
        case kit.NFCAvailability.available:
          _log('Android NFCAvailability: available');
          return NfcAvailability(supported: true, enabled: true);
        case kit.NFCAvailability.disabled:
          _log('Android NFCAvailability: disabled');
          return NfcAvailability(supported: true, enabled: false);
        case kit.NFCAvailability.not_supported:
        default:
          _log('Android NFCAvailability: not_supported');
          return NfcAvailability(supported: false, enabled: false);
      }
    } catch (_) {
      _log('Error while checking NFCAvailability');
      return NfcAvailability(supported: false, enabled: false);
    }
  }

  /// Reads an ePassport/eID using MRZ-derived key (BAC) and returns a populated [NfcDoc].
  ///
  /// Performs BAC (or PACE) using MRZ-derived keys and reads DG1/DG2 (face image) via dmrtd.
  Future<NfcDoc> readDocumentFromMrz(MrzData mrz, {ProgressCallback? onProgress}) async {
    final mrzLines = [mrz.line1.trim(), mrz.line2.trim(), mrz.line3?.trim() ?? ''];
    _log('MRZ input raw: L1="${mrzLines[0]}", L2="${mrzLines[1]}", L3="${mrzLines[2]}"');
    _log('MRZ input lens: len(l1)=${mrzLines[0].length}, len(l2)=${mrzLines[1].length}, len(l3)=${mrzLines[2].length}');
    if (mrzLines[0].isEmpty || mrzLines[1].isEmpty) {
      throw Exception('Invalid MRZ');
    }

    // Parse MRZ fields manually (tolerant of OCR errors) to derive keys.
    final isTD1 = (mrz.line3 != null && mrz.line3!.trim().isNotEmpty);
    // Normalize to uppercase, remove spaces and replace non-MRZ chars with '<'
    final norm1 = _normalizeMrz(mrzLines[0]);
    final norm2 = _normalizeMrz(mrzLines[1]);
    final norm3 = isTD1 ? _normalizeMrz(mrzLines[2]) : '';
    _log('MRZ normalized: L1="${norm1}", L2="${norm2}"${isTD1 ? ", L3=\"$norm3\"" : ''}');
    // Basic checksum validation to catch OCR mistakes early
    String line2ForParse = norm2; // may be auto-aligned below
    if (!isTD1) {
      final l1 = norm1.padRight(44, '<');
      var l2 = norm2.padRight(44, '<');
      // Detailed TD3 logging for checksums
      final docNo = l2.substring(0, 9);
      final docCd = l2.substring(9, 10);
      final docComp = MrzUtils.computeCheckDigit(docNo);
      _log('TD3 docNo="$docNo" cd expected=$docCd computed=$docComp');
      var dob = l2.substring(13, 19);
      var dobCd = l2.substring(19, 20);
      var dobComp = MrzUtils.computeCheckDigit(dob);
      _log('TD3 dob="$dob" cd expected=$dobCd computed=$dobComp');
      var exp = l2.substring(21, 27);
      var expCd = l2.substring(27, 28);
      var expComp = MrzUtils.computeCheckDigit(exp);
      _log('TD3 exp="$exp" cd expected=$expCd computed=$expComp');

      var err = MrzUtils.validateTd3(l1, l2);
      if (err != null) {
        _log('TD3 validation failed: $err');
        // Attempt auto-alignment around nationality if mis-scanned (common extra "<" before nationality)
        final offset = _td3AlignmentOffset(l2);
        if (offset != 0) {
          _log('Applying TD3 alignment offset $offset around nationality.');
          l2 = _alignTd3Line2(l2, offset);
          line2ForParse = l2;
          // Recompute fields
          dob = l2.substring(13, 19);
          dobCd = l2.substring(19, 20);
          dobComp = MrzUtils.computeCheckDigit(dob);
          exp = l2.substring(21, 27);
          expCd = l2.substring(27, 28);
          expComp = MrzUtils.computeCheckDigit(exp);
          _log('After align → dob="$dob" expected=$dobCd computed=$dobComp, exp="$exp" expected=$expCd computed=$expComp');
          err = MrzUtils.validateTd3(l1, l2);
        }
        // If still failing, try targeted corrections on digits-only fields (DOB/EXP) and common doc number OCR.
        if (err != null) {
          final corrected = _tryCorrectTd3Line2(l2);
          if (corrected != null) {
            _log('Applied TD3 digit corrections to L2.');
            l2 = corrected;
            line2ForParse = l2;
            // Recompute logs
            dob = l2.substring(13, 19); dobCd = l2.substring(19, 20); dobComp = MrzUtils.computeCheckDigit(dob);
            exp = l2.substring(21, 27); expCd = l2.substring(27, 28); expComp = MrzUtils.computeCheckDigit(exp);
            _log('After correction → dob="$dob" expected=$dobCd computed=$dobComp, exp="$exp" expected=$expCd computed=$expComp');
            err = MrzUtils.validateTd3(l1, l2);
          }
        }
      }
      if (err != null) {
        throw Exception('MRZ appears invalid: $err Please correct MRZ and try again.');
      }
      _log('TD3 validation OK');
    } else {
      final l1 = norm1.padRight(30, '<');
      final l2 = norm2.padRight(30, '<');
      final l3 = norm3.padRight(30, '<');
      final err = MrzUtils.validateTd1(l1, l2, l3);
      if (err != null) {
        _log('TD1 validation failed: $err');
        throw Exception('MRZ appears invalid: $err Please correct MRZ and try again.');
      } else {
        _log('TD1 validation OK');
      }
    }
    final seed = _parseMrzFallback([norm1, line2ForParse, norm3]);
    _log('Parsed MRZ seed: issuer=${seed.issuer}, docNo=${_mask(seed.docNo)}, dob=${seed.dob.toIso8601String().split('T').first}, expiry=${seed.expiry.toIso8601String().split('T').first}');

    final nfc = emrtd.NfcProvider();
    try {
      onProgress?.call('Hold your document to the phone', 0);
      _log('Connecting to NFC tag ...');
      await nfc.connect(iosAlertMessage: 'Hold your iPhone near Passport');
      // Notify UI that tag is detected (connect() returns when tag is present)
      onProgress?.call('Tag detected', 10);
      _log('Tag detected. Creating Passport session.');
      final passport = emrtd.Passport(nfc);

      // Try PACE first if available
      emrtd.EfCardAccess? cardAccess;
      try {
        nfc.setIosAlertMessage('Reading EF.CardAccess ...');
        onProgress?.call('Reading EF.CardAccess ...', 5);
        _log('Reading EF.CardAccess ...');
        cardAccess = await passport.readEfCardAccess();
        _log('EF.CardAccess read OK');
      } catch (_) {
        _log('EF.CardAccess not available (will use BAC if needed).');
        cardAccess = null;
      }

      if (cardAccess != null) {
        final paceKey = emrtd.DBAKey(seed.docNo, seed.dob, seed.expiry, paceMode: true);
        onProgress?.call('Starting secure session (PACE) ...', 15);
        nfc.setIosAlertMessage('Starting secure session (PACE) ...');
        try {
          _log('Starting PACE ...');
          await passport.startSessionPACE(paceKey, cardAccess);
          _log('PACE session established.');
        } catch (e) {
          _log('PACE failed: $e');
          // Surface a clearer hint if MRZ-derived key is wrong
          rethrow;
        }
      } else {
        // BAC fallback
        final dbaKey = emrtd.DBAKey(seed.docNo, seed.dob, seed.expiry);
        onProgress?.call('Starting secure session (BAC) ...', 15);
        nfc.setIosAlertMessage('Starting secure session (BAC) ...');
        try {
          _log('Starting BAC ...');
          await passport.startSession(dbaKey);
          _log('BAC session established.');
        } catch (e) {
          _log('BAC failed: $e');
          rethrow;
        }
      }

      // Read EF.COM to know which DGs are present
      onProgress?.call('Reading EF.COM ...', 25);
      nfc.setIosAlertMessage('Reading EF.COM ...');
      _log('Reading EF.COM ...');
      final efcom = await passport.readEfCOM();
      _log('EF.COM read OK. DG tags count=${efcom.dgTags.length}');

      emrtd.EfDG1? dg1;
      if (efcom.dgTags.contains(emrtd.EfDG1.TAG)) {
        onProgress?.call('Reading DG1 (MRZ data) ...', 45);
        nfc.setIosAlertMessage('Reading DG1 ...');
        _log('Reading DG1 ...');
        dg1 = await passport.readEfDG1();
        _log('DG1 read OK.');
      }
      emrtd.EfDG2? dg2;
      if (efcom.dgTags.contains(emrtd.EfDG2.TAG)) {
        onProgress?.call('Reading DG2 (face image) ...', 70);
        nfc.setIosAlertMessage('Reading DG2 ...');
        _log('Reading DG2 ...');
        dg2 = await passport.readEfDG2();
        _log('DG2 read OK. Image bytes: ${dg2?.imageData?.length ?? 0}');
      }
      // Optionally read SOD for integrity (full CSCA validation not implemented here)
      if (efcom.dgTags.isNotEmpty) {
        try {
          onProgress?.call('Reading EF.SOD ...', 85);
          nfc.setIosAlertMessage('Reading EF.SOD ...');
          _log('Reading EF.SOD ...');
          await passport.readEfSOD();
          _log('EF.SOD read OK.');
        } catch (_) {}
      }

      // Map DG1 fields
      String issuer = '';
      String surname = '';
      String given = '';
      String docNo = '';
      String nationality = '';
      DateTime dob = DateTime(1970,1,1);
      String sex = '';
      DateTime expiry = DateTime(1970,1,1);

      if (dg1 != null) {
        final m = dg1.mrz;
        issuer = m.country;
        surname = m.lastName;
        given = m.firstName;
        docNo = m.documentNumber;
        nationality = m.nationality;
        dob = m.dateOfBirth;
        sex = m.gender;
        expiry = m.dateOfExpiry;
      } else {
        // Fallback to parsed input if DG1 not present
        issuer = seed.issuer;
        surname = seed.surname;
        given = seed.given;
        docNo = seed.docNo;
        nationality = seed.nationality;
        dob = seed.dob;
        sex = seed.sex;
        expiry = seed.expiry;
      }

      List<int>? faceBytes;
      if (dg2?.imageData != null) {
        faceBytes = dg2!.imageData!;
      }

      final type = isTD1 ? DocumentType.idCard : DocumentType.passport;
      final now = DateTime.now();
      final id = '${type.name}:${docNo.toUpperCase()}';

      final result = NfcDoc(
        id: id,
        alias: '${given.isNotEmpty ? given.split(' ').first : ''} ${surname.isNotEmpty ? surname : ''}'.trim(),
        type: type,
        documentNumber: docNo,
        issuer: issuer,
        givenNames: given,
        surname: surname,
        nationality: nationality,
        sex: sex,
        dateOfBirth: dob,
        dateOfExpiry: expiry,
        lastScannedAt: now,
        mrzFullText: [mrzLines[0], mrzLines[1], if (isTD1) mrzLines[2]].join('\n'),
        faceImageJpeg: faceBytes,
      );
      onProgress?.call('Finished', 100);
      nfc.setIosAlertMessage('Finished');
      _log('NFC reading finished successfully.');
      return result;
    } finally {
      try {
        _log('Disconnecting NFC session ...');
        await nfc.disconnect(iosAlertMessage: 'Finished');
        _log('NFC session disconnected.');
      } catch (e) {
        _log('Error during disconnect: $e');
      }
    }
  }
}

String safeSub(String s, int start, int end) {
  if (start >= s.length) return '';
  if (end > s.length) end = s.length;
  return s.substring(start, end);
}

void _log(String msg) {
  fnd.debugPrint('[NFC] $msg');
}

String _mask(String s) {
  if (s.isEmpty) return s;
  if (s.length <= 3) return '***';
  return '${s.substring(0, s.length - 3).replaceAll(RegExp('.'), '*')}${s.substring(s.length - 3)}';
}

String _normalizeMrz(String s) {
  var t = s.toUpperCase();
  t = t.replaceAll(' ', '');
  // Replace any non-MRZ char with filler '<'
  t = t.replaceAll(RegExp(r'[^A-Z0-9<]'), '<');
  return t;
}

// Try to recover from a common TD3 mis-scan where an extra '<' appears before nationality.
// See _td3AlignmentOffset below for implementation used.

// Safer version to compute TD3 alignment offset with strict NAT check
int _td3AlignmentOffset(String l2) {
  final s = l2.padRight(44, '<');
  // 1) Try to anchor by finding a 3-letter nationality near index 10
  int? natAnchor() {
    int bestOffset = 0;
    int bestDist = 999;
    for (int i = 8; i <= 12; i++) {
      if (i + 3 <= s.length) {
        final nat = s.substring(i, i + 3);
        if (RegExp(r'^[A-Z]{3}$').hasMatch(nat)) {
          final off = i - 10;
          final dist = (off).abs();
          if (dist < bestDist) { bestDist = dist; bestOffset = off; }
        }
      }
    }
    return bestDist == 999 ? null : bestOffset;
  }
  bool natOkAt(int o) {
    final natStart = 10 + o;
    if (natStart < 0 || natStart + 3 > s.length) return false;
    final nat = s.substring(natStart, natStart + 3);
    return RegExp(r'^[A-Z]{3}$').hasMatch(nat);
  }
  bool okAt(int o) {
    if (13 + o < 0 || 28 + o > s.length) return false;
    final dob = s.substring(13 + o, 19 + o);
    final dobCd = s.substring(19 + o, 20 + o);
    final exp = s.substring(21 + o, 27 + o);
    final expCd = s.substring(27 + o, 28 + o);
    final dobOk = MrzUtils.computeCheckDigit(dob) == dobCd;
    final expOk = MrzUtils.computeCheckDigit(exp) == expCd;
    return dobOk && expOk;
  }
  if (okAt(0)) return 0;
  // Use nationality anchor if available
  final anchor = natAnchor();
  if (anchor != null && anchor != 0) return anchor;
  // Prefer offsets that also fix nationality, but accept pure checksum matches too
  for (final o in const [-2, -1, 1, 2, -3, 3, -4, 4]) {
    if (okAt(o) && natOkAt(o)) return o;
  }
  for (final o in const [-2, -1, 1, 2, -3, 3, -4, 4]) {
    if (okAt(o)) return o;
  }
  return 0;
}

String _alignTd3Line2(String l2, int offset) {
  var s = l2;
  if (offset > 0) {
    // remove 'offset' chars at index 10
    if (s.length > 10) {
      final cut = (10 + offset) <= s.length ? (10 + offset) : s.length;
      s = s.substring(0, 10) + s.substring(cut);
    }
  } else if (offset < 0) {
    // insert '<' repeated at index 10
    final ins = '<' * (-offset);
    if (s.length >= 10) {
      s = s.substring(0, 10) + ins + s.substring(10);
    } else {
      s = s.padRight(10, '<') + ins + (s.length > 10 ? s.substring(10) : '');
    }
  }
  if (s.length > 44) s = s.substring(0, 44);
  if (s.length < 44) s = s.padRight(44, '<');
  return s;
}

String? _tryCorrectTd3Line2(String l2) {
  var s = l2.padRight(44, '<');
  // Correct document number (positions 0..8) using limited OCR swaps if it fixes check digit at position 9
  final doc = s.substring(0, 9);
  final docCd = s.substring(9, 10);
  final docFixed = _tryCorrectField(doc, docCd, allowLetters: true);
  if (docFixed != null && docFixed != doc) {
    _log('Doc number corrected from "$doc" to "$docFixed"');
    s = docFixed + s.substring(9);
  }
  // Correct DOB (13..18) and EXP (21..26) using digits-only correction
  final dob = s.substring(13, 19);
  final dobCd = s.substring(19, 20);
  final dobFixed = _tryCorrectField(dob, dobCd, allowLetters: false);
  if (dobFixed != null && dobFixed != dob) {
    _log('DOB corrected from "$dob" to "$dobFixed"');
    s = s.substring(0, 13) + dobFixed + s.substring(19);
  }
  final exp = s.substring(21, 27);
  final expCd = s.substring(27, 28);
  final expFixed = _tryCorrectField(exp, expCd, allowLetters: false);
  if (expFixed != null && expFixed != exp) {
    _log('EXP corrected from "$exp" to "$expFixed"');
    s = s.substring(0, 21) + expFixed + s.substring(27);
  }
  // Validate now
  final l1dummy = ''.padRight(44, '<');
  if (MrzUtils.validateTd3(l1dummy, s) == null) {
    return s;
  }
  return null;
}

String? _tryCorrectField(String field, String check, {required bool allowLetters}) {
  // If already valid, return as-is
  if (MrzUtils.computeCheckDigit(field) == check) return field;
  // Build candidate sets per character
  final candidates = <List<String>>[];
  for (final ch in field.split('')) {
    if (RegExp(r'^[0-9]$').hasMatch(ch)) {
      candidates.add([ch]);
      continue;
    }
    if (!allowLetters) {
      final mapped = _digitCandidates(ch);
      if (mapped.isEmpty) return null; // cannot correct
      candidates.add(mapped);
    } else {
      // For doc number allow either keep as-is or swap ambiguous letters to digits.
      final mapped = _digitCandidates(ch);
      final list = <String>{ch, ...mapped}.toList();
      candidates.add(list);
    }
  }
  // DFS search with cap
  final buf = List<String>.filled(field.length, '0');
  String? result;
  int explored = 0;
  String? dfs(int i) {
    if (explored > 5000) return null; // safety cap
    if (i == field.length) {
      explored++;
      final s = buf.join();
      if (MrzUtils.computeCheckDigit(s) == check) return s;
      return null;
    }
    for (final c in candidates[i]) {
      buf[i] = c;
      final r = dfs(i + 1);
      if (r != null) return r;
    }
    return null;
  }
  result = dfs(0);
  return result;
}

List<String> _digitCandidates(String ch) {
  switch (ch) {
    case '<':
      return ['0'];
    case 'O':
    case 'D':
    case 'Q':
      return ['0'];
    case 'I':
    case 'L':
      return ['1'];
    case 'Z':
      return ['2'];
    case 'S':
      return ['5'];
    case 'B':
      return ['8'];
    case 'G':
      return ['6'];
    case 'A':
      return ['8', '4'];
  }
  return const [];
}

DateTime parseYYMMDD(String s) {
  // Simple YYMMDD parser with 1900/2000 pivot at 1980/2080
  if (s.length < 6) return DateTime(1970, 1, 1);
  final yy = int.tryParse(s.substring(0, 2)) ?? 0;
  final mm = int.tryParse(s.substring(2, 4)) ?? 1;
  final dd = int.tryParse(s.substring(4, 6)) ?? 1;
  final year = yy >= 80 ? 1900 + yy : 2000 + yy;
  return DateTime(year, mm, dd);
}

DateTime _parseYMD(String s) => parseYYMMDD(s);

class _ParsedMrz {
  final String issuer;
  final String surname;
  final String given;
  final String docNo;
  final String nationality;
  final DateTime dob;
  final String sex;
  final DateTime expiry;
  _ParsedMrz({
    required this.issuer,
    required this.surname,
    required this.given,
    required this.docNo,
    required this.nationality,
    required this.dob,
    required this.sex,
    required this.expiry,
  });
}

_ParsedMrz _parseMrzFallback(List<String> lines) {
  final isTD1 = (lines.length > 2 && lines[2].trim().isNotEmpty);
  String issuer;
  String surname;
  String given;
  String docNo;
  String nationality;
  DateTime dob;
  String sex;
  DateTime expiry;
  if (!isTD1) {
    issuer = safeSub(lines[0], 2, 5);
    final nameField = safeSub(lines[0], 5, lines[0].length);
    final nameParts = nameField.split('<<');
    surname = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', ' ').trim() : '';
    given = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';
    docNo = safeSub(lines[1], 0, 9).replaceAll('<', '');
    nationality = safeSub(lines[1], 10, 13);
    dob = parseYYMMDD(safeSub(lines[1], 13, 19));
    sex = safeSub(lines[1], 20, 21);
    expiry = parseYYMMDD(safeSub(lines[1], 21, 27));
  } else {
    issuer = safeSub(lines[0], 2, 5);
    docNo = safeSub(lines[0], 5, 14).replaceAll('<', '');
    nationality = safeSub(lines[1], 10, 13);
    dob = parseYYMMDD(safeSub(lines[1], 13, 19));
    sex = safeSub(lines[1], 20, 21);
    expiry = parseYYMMDD(safeSub(lines[1], 21, 27));
    final nameField = lines[2];
    final nameParts = nameField.split('<<');
    surname = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', ' ').trim() : '';
    given = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';
  }
  return _ParsedMrz(
    issuer: issuer,
    surname: surname,
    given: given,
    docNo: docNo,
    nationality: nationality,
    dob: dob,
    sex: sex,
    expiry: expiry,
  );
}
