class MrzUtils {
  static const List<int> _weights = [7, 3, 1];

  static int _valueOf(String ch) {
    final c = ch.codeUnitAt(0);
    // '0'..'9' -> 0..9
    if (c >= 0x30 && c <= 0x39) return c - 0x30;
    // 'A'..'Z' -> 10..35
    if (c >= 0x41 && c <= 0x5A) return (c - 0x41) + 10;
    // '<' or anything else -> 0
    return 0;
  }

  static String computeCheckDigit(String data) {
    var sum = 0;
    for (var i = 0; i < data.length; i++) {
      final v = _valueOf(data[i]);
      sum += v * _weights[i % 3];
    }
    return (sum % 10).toString();
  }

  /// Validates TD3 (passport) MRZ lines: returns null if ok, otherwise a short reason.
  static String? validateTd3(String line1, String line2) {
    if (line1.length < 44 || line2.length < 44) {
      return 'MRZ lines must be 44 characters each.';
    }
    final docNo = line2.substring(0, 9);
    final docNoCd = line2.substring(9, 10);
    final dob = line2.substring(13, 19);
    final dobCd = line2.substring(19, 20);
    final exp = line2.substring(21, 27);
    final expCd = line2.substring(27, 28);

    if (computeCheckDigit(docNo) != docNoCd) {
      return 'Document number checksum mismatch.';
    }
    if (computeCheckDigit(dob) != dobCd) {
      return 'Date of birth checksum mismatch.';
    }
    if (computeCheckDigit(exp) != expCd) {
      return 'Date of expiry checksum mismatch.';
    }
    return null;
  }

  /// Minimal TD1 validation for common fields. Returns null if OK.
  static String? validateTd1(String line1, String line2, String line3) {
    if (line1.length < 30 || line2.length < 30 || line3.length < 30) {
      return 'MRZ lines must be 30 characters each.';
    }
    // Doc number: line1[5..14], check at line1[14]
    final docNo = line1.substring(5, 14);
    final docNoCd = line1.substring(14, 15);
    // DOB: line2[0..6], check at line2[6]
    final dob = line2.substring(0, 6);
    final dobCd = line2.substring(6, 7);
    // EXP: line2[8..14], check at line2[14]
    final exp = line2.substring(8, 14);
    final expCd = line2.substring(14, 15);

    if (computeCheckDigit(docNo) != docNoCd) {
      return 'Document number checksum mismatch (TD1).';
    }
    if (computeCheckDigit(dob) != dobCd) {
      return 'Date of birth checksum mismatch (TD1).';
    }
    if (computeCheckDigit(exp) != expCd) {
      return 'Date of expiry checksum mismatch (TD1).';
    }
    return null;
  }
}
