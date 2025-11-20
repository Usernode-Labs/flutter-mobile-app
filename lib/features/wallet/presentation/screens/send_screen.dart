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

  // Preset addresses for quick selection (TreeHash with version 5)
  static const List<String> _presetAddresses = [
    'ut1na9lq2yny9l2l6axf09g3mhhmhed3vj7tpejs4f28xe2cjd6n5qqg9ww4x',
    'ut1h9r5yjsxxnhj7pmeagma2qaef5n587fnqlmxkcpladtrt3l53ghqu5em02',
    'ut1zd2afm8kv792mfxwc0txyvqz2ujn5f3jpz3h2zyzn5f9jyqyhywsga4rve',
    'ut1782ys0a8zrc664qge74ywlm3yhns9c3gg5k5hm0ktjljpxttlvpq3e7rap',
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
                    final shortAddress =
                        '${address.substring(0, 6)}...${address.substring(address.length - 4)}';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.account_balance_wallet,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
    // Memo and fee are disabled; do not send them
    final String? memo = null;
    final String? networkFee = null;

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
          showNodeStatus: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          // Recipient Address Field
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: TextFormField(
                              controller: _recipientController,
                              decoration: InputDecoration(
                                hintText: 'Recipient Address',
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    Icons.contacts,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),

                          // Amount Field
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                suffixIcon: _amountFocus.hasFocus
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: TextButton(
                                          onPressed: () =>
                                              _amountFocus.unfocus(),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),

                          // Memo Field (disabled)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: TextFormField(
                              controller: _memoController,
                              decoration: InputDecoration(
                                hintText: 'Memo (disabled)',
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                              ),
                              enabled: false,
                              readOnly: true,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                'Memo is disabled in this build.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),

                          // Network Fee Field (disabled)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: TextFormField(
                              controller: _networkFeeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: false),
                              inputFormatters: [decimalFormatter],
                              enableSuggestions: false,
                              autocorrect: false,
                              textInputAction: TextInputAction.done,
                              focusNode: _feeFocus,
                              onEditingComplete: () => _feeFocus.unfocus(),
                              onFieldSubmitted: (_) => _feeFocus.unfocus(),
                              decoration: InputDecoration(
                                hintText: 'Network Fee (disabled)',
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                suffixIcon: _feeFocus.hasFocus
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: TextButton(
                                          onPressed: () => _feeFocus.unfocus(),
                                          child: const Text('Done'),
                                        ),
                                      )
                                    : null,
                              ),
                              enabled: false,
                              readOnly: true,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 32.0),
                              child: Text(
                                'Network fee is disabled in this build.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

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
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
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
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
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
