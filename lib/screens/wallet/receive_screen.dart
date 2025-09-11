import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/receive_models.dart';
import '../../services/receive_service.dart';
import 'package:crypto_mobile_app/services/accounts_repository.dart';
import 'package:crypto_mobile_app/models/account.dart';
import '../../widgets/wallet/receive_widgets.dart';

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
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Receive',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
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
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.black87,
                                        fontFeatures: const [],
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
