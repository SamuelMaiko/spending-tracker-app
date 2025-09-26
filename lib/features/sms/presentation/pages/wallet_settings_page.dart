import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/repositories/wallet_repository.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../dependency_injector.dart';

/// Page for managing wallets and their settings
class WalletSettingsPage extends StatefulWidget {
  const WalletSettingsPage({super.key});

  @override
  State<WalletSettingsPage> createState() => _WalletSettingsPageState();
}

class _WalletSettingsPageState extends State<WalletSettingsPage> {
  final WalletRepository _walletRepository = sl<WalletRepository>();
  List<Wallet> _wallets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final wallets = await _walletRepository.getAllWallets();
      setState(() {
        _wallets = wallets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading wallets: $e')));
      }
    }
  }

  void _showEditBalanceDialog(Wallet wallet) {
    final TextEditingController balanceController = TextEditingController(
      text: wallet.amount.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Edit ${wallet.name} Balance',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),

                // Balance input field
                TextField(
                  controller: balanceController,
                  decoration: const InputDecoration(
                    labelText: 'Balance',
                    prefixText: 'KSh ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  autofocus: true,
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final balanceText = balanceController.text.trim();
                          if (balanceText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a balance'),
                              ),
                            );
                            return;
                          }

                          final balance = double.tryParse(balanceText);
                          if (balance == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid balance'),
                              ),
                            );
                            return;
                          }

                          try {
                            final updatedWallet = wallet.copyWith(
                              amount: balance,
                            );
                            await _walletRepository.updateWallet(updatedWallet);
                            if (mounted) {
                              Navigator.pop(context);
                              await _loadWallets();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${wallet.name} balance updated successfully',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error updating balance: $e'),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Update'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Settings'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallets.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadWallets,
              child: const Center(
                child: Text(
                  'No wallets found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadWallets,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _wallets.length,
                itemBuilder: (context, index) {
                  final wallet = _wallets[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        backgroundImage: _getWalletImage(wallet.name),
                      ),
                      title: Text(
                        wallet.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'KSh ${wallet.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: wallet.amount >= 0
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => _showEditBalanceDialog(wallet),
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Balance',
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  ImageProvider? _getWalletImage(String walletName) {
    switch (walletName.toLowerCase()) {
      case 'm-pesa':
        return const AssetImage('assets/images/mpesa_logo.png');
      case 'pochi la biashara':
      case 'pochi':
        return const AssetImage('assets/images/pochi_logo.jpeg');
      case 'm-shwari':
        return const AssetImage('assets/images/mshwari_logo.png');
      case 'sc bank':
        return const AssetImage('assets/images/sc_bank_logo.png');
      case 'equity bank':
        return const AssetImage('assets/images/equity_bank_logo.png');
      case 'cash':
        return const AssetImage('assets/images/cash_logo.jpeg');
      default:
        return const AssetImage('assets/images/default_wallet_logo.png');
    }
  }
}
