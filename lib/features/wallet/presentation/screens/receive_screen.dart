import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/receive_models.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/receive_service.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/widgets/receive_widgets.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  ReceiveAddress? _address;
  bool _loading = true;
  AccountMeta? _account;
  bool _accountLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _loadAccount();
  }

  Future<void> _loadAddress() async {
    final addr = await ReceiveService.instance.getCurrentAddress();
    if (!mounted) return;
    setState(() {
      _address = addr;
      _loading = false;
    });
  }

  Future<void> _loadAccount() async {
    final repo = await AccountsRepository.create();
    final active = await repo.getActive();
    if (!mounted) return;
    setState(() {
      _account = active;
      _accountLoading = false;
    });
  }

  String _shortAddr(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 6);
    final end = addr.substring(addr.length - 4);
    return '$start…$end';
  }

  void _copy(String value, {String label = 'Address'}) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Receive',
        showNotifications: false,
        showNodeStatus: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _address == null
              ? const Center(child: Text('Failed to load address'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // QR Code card
                      QRCodeCard(
                        qrData: _address!.address,
                        onTap: () {
                          // Future: expand to full screen
                        },
                      ),
                      const SizedBox(height: 16),
                      // Account + Address section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _accountLoading
                                    ? 'Loading account…'
                                    : (_account?.name ?? 'Account'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _shortAddr(_address!.address),
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Copy address',
                                    icon: const Icon(Icons.copy_rounded),
                                    onPressed: () => _copy(_address!.address,
                                        label: 'Address'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
