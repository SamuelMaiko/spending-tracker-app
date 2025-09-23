import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database_helper.g.dart';

/// Wallets table - represents each money source (e.g., M-Pesa, Bank, Airtel)
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get transactionSenderName =>
      text().named('transaction_sender_name')();
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
}

/// Categories table - represents broad spending groups
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

/// Category Items table - represents finer classification within a category
class CategoryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get categoryId => integer()
      .named('category_id')
      .references(Categories, #id, onDelete: KeyAction.cascade)();
}

/// Transactions table - stores individual transactions parsed from SMS
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get walletId => integer()
      .named('wallet_id')
      .references(Wallets, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryItemId => integer()
      .named('category_item_id')
      .nullable()
      .references(CategoryItems, #id, onDelete: KeyAction.setNull)();
  RealColumn get amount => real()();
  RealColumn get transactionCost =>
      real().named('transaction_cost').withDefault(const Constant(0.0))();
  TextColumn get type => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('UNCATEGORIZED'))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
}

/// Main database class using Drift ORM
@DriftDatabase(tables: [Wallets, Categories, CategoryItems, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaultData();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Handle future migrations here
    },
  );

  /// Insert default categories, category items, and wallets
  Future<void> _insertDefaultData() async {
    // Insert default categories
    final categoryNames = [
      'Transport',
      'Food',
      'Bills',
      'Fees',
      'Savings',
      'Income',
      'Shopping',
      'Entertainment',
    ];

    final categoryIds = <String, int>{};
    for (final categoryName in categoryNames) {
      final categoryId = await into(
        categories,
      ).insert(CategoriesCompanion.insert(name: categoryName));
      categoryIds[categoryName] = categoryId;
    }

    // Insert default category items
    final categoryItemsData = {
      'Transport': ['Uber', 'Matatu', 'Boda Boda', 'Fuel', 'Parking'],
      'Food': ['Restaurant', 'Groceries', 'Fast Food', 'Coffee', 'Delivery'],
      'Bills': ['Electricity', 'Water', 'Internet', 'Phone', 'Rent'],
      'Fees': ['M-Pesa Charges', 'Bank Charges', 'ATM Fees', 'Transfer Fees'],
      'Savings': ['Emergency Fund', 'Investment', 'Fixed Deposit'],
      'Income': ['Salary', 'Freelance', 'Business', 'Investment Returns'],
      'Shopping': ['Clothes', 'Electronics', 'Home Items', 'Personal Care'],
      'Entertainment': ['Movies', 'Games', 'Sports', 'Music', 'Events'],
    };

    for (final entry in categoryItemsData.entries) {
      final categoryName = entry.key;
      final items = entry.value;
      final categoryId = categoryIds[categoryName];

      if (categoryId != null) {
        for (final item in items) {
          await into(categoryItems).insert(
            CategoryItemsCompanion.insert(name: item, categoryId: categoryId),
          );
        }
      }
    }

    // Insert default wallets
    final defaultWallets = [
      {'name': 'M-PESA', 'transaction_sender_name': 'MPESA'},
      {'name': 'Equity Bank', 'transaction_sender_name': 'EQUITYBANK'},
      {'name': 'KCB Bank', 'transaction_sender_name': 'KCB'},
      {'name': 'Co-op Bank', 'transaction_sender_name': 'COOPBANK'},
    ];

    for (final wallet in defaultWallets) {
      await into(wallets).insert(
        WalletsCompanion.insert(
          name: wallet['name']!,
          transactionSenderName: wallet['transaction_sender_name']!,
        ),
      );
    }
  }

  /// Clear all data (for testing purposes)
  Future<void> clearAllData() async {
    await delete(transactions).go();
    await delete(categoryItems).go();
    await delete(categories).go();
    await delete(wallets).go();

    // Re-insert default data
    await _insertDefaultData();
  }
}

/// Create database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'spending_tracker.db'));
    return NativeDatabase.createInBackground(file);
  });
}
