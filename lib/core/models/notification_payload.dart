/// Model for parsing notification payloads
class NotificationPayload {
  final NotificationPayloadType type;
  final int? singleSlot;
  final List<int>? groupedSlots;

  NotificationPayload({
    required this.type,
    this.singleSlot,
    this.groupedSlots,
  });

  /// Parse notification payload string into structured data
  ///
  /// Supported formats:
  /// - "slot:123:upcoming" → Single upcoming slot
  /// - "slot:123:produced" → Single produced block
  /// - "slot:123:missed" → Single missed slot
  /// - "slots:grouped:123,456,789" → Multiple grouped slots
  static NotificationPayload? parse(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    final parts = payload.split(':');
    if (parts.isEmpty) return null;

    try {
      // Pattern: "slot:123:upcoming|produced|missed"
      if (parts[0] == 'slot' && parts.length == 3) {
        final slotNum = int.tryParse(parts[1]);
        if (slotNum == null) return null;

        final typeStr = parts[2];
        NotificationPayloadType? type;

        switch (typeStr) {
          case 'upcoming':
            type = NotificationPayloadType.upcoming;
            break;
          case 'produced':
            type = NotificationPayloadType.produced;
            break;
          case 'missed':
            type = NotificationPayloadType.missed;
            break;
          default:
            return null;
        }

        return NotificationPayload(
          type: type,
          singleSlot: slotNum,
        );
      }

      // Pattern: "slots:grouped:123,456,789"
      if (parts[0] == 'slots' && parts[1] == 'grouped' && parts.length == 3) {
        final slots = parts[2]
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .where((n) => n != null)
            .cast<int>()
            .toList();

        if (slots.isEmpty) return null;

        return NotificationPayload(
          type: NotificationPayloadType.grouped,
          groupedSlots: slots,
        );
      }

      return null;
    } catch (e) {
      // Invalid payload format
      return null;
    }
  }

  /// Check if this is a single slot notification
  bool get isSingleSlot => singleSlot != null;

  /// Check if this is a grouped notification
  bool get isGrouped => groupedSlots != null && groupedSlots!.isNotEmpty;

  /// Get all slot numbers (for both single and grouped)
  List<int> get allSlots {
    if (isSingleSlot) return [singleSlot!];
    if (isGrouped) return groupedSlots!;
    return [];
  }
}

/// Type of notification payload
enum NotificationPayloadType {
  upcoming,
  produced,
  missed,
  grouped,
}
