import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'review_send_screen.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _networkFeeController = TextEditingController();

  final FocusNode _amountFocus = FocusNode();
  final FocusNode _feeFocus = FocusNode();

  // Preset addresses for quick selection
  static const List<String> _presetAddresses = [
    '0x0000000000000000000000000000000000000000000000000000000000000000',
    '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb4',
    '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
    '0x8f3CF7ad23Cd3CaDbD9735AFf958023239c6A063',
    '0xD4a3BebF2E8b1dC4Ea9E2e3F5C8a7B9E4F1A2C3D',
    '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984',
    '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    '0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD',
    '0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE',
    '0x6B175474E89094C44Da98b954EedeAC495271d0F',
    '0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8',
  ];

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(() => setState(() {}));
    _feeFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _networkFeeController.dispose();
    _amountFocus.dispose();
    _feeFocus.dispose();
    super.dispose();
  }

  // Allow only digits and a single optional decimal separator (dot or comma).
  // Normalizes commas to dots so parsing works with double.parse.
  static final TextInputFormatter decimalFormatter =
      TextInputFormatter.withFunction(
    (oldValue, newValue) {
      final raw = newValue.text;
      if (raw.isEmpty) return newValue;
      // Normalize common locale decimal separators to '.'
      final normalized = raw.replaceAll(RegExp(r'[\,٫，]'), '.');
      final valid = RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(normalized);
      if (!valid) return oldValue;
      final dotCount = '.'.allMatches(normalized).length;
      if (dotCount > 1) return oldValue;
      // Keep selection stable
      final sel = newValue.selection;
      final adjustedSelection = TextSelection(
        baseOffset: sel.baseOffset.clamp(0, normalized.length),
        extentOffset: sel.extentOffset.clamp(0, normalized.length),
      );
      return newValue.copyWith(
          text: normalized,
          selection: adjustedSelection,
          composing: TextRange.empty);
    },
  );

  void _showAddressPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Select Address',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _presetAddresses.length,
                  itemBuilder: (context, index) {
                    final address = _presetAddresses[index];
                    final shortAddress = '${address.substring(0, 6)}...${address.substring(address.length - 4)}';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        shortAddress,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        address,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _recipientController.text = address;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _proceedToReview() {
    if (!_formKey.currentState!.validate()) return;

    final recipient = _recipientController.text.trim();
    final amount = _amountController.text.trim();
    final memo = _memoController.text.trim().isEmpty
        ? null
        : _memoController.text.trim();
    final networkFee = _networkFeeController.text.trim().isEmpty
        ? null
        : _networkFeeController.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSendScreen(
          recipientAddress: recipient,
          amount: amount,
          memo: memo,
          networkFee: networkFee,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(
        title: 'Send',
      ),
      body: SafeArea(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Recipient Address Field
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: TextFormField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    hintText: 'Recipient Address',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.contacts,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _showAddressPicker,
                      tooltip: 'Select from preset addresses',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter recipient address';
                    }
                    return null;
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    "Enter the recipient's wallet address.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),

              // Amount Field
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: false),
                  inputFormatters: [decimalFormatter],
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  focusNode: _amountFocus,
                  onEditingComplete: () => _amountFocus.unfocus(),
                  onFieldSubmitted: (_) => _amountFocus.unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Amount',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    suffixIcon: _amountFocus.hasFocus
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: TextButton(
                              onPressed: () => _amountFocus.unfocus(),
                              child: const Text('Done'),
                            ),
                          )
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Amount to send in tokens.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),

              // Memo Field (optional)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: TextFormField(
                  controller: _memoController,
                  decoration: InputDecoration(
                    hintText: 'Memo',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Optional note; visible to recipient.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),

              // Network Fee Field (optional)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: TextFormField(
                  controller: _networkFeeController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: false),
                  inputFormatters: [decimalFormatter],
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  focusNode: _feeFocus,
                  onEditingComplete: () => _feeFocus.unfocus(),
                  onFieldSubmitted: (_) => _feeFocus.unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Network Fee',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    suffixIcon: _feeFocus.hasFocus
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: TextButton(
                              onPressed: () => _feeFocus.unfocus(),
                              child: const Text('Done'),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: Text(
                    'Optional custom fee; leave blank to use default.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),

              const Spacer(),

              // Continue Button with extra bottom spacing
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _proceedToReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Send',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
