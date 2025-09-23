import 'package:drift/drift.dart';
import '../database_helper.dart';

/// Repository for managing wallet data using Drift ORM
class WalletRepository {
  final AppDatabase _database;

  WalletRepository(this._database);

  /// Get all wallets
  Future<List<Wallet>> getAllWallets() async {
    return await _database.select(_database.wallets).get();
  }

  /// Get wallet by ID
  Future<Wallet?> getWalletById(int id) async {
    return await (_database.select(_database.wallets)
          ..where((wallet) => wallet.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get wallet by transaction sender name
  Future<Wallet?> getWalletBySenderName(String senderName) async {
    return await (_database.select(_database.wallets)
          ..where((wallet) => wallet.transactionSenderName.equals(senderName)))
        .getSingleOrNull();
  }

  /// Create a new wallet
  Future<int> createWallet({
    required String name,
    required String transactionSenderName,
    double amount = 0.0,
  }) async {
    return await _database.into(_database.wallets).insert(
          WalletsCompanion.insert(
            name: name,
            transactionSenderName: transactionSenderName,
            amount: Value(amount),
          ),
        );
  }

  /// Update wallet
  Future<bool> updateWallet(Wallet wallet) async {
    return await _database.update(_database.wallets).replace(wallet);
  }

  /// Update wallet balance
  Future<bool> updateWalletBalance(int walletId, double newBalance) async {
    return await (_database.update(_database.wallets)
          ..where((wallet) => wallet.id.equals(walletId)))
        .write(
      WalletsCompanion(
        amount: Value(newBalance),
        updatedAt: Value(DateTime.now()),
      ),
    ) >
        0;
  }

  /// Delete wallet
  Future<int> deleteWallet(int id) async {
    return await (_database.delete(_database.wallets)
          ..where((wallet) => wallet.id.equals(id)))
        .go();
  }

  /// Get total balance across all wallets
  Future<double> getTotalBalance() async {
    final query = _database.selectOnly(_database.wallets)
      ..addColumns([_database.wallets.amount.sum()]);
    
    final result = await query.getSingle();
    return result.read(_database.wallets.amount.sum()) ?? 0.0;
  }

  /// Get wallets with their transaction counts
  Future<List<WalletWithTransactionCount>> getWalletsWithTransactionCounts() async {
    final query = _database.select(_database.wallets).join([
      leftOuterJoin(
        _database.transactions,
        _database.transactions.walletId.equalsExp(_database.wallets.id),
      ),
    ]);

    final results = await query.get();
    final walletGroups = <int, List<TypedResult>>{};

    // Group results by wallet ID
    for (final result in results) {
      final wallet = result.readTable(_database.wallets);
      walletGroups.putIfAbsent(wallet.id, () => []).add(result);
    }

    // Convert to WalletWithTransactionCount objects
    return walletGroups.entries.map((entry) {
      final wallet = entry.value.first.readTable(_database.wallets);
      final transactionCount = entry.value
          .where((result) => result.readTableOrNull(_database.transactions) != null)
          .length;

      return WalletWithTransactionCount(
        wallet: wallet,
        transactionCount: transactionCount,
      );
    }).toList();
  }
}

/// Data class for wallet with transaction count
class WalletWithTransactionCount {
  final Wallet wallet;
  final int transactionCount;

  const WalletWithTransactionCount({
    required this.wallet,
    required this.transactionCount,
  });

  @override
  String toString() {
    return 'WalletWithTransactionCount(wallet: $wallet, transactionCount: $transactionCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletWithTransactionCount &&
        other.wallet == wallet &&
        other.transactionCount == transactionCount;
  }

  @override
  int get hashCode => Object.hash(wallet, transactionCount);
}
