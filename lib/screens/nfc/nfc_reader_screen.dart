import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../models/nfc_doc.dart';
import '../../services/nfc/document_storage_service.dart';
import '../../services/nfc/nfc_service.dart';
import 'nfc_mrz_input_screen.dart';
import 'mrz_camera_scan_screen.dart';
import 'nfc_read_session_screen.dart';
import 'nfc_doc_detail_screen.dart';

class NfcReaderScreen extends StatefulWidget {
  const NfcReaderScreen({super.key});

  @override
  State<NfcReaderScreen> createState() => _NfcReaderScreenState();
}

class _NfcReaderScreenState extends State<NfcReaderScreen> {
  bool _loading = true;
  List<NfcDoc> _docs = const [];
  NfcAvailability? _availability;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DocumentStorageService.instance.init();
    final avail = await NfcService.instance.checkAvailability();
    setState(() {
      _availability = avail;
      _docs = DocumentStorageService.instance.getAll();
      _loading = false;
    });
  }

  Future<void> _scanAnother() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: Text('Scan MRZ with camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.nfcManualMrz),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'camera') {
      final mrz = await Navigator.of(context).push<MrzData>(
        MaterialPageRoute(builder: (_) => const MrzCameraScanScreen()),
      );
      if (mrz != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NfcReadSessionScreen(mrz: mrz)),
        );
      }
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MrzInputScreen()),
      );
    }
    setState(() { _docs = DocumentStorageService.instance.getAll(); });
  }

  Future<void> _rename(String key, String current) async {
    final controller = TextEditingController(text: current);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).nfcRename),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () async {
              await DocumentStorageService.instance.rename(key, controller.text.trim());
              if (!mounted) return;
              Navigator.pop(ctx);
              setState(() => _docs = DocumentStorageService.instance.getAll());
            },
            child: Text(AppLocalizations.of(ctx).nfcRename),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(String key) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.nfcConfirmDelete),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.nfcDelete)),
        ],
      ),
    );
    if (ok == true) {
      await DocumentStorageService.instance.delete(key);
      setState(() => _docs = DocumentStorageService.instance.getAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final avail = _availability;
    Widget? banner;
    if (avail != null && !avail.supported) {
      banner = _InfoBanner(text: l10n.nfcNotSupported, color: theme.colorScheme.error);
    } else if (avail != null && !avail.enabled) {
      banner = _InfoBanner(text: l10n.nfcTurnOn, color: theme.colorScheme.tertiary);
    }

    if (_docs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.nfcReader)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (banner != null) banner,
              Icon(Icons.contactless, size: 96, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(l10n.nfcEmptyTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(l10n.nfcEmptySubtitle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _scanAnother,
                icon: const Icon(Icons.badge_outlined),
                label: Text(l10n.nfcEmptyTitle),
              ),
            ],
          ),
        ),
      );
    }

    final dateFmt = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nfcReader),
        actions: [
          IconButton(onPressed: _scanAnother, icon: const Icon(Icons.add)),
        ],
      ),
      body: Column(
        children: [
          if (banner != null) banner,
          Expanded(
            child: ListView.separated(
              itemCount: _docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final d = _docs[i];
                final key = DocumentStorageService.keyFor(d.type, d.documentNumber);
                return ListTile(
                  leading: Icon(_iconFor(d.type)),
                  title: Text(d.alias.isNotEmpty ? d.alias : _titleFor(d)),
                  subtitle: Text('${d.type.name.toUpperCase()} · ${d.documentNumber} · ${dateFmt.format(d.lastScannedAt)}'),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NfcDocDetailScreen(doc: d)),
                    );
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _rename(key, d.alias);
                      if (v == 'delete') _delete(key);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: 'rename', child: Text(l10n.nfcRename)),
                      PopupMenuItem(value: 'delete', child: Text(l10n.nfcDelete)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanAnother,
        icon: const Icon(Icons.add),
        label: Text(l10n.nfcScanAnother),
      ),
    );
  }

  IconData _iconFor(DocumentType t) {
    switch (t) {
      case DocumentType.passport:
        return Icons.book_outlined;
      case DocumentType.idCard:
        return Icons.badge_outlined;
      case DocumentType.unknown:
      default:
        return Icons.description_outlined;
    }
  }

  String _titleFor(NfcDoc d) => [d.givenNames, d.surname].where((e) => e.trim().isNotEmpty).join(' ').trim();
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  const _InfoBanner({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: color.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
          )
        ],
      ),
    );
  }
}
