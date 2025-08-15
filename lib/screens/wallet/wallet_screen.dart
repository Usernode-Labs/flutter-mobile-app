import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../models/transaction_model.dart';
import '../../services/wallet_service.dart';
import '../../widgets/wallet/wallet_widgets.dart';
import 'send_screen.dart';
import 'receive_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WalletService _walletService;
  late WalletBalance _balance;
  late List<TransactionModel> _transactions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _walletService = WalletService.instance;
    _loadWalletData();
  }

  void _loadWalletData() {
    setState(() {
      _balance = _walletService.getBalance();
      _transactions = _walletService.getRecentTransactions();
    });
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _balance = _walletService.toggleBalanceVisibility();
    });
  }

  Future<void> _refreshWallet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _walletService.refreshWalletData();
      _loadWalletData();
    } catch (e) {
      _showErrorSnackBar('Failed to refresh wallet data');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleSendTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SendScreen()),
    );
  }

  void _handleReceiveTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReceiveScreen()),
    );
  }

  void _handleTransactionTap(TransactionModel transaction) {
    // TODO: Navigate to transaction details
    _showComingSoon('Transaction details for ${transaction.title}');
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wallet),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshWallet,
              tooltip: 'Refresh wallet',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshWallet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallet Balance Card
              WalletBalanceCard(
                balance: _balance,
                onVisibilityToggle: _toggleBalanceVisibility,
              ),

              const SizedBox(height: 20),

              // Quick Actions
              QuickActionsRow(
                onSendTap: _handleSendTap,
                onReceiveTap: _handleReceiveTap,
              ),

              const SizedBox(height: 24),

              // Recent Transactions Header
              Text(
                'Recent Transactions',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              // Transaction List
              TransactionsList(
                transactions: _transactions,
                onTransactionTap: _handleTransactionTap,
              ),

              // Add some bottom padding for better scrolling experience
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
