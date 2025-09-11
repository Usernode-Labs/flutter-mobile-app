import 'package:flutter/material.dart';
import 'review_send_screen.dart';
import 'package:flutter/services.dart';

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
  static final TextInputFormatter decimalFormatter = TextInputFormatter.withFunction(
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
      return newValue.copyWith(text: normalized, selection: adjustedSelection, composing: TextRange.empty);
    },
  );

  void _proceedToReview() {
    if (!_formKey.currentState!.validate()) return;

    final recipient = _recipientController.text.trim();
    final amount = _amountController.text.trim();
    final memo = _memoController.text.trim().isEmpty ? null : _memoController.text.trim();
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
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Send',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        centerTitle: false,
      ),
      body: Padding(
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    );
  }
}
