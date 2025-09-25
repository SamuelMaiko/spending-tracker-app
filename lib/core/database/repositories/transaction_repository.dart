import 'package:drift/drift.dart';
import '../database_helper.dart';
import 'wallet_repository.dart';
import '../../services/data_sync_service.dart';

/// Repository for managing transaction data using Drift ORM
class TransactionRepository {
  final AppDatabase _database;

  TransactionRepository(this._database);

  /// Get all transactions
  Future<List<Transaction>> getAllTransactions() async {
    return await (_database.select(
      _database.transactions,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// Get transactions with pagination
  Future<List<Transaction>> getTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    return await (_database.select(_database.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Get transaction by ID
  Future<Transaction?> getTransactionById(int id) async {
    return await (_database.select(
      _database.transactions,
    )..where((transaction) => transaction.id.equals(id))).getSingleOrNull();
  }

  /// Get transaction by SMS hash
  Future<Transaction?> getTransactionBySmsHash(String smsHash) async {
    return await (_database.select(_database.transactions)
          ..where((transaction) => transaction.smsHash.equals(smsHash)))
        .getSingleOrNull();
  }

  /// Get transaction by date and amount (for duplicate detection)
  Future<Transaction?> getTransactionByDateAndAmount(
    DateTime date,
    double amount,
  ) async {
    return await (_database.select(_database.transactions)..where(
          (transaction) =>
              transaction.date.equals(date) & transaction.amount.equals(amount),
        ))
        .getSingleOrNull();
  }

  /// Get the latest transaction with SMS hash (for catch-up functionality)
  Future<Transaction?> getLatestTransactionWithSmsHash() async {
    return await (_database.select(_database.transactions)
          ..where((transaction) => transaction.smsHash.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get the latest processed transaction (for catch-up functionality using date+amount)
  Future<Transaction?> getLatestProcessedTransaction() async {
    return await (_database.select(_database.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get transactions by wallet ID
  Future<List<Transaction>> getTransactionsByWalletId(int walletId) async {
    return await (_database.select(_database.transactions)
          ..where((transaction) => transaction.walletId.equals(walletId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get uncategorized transactions
  Future<List<Transaction>> getUncategorizedTransactions() async {
    return await (_database.select(_database.transactions)
          ..where((transaction) => transaction.status.equals('UNCATEGORIZED'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get transactions by date range
  Future<List<Transaction>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await (_database.select(_database.transactions)
          ..where(
            (transaction) =>
                transaction.date.isBiggerOrEqualValue(startDate) &
                transaction.date.isSmallerOrEqualValue(endDate),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Create a new transaction
  Future<int> createTransaction({
    required int walletId,
    int? categoryItemId,
    required double amount,
    double transactionCost = 0.0,
    required String type, // 'DEBIT' or 'CREDIT'
    String? description,
    required DateTime date,
    String status = 'UNCATEGORIZED',
    String? smsHash,
  }) async {
    final transactionId = await _database
        .into(_database.transactions)
        .insert(
          TransactionsCompanion.insert(
            walletId: walletId,
            categoryItemId: Value(categoryItemId),
            amount: amount,
            transactionCost: Value(transactionCost),
            type: type,
            description: Value(description),
            date: date,
            status: Value(status),
            smsHash: Value(smsHash),
          ),
        );

    // Sync to cloud if enabled
    try {
      final transaction = await getTransactionById(transactionId);
      if (transaction != null) {
        DataSyncService.syncItemToCloud(transaction: transaction);
      }
    } catch (e) {
      // Sync failure shouldn't affect the transaction creation
    }

    return transactionId;
  }

  /// Update transaction
  Future<bool> updateTransaction(Transaction transaction) async {
    final success = await _database
        .update(_database.transactions)
        .replace(transaction);

    // Sync to cloud if enabled
    if (success) {
      DataSyncService.syncItemToCloud(transaction: transaction);
    }

    return success;
  }

  /// Update transaction with wallet balance adjustment
  Future<bool> updateTransactionWithBalanceAdjustment(
    Transaction originalTransaction,
    Transaction updatedTransaction,
  ) async {
    // Calculate the difference in amount
    final amountDifference =
        updatedTransaction.amount - originalTransaction.amount;

    // Update the transaction first
    final success = await updateTransaction(updatedTransaction);

    if (success && amountDifference != 0) {
      // Adjust wallet balance based on transaction type and amount difference
      final walletRepository = WalletRepository(_database);
      final wallet =
          await (_database.select(_database.wallets)
                ..where((w) => w.id.equals(originalTransaction.walletId)))
              .getSingleOrNull();

      if (wallet != null) {
        double balanceAdjustment = 0.0;

        // For DEBIT transactions: increase in amount = decrease in balance
        // For CREDIT transactions: increase in amount = increase in balance
        // For TRANSFER transactions: no balance change (it's between wallets)
        switch (originalTransaction.type) {
          case 'DEBIT':
            balanceAdjustment = -amountDifference; // Opposite of amount change
            break;
          case 'CREDIT':
            balanceAdjustment = amountDifference; // Same as amount change
            break;
          case 'TRANSFER':
            // For transfers, we might need more complex logic
            // For now, we'll skip balance adjustment for transfers
            balanceAdjustment = 0.0;
            break;
        }

        if (balanceAdjustment != 0) {
          final newBalance = wallet.amount + balanceAdjustment;
          await walletRepository.updateWalletBalance(wallet.id, newBalance);
        }
      }
    }

    return success;
  }

  /// Update transaction cost and adjust wallet balances accordingly
  Future<bool> updateTransactionCost(
    int transactionId,
    double newTransactionCost,
  ) async {
    // Get the current transaction
    final transaction = await getTransactionById(transactionId);
    if (transaction == null) {
      throw Exception('Transaction not found');
    }

    final oldTransactionCost = transaction.transactionCost;
    final costDifference = newTransactionCost - oldTransactionCost;

    // Update the transaction cost
    final success =
        await (_database.update(
          _database.transactions,
        )..where((t) => t.id.equals(transactionId))).write(
          TransactionsCompanion(
            transactionCost: Value(newTransactionCost),
            updatedAt: Value(DateTime.now()),
          ),
        ) >
        0;

    if (success && costDifference != 0) {
      // Adjust wallet balance based on cost difference
      // For DEBIT transactions, increase cost means decrease balance more
      // For CREDIT transactions, transaction costs don't typically apply
      if (transaction.type == 'DEBIT' || transaction.type == 'TRANSFER') {
        final walletRepository = WalletRepository(_database);
        final wallet = await (_database.select(
          _database.wallets,
        )..where((w) => w.id.equals(transaction.walletId))).getSingleOrNull();

        if (wallet != null) {
          final newBalance = wallet.amount - costDifference;
          await walletRepository.updateWalletBalance(wallet.id, newBalance);
        }
      }
    }

    return success;
  }

  /// Categorize transaction
  Future<bool> categorizeTransaction(
    int transactionId,
    int categoryItemId,
  ) async {
    return await (_database.update(
          _database.transactions,
        )..where((transaction) => transaction.id.equals(transactionId))).write(
          TransactionsCompanion(
            categoryItemId: Value(categoryItemId),
            status: const Value('CATEGORIZED'),
            updatedAt: Value(DateTime.now()),
          ),
        ) >
        0;
  }

  /// Categorize transaction with category only (no category item)
  /// For now, we'll store the category name in the description field with a special prefix
  /// This is a temporary solution until we add a categoryId field to the transactions table
  Future<bool> categorizeByCategoryOnly(
    int transactionId,
    int categoryId,
  ) async {
    // Get the category name
    final category = await (_database.select(
      _database.categories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();

    if (category == null) {
      throw Exception('Category not found');
    }

    // Get the current transaction to preserve the original description
    final transaction = await getTransactionById(transactionId);
    if (transaction == null) {
      throw Exception('Transaction not found');
    }

    // Store category info in a special format in the description
    final originalDescription = transaction.description ?? '';
    final categoryOnlyDescription =
        '[CATEGORY_ONLY:${category.name}]$originalDescription';

    return await (_database.update(
          _database.transactions,
        )..where((transaction) => transaction.id.equals(transactionId))).write(
          TransactionsCompanion(
            description: Value(categoryOnlyDescription),
            status: const Value('CATEGORIZED'),
            updatedAt: Value(DateTime.now()),
          ),
        ) >
        0;
  }

  /// Delete transaction
  Future<int> deleteTransaction(int id) async {
    final result = await (_database.delete(
      _database.transactions,
    )..where((transaction) => transaction.id.equals(id))).go();

    // Sync deletion to cloud
    if (result > 0) {
      DataSyncService.syncItemDeletionToCloud(transactionId: id.toString());
    }

    return result;
  }

  /// Delete all transactions
  Future<void> deleteAllTransactions() async {
    await _database.delete(_database.transactions).go();
  }

  /// Get transactions with full details (wallet, category, category item)
  Future<List<TransactionWithDetails>> getTransactionsWithDetails({
    int limit = 50,
    int offset = 0,
  }) async {
    final query =
        _database.select(_database.transactions).join([
            innerJoin(
              _database.wallets,
              _database.wallets.id.equalsExp(_database.transactions.walletId),
            ),
            leftOuterJoin(
              _database.categoryItems,
              _database.categoryItems.id.equalsExp(
                _database.transactions.categoryItemId,
              ),
            ),
            leftOuterJoin(
              _database.categories,
              _database.categories.id.equalsExp(
                _database.categoryItems.categoryId,
              ),
            ),
          ])
          ..orderBy([OrderingTerm.desc(_database.transactions.createdAt)])
          ..limit(limit, offset: offset);

    final results = await query.get();
    return results.map((result) {
      final transaction = result.readTable(_database.transactions);
      final wallet = result.readTable(_database.wallets);
      final categoryItem = result.readTableOrNull(_database.categoryItems);
      final category = result.readTableOrNull(_database.categories);

      return TransactionWithDetails(
        transaction: transaction,
        wallet: wallet,
        categoryItem: categoryItem,
        category: category,
      );
    }).toList();
  }

  /// Get spending summary by category for a date range
  Future<List<CategorySpendingSummary>> getSpendingSummaryByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query =
        _database.selectOnly(_database.transactions).join([
            leftOuterJoin(
              _database.categoryItems,
              _database.categoryItems.id.equalsExp(
                _database.transactions.categoryItemId,
              ),
            ),
            leftOuterJoin(
              _database.categories,
              _database.categories.id.equalsExp(
                _database.categoryItems.categoryId,
              ),
            ),
          ])
          ..addColumns([
            _database.categories.name,
            _database.transactions.amount.sum(),
          ])
          ..where(
            _database.transactions.date.isBiggerOrEqualValue(startDate) &
                _database.transactions.date.isSmallerOrEqualValue(endDate) &
                _database.transactions.type.equals('DEBIT'),
          )
          ..groupBy([_database.categories.name]);

    final results = await query.get();
    return results.map((result) {
      final categoryName =
          result.read(_database.categories.name) ?? 'Uncategorized';
      final totalAmount =
          result.read(_database.transactions.amount.sum()) ?? 0.0;

      return CategorySpendingSummary(
        categoryName: categoryName,
        totalAmount: totalAmount,
      );
    }).toList();
  }

  /// Get monthly spending totals
  Future<List<MonthlySpendingSummary>> getMonthlySpendingSummary({
    required int year,
  }) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year + 1, 1, 1);

    final query = _database.selectOnly(_database.transactions)
      ..addColumns([
        _database.transactions.date.year,
        _database.transactions.date.month,
        _database.transactions.amount.sum(),
      ])
      ..where(
        _database.transactions.date.isBiggerOrEqualValue(startDate) &
            _database.transactions.date.isSmallerOrEqualValue(endDate) &
            _database.transactions.type.equals('DEBIT'),
      )
      ..groupBy([
        _database.transactions.date.year,
        _database.transactions.date.month,
      ])
      ..orderBy([
        OrderingTerm.asc(_database.transactions.date.year),
        OrderingTerm.asc(_database.transactions.date.month),
      ]);

    final results = await query.get();
    return results.map((result) {
      final year = result.read(_database.transactions.date.year)!;
      final month = result.read(_database.transactions.date.month)!;
      final totalAmount =
          result.read(_database.transactions.amount.sum()) ?? 0.0;

      return MonthlySpendingSummary(
        year: year,
        month: month,
        totalAmount: totalAmount,
      );
    }).toList();
  }
}

/// Data class for transaction with full details
class TransactionWithDetails {
  final Transaction transaction;
  final Wallet wallet;
  final CategoryItem? categoryItem;
  final Category? category;

  const TransactionWithDetails({
    required this.transaction,
    required this.wallet,
    this.categoryItem,
    this.category,
  });

  @override
  String toString() {
    return 'TransactionWithDetails(transaction: $transaction, wallet: $wallet, categoryItem: $categoryItem, category: $category)';
  }
}

/// Data class for category spending summary
class CategorySpendingSummary {
  final String categoryName;
  final double totalAmount;

  const CategorySpendingSummary({
    required this.categoryName,
    required this.totalAmount,
  });

  @override
  String toString() {
    return 'CategorySpendingSummary(categoryName: $categoryName, totalAmount: $totalAmount)';
  }
}

/// Data class for monthly spending summary
class MonthlySpendingSummary {
  final int year;
  final int month;
  final double totalAmount;

  const MonthlySpendingSummary({
    required this.year,
    required this.month,
    required this.totalAmount,
  });

  @override
  String toString() {
    return 'MonthlySpendingSummary(year: $year, month: $month, totalAmount: $totalAmount)';
  }
}
