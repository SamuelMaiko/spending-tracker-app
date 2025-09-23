import 'package:drift/drift.dart';
import '../database_helper.dart';

/// Repository for managing transaction data using Drift ORM
class TransactionRepository {
  final AppDatabase _database;

  TransactionRepository(this._database);

  /// Get all transactions
  Future<List<Transaction>> getAllTransactions() async {
    return await (_database.select(
      _database.transactions,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).get();
  }

  /// Get transactions with pagination
  Future<List<Transaction>> getTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    return await (_database.select(_database.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Get transaction by ID
  Future<Transaction?> getTransactionById(int id) async {
    return await (_database.select(
      _database.transactions,
    )..where((transaction) => transaction.id.equals(id))).getSingleOrNull();
  }

  /// Get transactions by wallet ID
  Future<List<Transaction>> getTransactionsByWalletId(int walletId) async {
    return await (_database.select(_database.transactions)
          ..where((transaction) => transaction.walletId.equals(walletId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Get uncategorized transactions
  Future<List<Transaction>> getUncategorizedTransactions() async {
    return await (_database.select(_database.transactions)
          ..where((transaction) => transaction.status.equals('UNCATEGORIZED'))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
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
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
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
  }) async {
    return await _database
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
          ),
        );
  }

  /// Update transaction
  Future<bool> updateTransaction(Transaction transaction) async {
    return await _database.update(_database.transactions).replace(transaction);
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
    return await (_database.delete(
      _database.transactions,
    )..where((transaction) => transaction.id.equals(id))).go();
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
          ..orderBy([OrderingTerm.desc(_database.transactions.date)])
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
