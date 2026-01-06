import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _feeController = TextEditingController(text: '1');
  final _memoController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _feeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _onSend() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Send functionality will be implemented')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Send'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  theme: theme,
                  controller: _addressController,
                  hint: 'Recipient address',
                  validator:
                      _validateRequired('recipient address', minLength: 20),
                ),
                const SizedBox(height: 18),
                _buildField(
                  theme: theme,
                  controller: _amountController,
                  hint: 'Amount',
                  isNumeric: true,
                  validator: _validatePositiveNumber('amount'),
                ),
                const SizedBox(height: 18),
                _buildField(
                  theme: theme,
                  controller: _feeController,
                  hint: 'Fee',
                  isNumeric: true,
                  validator: _validatePositiveNumber('fee', allowZero: true),
                ),
                const SizedBox(height: 18),
                _buildField(
                  theme: theme,
                  controller: _memoController,
                  hint: 'Memo (optional)',
                  maxLines: 4,
                ),
                const Spacer(),
                _buildSendButton(theme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required ThemeData theme,
    required TextEditingController controller,
    required String hint,
    bool isNumeric = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(6),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade600,
              width: 1,
            ),
          ),
        ),
        child: TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.all(16),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black87, fontSize: 16),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ElevatedButton(
        onPressed: _onSend,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: const Text(
          'Send',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String? Function(String?) _validateRequired(String fieldName,
      {int minLength = 1}) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter a $fieldName';
      }
      if (value.trim().length < minLength) {
        return '${fieldName[0].toUpperCase()}${fieldName.substring(1)} appears to be too short';
      }
      return null;
    };
  }

  String? Function(String?) _validatePositiveNumber(String fieldName,
      {bool allowZero = false}) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter a $fieldName';
      }
      final number = double.tryParse(value.trim());
      if (number == null || (allowZero ? number < 0 : number <= 0)) {
        return 'Please enter a valid $fieldName';
      }
      return null;
    };
  }
}
