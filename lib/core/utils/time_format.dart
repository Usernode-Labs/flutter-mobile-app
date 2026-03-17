/// Formats [dt] as `"HH:MM:SS"` (24-hour, zero-padded).
String formatHHMMSS(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

/// Formats [dt] as `"HH:MM"` (24-hour, zero-padded, no seconds).
String formatHHMM(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
