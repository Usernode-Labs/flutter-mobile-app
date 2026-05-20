import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';

/// Formats a duration in milliseconds to a human-friendly string.
///
/// Values < 1000 → "253 ms", values >= 1000 → "1.6 sec" (1 decimal).
String formatDurationMs(int ms) {
  if (ms < 1000) return '$ms ms';
  return '${(ms / 1000).toStringAsFixed(1)} sec';
}

/// Builds a [ZkIdentityStatusData] from a [ZkPassportLocalRegistration].
///
/// Extracts date formatting, nullifier truncation, face-match label, and
/// optional timing rows into a shared pure function used by both the
/// challenge detail screen and the standalone success dialog.
ZkIdentityStatusData buildZkIdentityStatusData(
  ZkPassportLocalRegistration reg,
  AppLocalizations l10n, {
  VoidCallback? onCopyProofId,
}) {
  final date = reg.registeredAtMs != null
      ? DateFormat.yMMMd().format(
          DateTime.fromMillisecondsSinceEpoch(reg.registeredAtMs!),
        )
      : null;

  String? truncatedNullifier;
  if (reg.nullifierHex != null && reg.nullifierHex!.length >= 12) {
    final hex = reg.nullifierHex!;
    truncatedNullifier =
        '${hex.substring(0, 8)}...${hex.substring(hex.length - 4)}';
  }

  final facematchLabel =
      reg.facematchVerified == true ? 'Verified' : 'Not requested';

  return ZkIdentityStatusData(
    steps: [
      ZkIdentityStatusStep(
        icon: Symbols.check_circle_sharp,
        label: l10n.zkIdentityStatusUniqueness,
        value: l10n.zkIdentityStatusUniquenessValue,
      ),
      ZkIdentityStatusStep(
        icon: Symbols.face_sharp,
        label: l10n.zkIdentityStatusFaceMatchLabel,
        value: facematchLabel,
      ),
      ZkIdentityStatusStep(
        icon: Symbols.shield_sharp,
        label: 'Privacy',
        value: l10n.zkIdentityStatusPrivacyValue,
      ),
      if (date != null)
        ZkIdentityStatusStep(
          icon: Symbols.calendar_today_sharp,
          label: 'Verified',
          value: date,
        ),
      if (truncatedNullifier != null)
        ZkIdentityStatusStep(
          icon: Symbols.fingerprint_sharp,
          label: 'Proof ID',
          value: truncatedNullifier,
          monospace: true,
          onTap: onCopyProofId,
        ),
      if (reg.verifyOuterMs != null)
        ZkIdentityStatusStep(
          icon: Symbols.verified_user_sharp,
          label: 'Verify',
          value: formatDurationMs(reg.verifyOuterMs!),
        ),
      if (reg.wrapOuterMs != null)
        ZkIdentityStatusStep(
          icon: Symbols.wrap_text_sharp,
          label: 'Wrap',
          value: formatDurationMs(reg.wrapOuterMs!),
        ),
      if (reg.verifyWrappedMs != null)
        ZkIdentityStatusStep(
          icon: Symbols.check_circle_sharp,
          label: 'Final Check',
          value: formatDurationMs(reg.verifyWrappedMs!),
        ),
    ],
  );
}
