import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/receive_models.dart';
import '../../theme/app_theme.dart';

class QRCodeCard extends StatelessWidget {
  final String qrData;
  final VoidCallback? onTap;

  const QRCodeCard({
    Key? key,
    required this.qrData,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Scan QR Code',
              style: AppTheme.nodeStatusStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'QR Code',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap to enlarge',
              style: AppTheme.nodeSubtitleStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class AddressDisplayCard extends StatelessWidget {
  final ReceiveAddress address;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback? onGenerateNew;

  const AddressDisplayCard({
    Key? key,
    required this.address,
    required this.onCopy,
    required this.onShare,
    this.onGenerateNew,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Address',
                  style: AppTheme.nodeStatusStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onGenerateNew != null)
                  GestureDetector(
                    onTap: onGenerateNew,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'New',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      address.address,
                      style: AppTheme.nodeStatusStyle.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onCopy,
                    child: Icon(
                      Icons.copy,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip(context, address.typeLabel, address.type),
                const SizedBox(width: 8),
                _buildStatusChip(context, address.statusText, null,
                    color: address.isValid
                        ? AppTheme.successCheckColor
                        : AppTheme.pendingIconColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
      BuildContext context, String label, ReceiveAddressType? type,
      {Color? color}) {
    Color chipColor;
    if (color != null) {
      chipColor = color;
    } else if (type != null) {
      switch (type) {
        case ReceiveAddressType.standard:
          chipColor = AppTheme.multiplierColor;
          break;
        case ReceiveAddressType.temporary:
          chipColor = AppTheme.pendingIconColor;
          break;
        case ReceiveAddressType.stealth:
          chipColor = AppTheme.successCheckColor;
          break;
      }
    } else {
      chipColor = AppTheme.nodeIconColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class PaymentRequestForm extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController memoController;
  final String? amountError;
  final VoidCallback onCreateRequest;
  final bool isLoading;

  const PaymentRequestForm({
    Key? key,
    required this.amountController,
    required this.memoController,
    this.amountError,
    required this.onCreateRequest,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Specific Amount',
              style: AppTheme.nodeStatusStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount (Optional)',
                hintText: '0.00',
                suffixText: 'TOKENS',
                suffixStyle: AppTheme.nodeSubtitleStyle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: amountError,
              ),
              style: AppTheme.nodeStatusStyle,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: memoController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Payment for...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: AppTheme.nodeStatusStyle,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onCreateRequest,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.qr_code),
                label: Text(isLoading ? 'Creating...' : 'Create QR Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddressHistoryCard extends StatelessWidget {
  final List<ReceiveAddress> addresses;
  final Function(ReceiveAddress) onAddressSelected;

  const AddressHistoryCard({
    Key? key,
    required this.addresses,
    required this.onAddressSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: AppTheme.nodeIconColor,
              ),
              SizedBox(height: 16),
              Text(
                'No Address History',
                style: AppTheme.nodeStatusStyle,
              ),
              SizedBox(height: 8),
              Text(
                'Generated addresses will appear here',
                style: AppTheme.nodeSubtitleStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Address History',
              style: AppTheme.nodeStatusStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...addresses
                .take(5)
                .map((address) => _buildAddressHistoryItem(
                      context,
                      address,
                    ))
                .toList(),
            if (addresses.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Show all addresses
                  },
                  child: Text('View All (${addresses.length})'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressHistoryItem(
      BuildContext context, ReceiveAddress address) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => onAddressSelected(address),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: address.isValid
                    ? AppTheme.successCheckColor
                    : AppTheme.nodeIconColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.formattedAddress,
                    style: AppTheme.nodeStatusStyle.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        address.typeLabel,
                        style:
                            AppTheme.nodeSubtitleStyle.copyWith(fontSize: 10),
                      ),
                      Text(' • ',
                          style: AppTheme.nodeSubtitleStyle
                              .copyWith(fontSize: 10)),
                      Text(
                        address.statusText,
                        style:
                            AppTheme.nodeSubtitleStyle.copyWith(fontSize: 10),
                      ),
                      if (address.totalReceived > 0) ...[
                        Text(' • ',
                            style: AppTheme.nodeSubtitleStyle
                                .copyWith(fontSize: 10)),
                        Text(
                          '${address.totalReceived.toStringAsFixed(2)} received',
                          style: AppTheme.nodeSubtitleStyle.copyWith(
                            fontSize: 10,
                            color: AppTheme.successCheckColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppTheme.nodeIconColor,
            ),
          ],
        ),
      ),
    );
  }
}
