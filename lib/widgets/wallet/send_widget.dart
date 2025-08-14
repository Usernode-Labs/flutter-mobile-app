import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/send_models.dart';
import '../../theme/app_theme.dart';

class RecipientInputCard extends StatelessWidget {
  final TextEditingController controller;
  final String? contactName;
  final VoidCallback onScanQR;
  final Function(String) onAddressChanged;
  final String? errorText;

  const RecipientInputCard({
    Key? key,
    required this.controller,
    this.contactName,
    required this.onScanQR,
    required this.onAddressChanged,
    this.errorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recipient',
                  style: AppTheme.nodeStatusStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: onScanQR,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Scan',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              onChanged: onAddressChanged,
              decoration: InputDecoration(
                hintText: 'Enter wallet address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.error),
                ),
                errorText: errorText,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: AppTheme.nodeStatusStyle,
            ),
            if (contactName != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successCheckColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: AppTheme.successCheckColor,
                    ),
                    SizedBox(width: 4),
                    Text(
                      contactName!,
                      style: TextStyle(
                        color: AppTheme.successCheckColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AmountInputCard extends StatelessWidget {
  final TextEditingController controller;
  final double availableBalance;
  final VoidCallback onMaxTap;
  final String? errorText;

  const AmountInputCard({
    Key? key,
    required this.controller,
    required this.availableBalance,
    required this.onMaxTap,
    this.errorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount',
                  style: AppTheme.nodeStatusStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: onMaxTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'MAX',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                hintText: '0.00',
                suffixText: 'TOKENS',
                suffixStyle: AppTheme.nodeSubtitleStyle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.error),
                ),
                errorText: errorText,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Available: ${availableBalance.toStringAsFixed(2)} TOKENS',
              style: AppTheme.nodeSubtitleStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class FeeSelectionCard extends StatelessWidget {
  final FeeType selectedFee;
  final NetworkFee networkFees;
  final Function(FeeType) onFeeSelected;
  final TextEditingController? customFeeController;

  const FeeSelectionCard({
    Key? key,
    required this.selectedFee,
    required this.networkFees,
    required this.onFeeSelected,
    this.customFeeController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network Fee',
              style: AppTheme.nodeStatusStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            ...FeeType.values.map((feeType) => _buildFeeOption(
                  context,
                  theme,
                  feeType,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeOption(
      BuildContext context, ThemeData theme, FeeType feeType) {
    final isSelected = selectedFee == feeType;
    final fee = networkFees.getFeeForType(feeType);
    final timeEstimate = networkFees.getTimeEstimate(feeType);

    String title;
    String subtitle;
    switch (feeType) {
      case FeeType.slow:
        title = 'Slow';
        subtitle = 'Lower priority';
        break;
      case FeeType.standard:
        title = 'Standard';
        subtitle = 'Recommended';
        break;
      case FeeType.fast:
        title = 'Fast';
        subtitle = 'Higher priority';
        break;
      case FeeType.custom:
        title = 'Custom';
        subtitle = 'Set your own fee';
        break;
    }

    return GestureDetector(
      onTap: () => onFeeSelected(feeType),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.nodeStatusStyle.copyWith(
                          color: isSelected ? theme.colorScheme.primary : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTheme.nodeSubtitleStyle,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${fee.toStringAsFixed(3)} TOKENS',
                      style: AppTheme.nodeStatusStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      timeEstimate,
                      style: AppTheme.nodeSubtitleStyle,
                    ),
                  ],
                ),
              ],
            ),
            if (feeType == FeeType.custom && isSelected) ...[
              SizedBox(height: 12),
              TextField(
                controller: customFeeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter custom fee',
                  suffixText: 'TOKENS',
                  suffixStyle: AppTheme.nodeSubtitleStyle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                style: AppTheme.nodeStatusStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TransactionSummaryCard extends StatelessWidget {
  final SendRequest request;
  final double fee;
  final double total;
  final String? contactName;

  const TransactionSummaryCard({
    Key? key,
    required this.request,
    required this.fee,
    required this.total,
    this.contactName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Summary',
              style: AppTheme.nodeStatusStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            _buildSummaryRow('To:', contactName ?? 'Unknown Contact'),
            _buildSummaryRow('Address:', request.toAddress, isAddress: true),
            _buildSummaryRow(
                'Amount:', '${request.amount.toStringAsFixed(2)} TOKENS'),
            _buildSummaryRow(
                'Network Fee:', '${fee.toStringAsFixed(3)} TOKENS'),
            if (request.memo != null && request.memo!.isNotEmpty)
              _buildSummaryRow('Memo:', request.memo!),
            Divider(height: 24),
            _buildSummaryRow(
              'Total:',
              '${total.toStringAsFixed(3)} TOKENS',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isAddress = false, bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.nodeSubtitleStyle,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isTotal
                  ? AppTheme.nodeStatusStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    )
                  : AppTheme.nodeStatusStyle,
              overflow: isAddress ? TextOverflow.ellipsis : null,
            ),
          ),
        ],
      ),
    );
  }
}
