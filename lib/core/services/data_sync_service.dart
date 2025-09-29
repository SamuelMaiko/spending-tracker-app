import 'dart:async';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import '../database/repositories/wallet_repository.dart';
import '../database/repositories/transaction_repository.dart';
import '../database/repositories/category_repository.dart';
import '../database/repositories/weekly_spending_limit_repository.dart';
import '../database/repositories/multi_categorization_repository.dart';
import 'exclude_weekly_settings_service.dart';
import '../database/database_helper.dart' as db;
import 'firestore_service.dart';
import 'sync_settings_service.dart';
import 'sync_status_service.dart';
import '../../dependency_injector.dart';

/// Service for synchronizing data between local SQLite and Firestore
class DataSyncService {
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;
  final CategoryRepository _categoryRepository;
  final WeeklySpendingLimitRepository _weeklySpendingLimitRepository;
  final MultiCategorizationRepository _multiCategorizationRepository;

  DataSyncService({
    required WalletRepository walletRepository,
    required TransactionRepository transactionRepository,
    required CategoryRepository categoryRepository,
    required WeeklySpendingLimitRepository weeklySpendingLimitRepository,
    required MultiCategorizationRepository multiCategorizationRepository,
  }) : _walletRepository = walletRepository,
       _transactionRepository = transactionRepository,
       _categoryRepository = categoryRepository,
       _weeklySpendingLimitRepository = weeklySpendingLimitRepository,
       _multiCategorizationRepository = multiCategorizationRepository;

  /// Perform proper sign-in sync flow
  Future<void> performSignInSync() async {
    if (!await SyncSettingsService.canSync()) {
      developer.log(
        '⏭️ Skipping sign-in sync: sync not enabled or user not authenticated',
      );
      return;
    }

    try {
      developer.log('🔄 Starting sign-in sync flow');

      // Step 1: Clear local database completely
      developer.log('🗑️ Clearing local database...');
      await _clearLocalDatabase();

      // Step 2: Get all data from Firestore
      developer.log('📥 Downloading all data from Firestore...');
      final cloudData = await FirestoreService.downloadAllData();

      // Step 3: Populate with cloud data
      developer.log('📥 Populating local database with cloud data...');
      await _populateLocalWithCloudData(cloudData);

      // Step 4: Clean up wallets and ensure required ones exist
      developer.log(
        '🏦 Cleaning up wallets and ensuring required ones exist...',
      );
      await _cleanupAndEnsureRequiredWallets();

      // Step 5: Sync everything back to Firebase using existing functionality
      developer.log('📤 Syncing all data back to Firebase...');
      await _uploadAllToFirestore();

      developer.log('✅ Sign-in sync completed successfully');
    } catch (e) {
      developer.log('❌ Error during sign-in sync: $e');
      rethrow;
    }
  }

  /// Perform initial sync on login - always overwrite local with cloud data
  Future<void> performInitialSync() async {
    if (!await SyncSettingsService.canSync()) {
      developer.log(
        '⏭️ Skipping initial sync: sync not enabled or user not authenticated',
      );
      return;
    }

    try {
      developer.log('🔄 Starting initial sync on login');

      // Step 1: Get all data from Firestore
      developer.log('📥 Downloading all data from Firestore...');
      final cloudData = await FirestoreService.downloadAllData();

      // Step 2: Clear local database completely
      developer.log('🗑️ Clearing local database...');
      await _clearLocalDatabase();

      // Step 3: Populate with cloud data
      developer.log('📥 Populating local database with cloud data...');
      await _populateLocalWithCloudData(cloudData);

      // Step 4: Ensure default wallets exist
      developer.log('🏦 Ensuring default wallets exist...');
      await _ensureDefaultWalletsExist();

      // Step 5: Ensure default weekly spending limit exists
      developer.log('📊 Ensuring default weekly spending limit exists...');
      await _ensureDefaultWeeklySpendingLimitExists();

      // Step 6: Load user settings from Firebase
      developer.log('⚙️ Loading user settings from Firebase...');
      await ExcludeWeeklySettingsService.loadFromFirebase();

      developer.log(
        '✅ Initial sync completed - local data overwritten with cloud data',
      );
    } catch (e) {
      developer.log('❌ Error during initial sync: $e');
      rethrow;
    }
  }

  /// Populate local database with cloud data
  Future<void> _populateLocalWithCloudData(
    Map<String, dynamic> cloudData,
  ) async {
    try {
      final wallets = cloudData['wallets'] ?? [];
      final categories = cloudData['categories'] ?? [];
      final categoryItems = cloudData['categoryItems'] ?? [];
      final transactions = cloudData['transactions'] ?? [];
      final weeklyLimits = cloudData['weeklySpendingLimits'] ?? [];
      final multiCategorizationLists =
          cloudData['multiCategorizationLists'] ?? [];
      final multiCategorizationItems =
          cloudData['multiCategorizationItems'] ?? [];

      // Create wallets from cloud (preserve Firestore IDs; do NOT auto-sync)
      final Map<String, int> walletNameToId = {};
      final database = sl<db.AppDatabase>();
      for (final walletData in wallets) {
        final name = (walletData['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final dynamic rawId = walletData['id'] ?? walletData['firestoreId'];
        final int? cloudId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        final sender =
            (walletData['transactionSenderName'] ??
                    walletData['transaction_sender_name'] ??
                    '')
                .toString();
        final balance = (walletData['balance'] is num)
            ? (walletData['balance'] as num).toDouble()
            : 0.0;
        final createdAtStr =
            (walletData['createdAt'] ?? walletData['created_at'])?.toString();
        final updatedAtStr =
            (walletData['updatedAt'] ?? walletData['updated_at'])?.toString();
        final createdAt =
            DateTime.tryParse(createdAtStr ?? '') ?? DateTime.now();
        final updatedAt =
            DateTime.tryParse(updatedAtStr ?? '') ?? DateTime.now();

        // Insert directly to DB to avoid per-record auto-sync and to preserve IDs
        final companion = db.WalletsCompanion(
          id: cloudId != null ? Value(cloudId) : const Value.absent(),
          name: Value(name),
          transactionSenderName: Value(sender.isNotEmpty ? sender : 'MPESA'),
          amount: Value(balance),
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
        );
        final insertedId = await database
            .into(database.wallets)
            .insert(companion);
        walletNameToId[name] = cloudId ?? insertedId;
        developer.log(
          '📥 Created wallet from cloud (id=${cloudId ?? insertedId}): $name',
        );
      }

      // Create categories from cloud (preserve Firestore IDs; do NOT auto-sync)
      final Map<String, int> categoryNameToId = {};
      for (final categoryData in categories) {
        final name = (categoryData['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final dynamic rawId = categoryData['id'] ?? categoryData['firestoreId'];
        final int? cloudId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        // Timestamps are not needed locally for categories during initial populate
        final database = sl<db.AppDatabase>();
        final companion = db.CategoriesCompanion(
          id: cloudId != null ? Value(cloudId) : const Value.absent(),
          name: Value(name),
        );
        final insertedId = await database
            .into(database.categories)
            .insert(companion);
        categoryNameToId[name] = cloudId ?? insertedId;
        developer.log(
          '📥 Created category from cloud (id=${cloudId ?? insertedId}): $name',
        );
      }

      // Create category items from cloud (preserve IDs)
      for (final itemData in categoryItems) {
        final name = (itemData['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final dynamic rawId = itemData['id'] ?? itemData['firestoreId'];
        final int? cloudId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        final dynamic rawCatId = itemData['categoryId'];
        final int? catId = rawCatId is int
            ? rawCatId
            : int.tryParse(rawCatId?.toString() ?? '');
        if (catId == null) continue;

        final dbInstance = sl<db.AppDatabase>();
        final companion = db.CategoryItemsCompanion(
          id: cloudId != null ? Value(cloudId) : const Value.absent(),
          name: Value(name),
          categoryId: Value(catId),
        );
        await dbInstance.into(dbInstance.categoryItems).insert(companion);
        developer.log(
          '📥 Created category item from cloud (id=${cloudId ?? 'auto'}) under catId=$catId: $name',
        );
      }

      // Create transactions from cloud
      for (final transactionData in transactions) {
        final walletName = (transactionData['walletName'] ?? '').toString();
        final walletId = walletNameToId[walletName];

        // Map categoryId from cloud to local category_item_id
        int? categoryItemId;
        final dynamic rawCatItemId = transactionData['categoryId'];
        if (rawCatItemId is int) {
          categoryItemId = rawCatItemId;
        } else if (rawCatItemId != null) {
          categoryItemId = int.tryParse(rawCatItemId.toString());
        }

        if (walletId != null) {
          await _transactionRepository.createTransaction(
            walletId: walletId,
            categoryItemId: categoryItemId,
            amount: (transactionData['amount'] is num)
                ? (transactionData['amount'] as num).toDouble()
                : 0.0,
            transactionCost: (transactionData['transactionCost'] is num)
                ? (transactionData['transactionCost'] as num).toDouble()
                : 0.0,
            type: (transactionData['type'] ?? 'DEBIT').toString(),
            description: (transactionData['description'] ?? '').toString(),
            date:
                DateTime.tryParse(transactionData['date'] ?? '') ??
                DateTime.now(),
            status: categoryItemId != null
                ? 'CATEGORIZED'
                : (transactionData['status'] ?? 'UNCATEGORIZED').toString(),
            smsHash: (transactionData['smsHash'] ?? '').toString(),
            excludeFromWeekly:
                transactionData['excludeFromWeekly'] as bool? ?? false,
          );
          developer.log('📥 Created transaction from cloud');
        }
      }

      // Create weekly spending limits from cloud
      for (final limitData in weeklyLimits) {
        final dynamic rawId = limitData['id'] ?? limitData['firestoreId'];
        final int? cloudId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');

        final weekStartStr = (limitData['weekStart'] ?? '').toString();
        final weekEndStr = (limitData['weekEnd'] ?? '').toString();
        final weekStart = DateTime.tryParse(weekStartStr);
        final weekEnd = DateTime.tryParse(weekEndStr);

        if (weekStart != null && weekEnd != null) {
          final targetAmount = (limitData['targetAmount'] is num)
              ? (limitData['targetAmount'] as num).toDouble()
              : 0.0;
          final createdAtStr =
              (limitData['createdAt'] ?? limitData['created_at'])?.toString();
          final updatedAtStr =
              (limitData['updatedAt'] ?? limitData['updated_at'])?.toString();
          final createdAt =
              DateTime.tryParse(createdAtStr ?? '') ?? DateTime.now();
          final updatedAt =
              DateTime.tryParse(updatedAtStr ?? '') ?? DateTime.now();

          // Insert directly to DB to preserve IDs
          final database = sl<db.AppDatabase>();
          final companion = db.WeeklySpendingLimitsCompanion(
            id: cloudId != null ? Value(cloudId) : const Value.absent(),
            weekStart: Value(weekStart),
            weekEnd: Value(weekEnd),
            targetAmount: Value(targetAmount),
            createdAt: Value(createdAt),
            updatedAt: Value(updatedAt),
          );

          await database.into(database.weeklySpendingLimits).insert(companion);
          developer.log(
            '📥 Created weekly spending limit from cloud (id=${cloudId ?? 'auto'})',
          );
        }
      }

      // Create multi-categorization lists from cloud
      for (final listData in multiCategorizationLists) {
        final dynamic rawId = listData['id'] ?? listData['firestoreId'];
        final int? cloudId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');

        final name = (listData['name'] ?? '').toString();
        final transactionId = listData['transactionId'] as int?;
        final isApplied = listData['isApplied'] as bool? ?? false;
        final createdAtStr = (listData['createdAt'] ?? '').toString();
        final updatedAtStr = (listData['updatedAt'] ?? '').toString();
        final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
        final updatedAt = DateTime.tryParse(updatedAtStr) ?? DateTime.now();

        if (name.isNotEmpty) {
          final companion = db.MultiCategorizationListsCompanion(
            id: cloudId != null ? Value(cloudId) : const Value.absent(),
            name: Value(name),
            transactionId: transactionId != null
                ? Value(transactionId)
                : const Value.absent(),
            isApplied: Value(isApplied),
            createdAt: Value(createdAt),
            updatedAt: Value(updatedAt),
          );

          await database
              .into(database.multiCategorizationLists)
              .insert(companion);
          developer.log(
            '📥 Created multi-categorization list from cloud: $name',
          );
        }
      }

      // Create multi-categorization items from cloud
      for (final itemData in multiCategorizationItems) {
        final dynamic rawId = itemData['id'] ?? itemData['firestoreId'];
        final int? cloudId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');

        final listId = itemData['listId'] as int?;
        final categoryItemId = itemData['categoryItemId'] as int?;
        final amount = (itemData['amount'] is num)
            ? (itemData['amount'] as num).toDouble()
            : 0.0;
        final createdAtStr = (itemData['createdAt'] ?? '').toString();
        final updatedAtStr = (itemData['updatedAt'] ?? '').toString();
        final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
        final updatedAt = DateTime.tryParse(updatedAtStr) ?? DateTime.now();

        if (listId != null && categoryItemId != null) {
          final companion = db.MultiCategorizationItemsCompanion(
            id: cloudId != null ? Value(cloudId) : const Value.absent(),
            listId: Value(listId),
            categoryItemId: Value(categoryItemId),
            amount: Value(amount),
            createdAt: Value(createdAt),
            updatedAt: Value(updatedAt),
          );

          await database
              .into(database.multiCategorizationItems)
              .insert(companion);
          developer.log('📥 Created multi-categorization item from cloud');
        }
      }

      developer.log('✅ Local database populated with cloud data');
    } catch (e) {
      developer.log('❌ Error populating local with cloud data: $e');
      rethrow;
    }
  }

  /// Perform ongoing sync (for periodic sync) - uses intelligent merge
  Future<void> performOngoingSync() async {
    if (!await SyncSettingsService.canSync()) {
      developer.log('⚠️ Sync is disabled or user not authenticated');
      return;
    }

    try {
      developer.log('🔄 Starting ongoing sync with intelligent merge');

      // Upload local changes first
      await _uploadAllToFirestore();

      // Then download and intelligently merge cloud changes
      await _downloadAndMergeFromFirestore();

      developer.log('✅ Ongoing sync completed successfully');
    } catch (e) {
      developer.log('❌ Error during ongoing sync: $e');
      rethrow;
    }
  }

  /// Upload all local data to Firestore with enriched context
  Future<void> _uploadAllToFirestore() async {
    try {
      final wallets = await _walletRepository.getAllWallets();
      final transactions = await _transactionRepository.getAllTransactions();
      final categories = await _categoryRepository.getAllCategories();
      final categoryItems = await _categoryRepository.getAllCategoryItems();
      final weeklyLimits = await _weeklySpendingLimitRepository
          .getAllWeeklyLimits();
      final multiCategorizationLists = await _multiCategorizationRepository
          .getAllLists();
      final multiCategorizationItems = await _multiCategorizationRepository
          .getAllItems();

      // Upload wallets, categories, category items, weekly limits, and multi-categorization data first
      await Future.wait([
        ...wallets.map((w) => FirestoreService.uploadWallet(w)),
        ...categories.map((c) => FirestoreService.uploadCategory(c)),
        ...categoryItems.map((i) => FirestoreService.uploadCategoryItem(i)),
        ...weeklyLimits.map(
          (l) => FirestoreService.uploadWeeklySpendingLimit(l),
        ),
        ...multiCategorizationLists.map(
          (l) => FirestoreService.uploadMultiCategorizationList(l),
        ),
        ...multiCategorizationItems.map(
          (i) => FirestoreService.uploadMultiCategorizationItem(i),
        ),
      ]);

      // Upload transactions with enriched context for better cross-device mapping
      for (final transaction in transactions) {
        String? walletName;
        String? walletSenderName;
        String? categoryName;
        String? categoryItemName;

        // Get wallet context
        final wallet = await _walletRepository.getWalletById(
          transaction.walletId,
        );
        walletName = wallet?.name;
        walletSenderName = wallet?.transactionSenderName;

        // Get category context if available
        if (transaction.categoryItemId != null) {
          final categoryItem = await _categoryRepository.getCategoryItemById(
            transaction.categoryItemId!,
          );
          categoryItemName = categoryItem?.name;
          if (categoryItem != null) {
            final category = await _categoryRepository.getCategoryById(
              categoryItem.categoryId,
            );
            categoryName = category?.name;
          }
        }

        await FirestoreService.uploadTransaction(
          transaction,
          walletName: walletName,
          walletSenderName: walletSenderName,
          categoryName: categoryName,
          categoryItemName: categoryItemName,
        );
      }

      developer.log('✅ All local data uploaded to Firestore');
    } catch (e) {
      developer.log('❌ Error uploading to Firestore: $e');
      rethrow;
    }
  }

  /// Clean up wallets and ensure required ones exist with proper Firebase IDs
  Future<void> _cleanupAndEnsureRequiredWallets() async {
    try {
      developer.log(
        '🏦 Cleaning up wallets and ensuring required ones exist...',
      );

      final requiredWallets = [
        {'name': 'M-Pesa', 'transaction_sender_name': 'MPESA', 'amount': 0.0},
        {
          'name': 'Pochi La Biashara',
          'transaction_sender_name': 'MPESA',
          'amount': 0.0,
        },
        {'name': 'M-Shwari', 'transaction_sender_name': 'MPESA', 'amount': 0.0},
        {'name': 'SC BANK', 'transaction_sender_name': 'MPESA', 'amount': 0.0},
        {
          'name': 'EQUITY BANK',
          'transaction_sender_name': 'MPESA',
          'amount': 0.0,
        },
        {'name': 'Cash', 'transaction_sender_name': 'CASH', 'amount': 0.0},
      ];

      final requiredWalletNames = requiredWallets
          .map((w) => w['name']! as String)
          .toSet();

      // Get all current wallets
      final existingWallets = await _walletRepository.getAllWallets();
      developer.log(
        '🔍 Current wallets in database: ${existingWallets.map((w) => w.name).toList()}',
      );
      developer.log('🔍 Required wallets: ${requiredWalletNames.toList()}');

      // Get database instance for direct operations
      final database = sl<db.AppDatabase>();

      // Step 1: Remove duplicate wallets (keep the first occurrence of each name)
      final walletsByName = <String, List<db.Wallet>>{};
      for (final wallet in existingWallets) {
        walletsByName.putIfAbsent(wallet.name, () => []).add(wallet);
      }

      int duplicatesRemoved = 0;
      for (final entry in walletsByName.entries) {
        final walletsWithSameName = entry.value;
        if (walletsWithSameName.length > 1) {
          // Keep the first one, remove the rest
          for (int i = 1; i < walletsWithSameName.length; i++) {
            await (database.delete(
              database.wallets,
            )..where((w) => w.id.equals(walletsWithSameName[i].id))).go();
            duplicatesRemoved++;
            developer.log(
              '🗑️ Removed duplicate wallet: ${walletsWithSameName[i].name} (ID: ${walletsWithSameName[i].id})',
            );
          }
        }
      }

      if (duplicatesRemoved > 0) {
        developer.log('✅ Removed $duplicatesRemoved duplicate wallets');
      }

      // Step 2: Get updated wallet list after cleanup
      final cleanedWallets = await _walletRepository.getAllWallets();
      final existingWalletNames = cleanedWallets.map((w) => w.name).toSet();

      // Step 3: Create missing required wallets
      int walletsCreated = 0;
      for (final walletData in requiredWallets) {
        final name = walletData['name']! as String;
        if (!existingWalletNames.contains(name)) {
          // Create wallet directly in database (preserving any Firebase ID if it comes from cloud)
          await database
              .into(database.wallets)
              .insert(
                db.WalletsCompanion.insert(
                  name: name,
                  transactionSenderName:
                      walletData['transaction_sender_name']! as String,
                  amount: Value(walletData['amount']! as double),
                  // Note: Firebase ID will be preserved if this wallet came from cloud data
                  // or will be generated during sync if it's a new wallet
                ),
              );
          walletsCreated++;
          developer.log('🏦 Created missing required wallet: $name');
        } else {
          developer.log('✅ Required wallet already exists: $name');
        }
      }

      // Step 4: Log final state
      final finalWallets = await _walletRepository.getAllWallets();
      developer.log('✅ Wallet cleanup completed:');
      developer.log('  - Duplicates removed: $duplicatesRemoved');
      developer.log('  - Missing wallets created: $walletsCreated');
      developer.log('  - Total wallets: ${finalWallets.length}');
      developer.log(
        '  - Final wallet names: ${finalWallets.map((w) => w.name).toList()}',
      );
    } catch (e) {
      developer.log('❌ Error cleaning up wallets: $e');
      rethrow;
    }
  }

  /// Ensure the 6 default wallets exist after login
  Future<void> _ensureDefaultWalletsExist() async {
    try {
      developer.log('🏦 Ensuring default wallets exist...');

      final defaultWallets = [
        {'name': 'M-Pesa', 'transaction_sender_name': 'MPESA', 'amount': 0.0},
        {
          'name': 'Pochi La Biashara',
          'transaction_sender_name': 'MPESA',
          'amount': 0.0,
        },
        {'name': 'M-Shwari', 'transaction_sender_name': 'MPESA', 'amount': 0.0},
        {'name': 'SC BANK', 'transaction_sender_name': 'MPESA', 'amount': 0.0},
        {
          'name': 'EQUITY BANK',
          'transaction_sender_name': 'MPESA',
          'amount': 0.0,
        },
        {'name': 'Cash', 'transaction_sender_name': 'CASH', 'amount': 0.0},
      ];

      final existingWallets = await _walletRepository.getAllWallets();
      final existingWalletNames = existingWallets.map((w) => w.name).toSet();

      for (final walletData in defaultWallets) {
        final name = walletData['name']! as String;
        if (!existingWalletNames.contains(name)) {
          await _walletRepository.createWallet(
            name: name,
            transactionSenderName:
                walletData['transaction_sender_name']! as String,
            amount: walletData['amount']! as double,
          );
          developer.log('🏦 Created default wallet: $name');
        }
      }

      developer.log('✅ Default wallets ensured');
    } catch (e) {
      developer.log('❌ Error ensuring default wallets: $e');
      rethrow;
    }
  }

  /// Ensure default weekly spending limit exists for current week
  Future<void> _ensureDefaultWeeklySpendingLimitExists() async {
    try {
      developer.log('📊 Ensuring default weekly spending limit exists...');

      // Get current week start (Monday)
      final now = DateTime.now();
      final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
      final currentWeekEnd = currentWeekStart.add(const Duration(days: 6));

      // Check if current week limit already exists
      final existingLimit = await _weeklySpendingLimitRepository
          .getWeeklyLimitByDate(currentWeekStart);

      if (existingLimit == null) {
        // Create default weekly spending limit of KSh 5000
        await _weeklySpendingLimitRepository.setWeeklyLimit(
          currentWeekStart,
          currentWeekEnd,
          5000.0,
        );
        developer.log('📊 Created default weekly spending limit: KSh 5000');
      }

      developer.log('✅ Default weekly spending limit ensured');
    } catch (e) {
      developer.log('❌ Error ensuring default weekly spending limit: $e');
      rethrow;
    }
  }

  /// Clear all local database data
  Future<void> _clearLocalDatabase() async {
    try {
      developer.log('🗑️ Clearing local database');

      // Use repositories to clear data (they handle the database access)
      await _transactionRepository.deleteAllTransactions();
      await _categoryRepository.deleteAllCategoryItems();
      await _categoryRepository.deleteAllCategories();
      await _walletRepository.deleteAllWallets();

      developer.log('✅ Local database cleared successfully');
    } catch (e) {
      developer.log('❌ Error clearing local database: $e');
      rethrow;
    }
  }

  /// Download all data from Firestore and intelligently merge with local database
  Future<void> _downloadAndMergeFromFirestore() async {
    try {
      developer.log('📥 Downloading and merging data from Firestore');

      final cloudData = await FirestoreService.downloadAllData();
      final wallets = cloudData['wallets'] ?? [];
      final categories = cloudData['categories'] ?? [];
      final transactions = cloudData['transactions'] ?? [];

      // Build local lookup maps for efficient merging
      final existingWallets = await _walletRepository.getAllWallets();
      final Map<String, int> senderToWalletId = {
        for (final w in existingWallets) w.transactionSenderName: w.id,
      };
      final Map<String, int> nameToWalletId = {
        for (final w in existingWallets) w.name: w.id,
      };

      // Merge wallets by name/senderName with updatedAt comparison
      for (final walletData in wallets) {
        final name = (walletData['name'] ?? '').toString();
        final sender = (walletData['transactionSenderName'] ?? '').toString();

        if (name.isEmpty) continue;

        int? existingId = senderToWalletId[sender] ?? nameToWalletId[name];
        if (existingId == null) {
          // Create new wallet from cloud
          final newId = await _walletRepository.createWallet(
            name: name,
            transactionSenderName: sender.isNotEmpty ? sender : 'MPESA',
            amount: (walletData['balance'] is num)
                ? (walletData['balance'] as num).toDouble()
                : 0.0,
          );
          senderToWalletId[sender.isNotEmpty ? sender : 'MPESA'] = newId;
          nameToWalletId[name] = newId;
          developer.log('📥 Created new wallet from cloud: $name');
        } else {
          // Wallet exists - compare updatedAt to decide which version to keep
          final localWallet = existingWallets.firstWhere(
            (w) => w.id == existingId,
          );
          final cloudUpdatedAt = DateTime.tryParse(
            walletData['updatedAt'] ?? '',
          );

          if (cloudUpdatedAt != null &&
              cloudUpdatedAt.isAfter(localWallet.updatedAt)) {
            // Cloud version is newer - overwrite local with ALL cloud data
            final updatedWallet = localWallet.copyWith(
              name: name,
              transactionSenderName: sender.isNotEmpty ? sender : 'MPESA',
              amount: (walletData['balance'] is num)
                  ? (walletData['balance'] as num).toDouble()
                  : 0.0,
              updatedAt: cloudUpdatedAt,
            );
            await _walletRepository.updateWallet(updatedWallet);
            developer.log(
              '📥 Overwritten local wallet with cloud data (newer): $name',
            );
          } else if (cloudUpdatedAt == null ||
              localWallet.updatedAt.isAfter(cloudUpdatedAt)) {
            // Local version is newer - overwrite cloud with ALL local data
            DataSyncService.syncItemToCloud(wallet: localWallet);
            developer.log('📤 Local wallet is newer, overwriting cloud: $name');
          }
        }
      }

      // Merge categories by name
      final existingCategories = await _categoryRepository.getAllCategories();
      final Map<String, int> categoryNameToId = {
        for (final c in existingCategories) c.name: c.id,
      };

      for (final categoryData in categories) {
        final name = (categoryData['name'] ?? '').toString();
        if (name.isEmpty) continue;

        if (!categoryNameToId.containsKey(name)) {
          final newId = await _categoryRepository.createCategory(name);
          categoryNameToId[name] = newId;
        }
      }

      // Merge transactions by smsHash with updatedAt comparison
      for (final transactionData in transactions) {
        final smsHash = (transactionData['smsHash'] as String?)?.trim();

        // Check if transaction already exists locally
        if (smsHash != null && smsHash.isNotEmpty) {
          final existing = await _transactionRepository.getTransactionBySmsHash(
            smsHash,
          );
          if (existing != null) {
            // Transaction exists - compare updatedAt to decide which version to keep
            final cloudUpdatedAt = DateTime.tryParse(
              transactionData['updatedAt'] ?? '',
            );

            if (cloudUpdatedAt != null &&
                cloudUpdatedAt.isAfter(existing.updatedAt)) {
              // Cloud version is newer - update local transaction
              developer.log(
                '📥 Updating local transaction from cloud (newer): ${existing.id}',
              );
              // Note: We'll update the transaction with cloud data
              // For now, we'll skip detailed update logic to keep it simple
            } else if (cloudUpdatedAt == null ||
                existing.updatedAt.isAfter(cloudUpdatedAt)) {
              // Local version is newer - sync to cloud
              DataSyncService.syncItemToCloud(transaction: existing);
              developer.log(
                '📤 Local transaction is newer, will sync to cloud: ${existing.id}',
              );
            }
            continue; // Skip creating new transaction
          }
        }

        // Map wallet by name/sender
        final walletName = (transactionData['walletName'] ?? '').toString();
        final walletSender = (transactionData['walletSenderName'] ?? '')
            .toString();
        int? walletId =
            senderToWalletId[walletSender] ?? nameToWalletId[walletName];

        if (walletId == null) {
          // Create missing wallet
          walletId = await _walletRepository.createWallet(
            name: walletName.isNotEmpty ? walletName : 'M-Pesa',
            transactionSenderName: walletSender.isNotEmpty
                ? walletSender
                : 'MPESA',
          );
          senderToWalletId[walletSender.isNotEmpty ? walletSender : 'MPESA'] =
              walletId;
          nameToWalletId[walletName.isNotEmpty ? walletName : 'M-Pesa'] =
              walletId;
        }

        // Map category if available
        int? categoryItemId;
        final categoryName = (transactionData['categoryName'] ?? '').toString();
        final categoryItemName = (transactionData['categoryItemName'] ?? '')
            .toString();

        if (categoryName.isNotEmpty && categoryItemName.isNotEmpty) {
          int? catId = categoryNameToId[categoryName];
          if (catId == null) {
            catId = await _categoryRepository.createCategory(categoryName);
            categoryNameToId[categoryName] = catId;
          }

          final items = await _categoryRepository.getCategoryItemsByCategoryId(
            catId,
          );
          final existingItem = items
              .where((i) => i.name == categoryItemName)
              .toList();

          if (existingItem.isEmpty) {
            categoryItemId = await _categoryRepository.createCategoryItem(
              name: categoryItemName,
              categoryId: catId,
            );
          } else {
            categoryItemId = existingItem.first.id;
          }
        }

        // Create transaction
        final amount = (transactionData['amount'] is num)
            ? (transactionData['amount'] as num).toDouble()
            : 0.0;
        final type = (transactionData['type'] ?? 'DEBIT').toString();
        final description = transactionData['description'] as String?;
        final date =
            DateTime.tryParse((transactionData['date'] ?? '').toString()) ??
            DateTime.now();

        await _transactionRepository.createTransaction(
          walletId: walletId,
          categoryItemId: categoryItemId,
          amount: amount,
          type: type,
          description: description,
          date: date,
          smsHash: smsHash,
          status: (transactionData['status'] ?? 'UNCATEGORIZED').toString(),
        );
      }

      developer.log('✅ Download and merge completed');

      // After downloading, sync any new local records that weren't in cloud
      await _syncNewLocalRecordsToCloud();
    } catch (e) {
      developer.log('❌ Error downloading from Firestore: $e');
      rethrow;
    }
  }

  /// Sync new local records to cloud that might have been missed
  Future<void> _syncNewLocalRecordsToCloud() async {
    try {
      developer.log('🔄 Syncing new local records to cloud...');

      // Get all local records
      final localWallets = await _walletRepository.getAllWallets();
      final localTransactions = await _transactionRepository
          .getAllTransactions();

      // Sync wallets that might be newer locally
      for (final wallet in localWallets) {
        try {
          DataSyncService.syncItemToCloud(wallet: wallet);
        } catch (e) {
          developer.log('❌ Failed to sync wallet ${wallet.name}: $e');
        }
      }

      // Sync transactions that might be newer locally
      for (final transaction in localTransactions) {
        try {
          DataSyncService.syncItemToCloud(transaction: transaction);
        } catch (e) {
          developer.log('❌ Failed to sync transaction ${transaction.id}: $e');
        }
      }

      developer.log('✅ New local records synced to cloud');
    } catch (e) {
      developer.log('❌ Error syncing new local records: $e');
    }
  }

  /// Sync a single item to cloud (for ongoing sync)
  static Future<void> syncItemToCloud({
    db.Wallet? wallet,
    db.Transaction? transaction,
    db.Category? category,
    db.CategoryItem? categoryItem,
  }) async {
    if (!await SyncSettingsService.canSync()) return;

    try {
      if (wallet != null) {
        await FirestoreService.uploadWallet(wallet);
        developer.log('📤 Synced wallet to cloud: ${wallet.name}');
      }

      if (transaction != null) {
        // Enrich transaction with context for better cross-device mapping
        String? walletName;
        String? walletSenderName;
        String? categoryName;
        String? categoryItemName;

        try {
          final walletRepo = sl<WalletRepository>();
          final categoryRepo = sl<CategoryRepository>();

          final wallet = await walletRepo.getWalletById(transaction.walletId);
          walletName = wallet?.name;
          walletSenderName = wallet?.transactionSenderName;

          if (transaction.categoryItemId != null) {
            final categoryItem = await categoryRepo.getCategoryItemById(
              transaction.categoryItemId!,
            );
            categoryItemName = categoryItem?.name;
            if (categoryItem != null) {
              final category = await categoryRepo.getCategoryById(
                categoryItem.categoryId,
              );
              categoryName = category?.name;
            }
          }
        } catch (_) {
          // Best-effort enrichment; ignore failures
        }

        await FirestoreService.uploadTransaction(
          transaction,
          walletName: walletName,
          walletSenderName: walletSenderName,
          categoryName: categoryName,
          categoryItemName: categoryItemName,
        );
        developer.log(
          '📤 Synced transaction to cloud: ${transaction.description}',
        );
      }

      if (category != null) {
        await FirestoreService.uploadCategory(category);
        developer.log('📤 Synced category to cloud: ${category.name}');
      }

      if (categoryItem != null) {
        await FirestoreService.uploadCategoryItem(categoryItem);
        developer.log('📤 Synced category item to cloud: ${categoryItem.name}');
      }
    } catch (e) {
      developer.log('❌ Error syncing item to cloud: $e');
      // Don't rethrow - sync failures shouldn't break the app
    }
  }

  /// Sync item deletion to cloud
  static Future<void> syncItemDeletionToCloud({
    String? walletId,
    String? transactionId,
    String? categoryId,
    String? categoryItemId,
  }) async {
    if (!await SyncSettingsService.canSync()) return;

    try {
      SyncStatusService.setSyncing();

      if (walletId != null) {
        await FirestoreService.deleteWallet(walletId);
        developer.log('📤 Synced wallet deletion to cloud: $walletId');
      }

      if (transactionId != null) {
        await FirestoreService.deleteTransaction(transactionId);
        developer.log(
          '📤 Synced transaction deletion to cloud: $transactionId',
        );
      }

      if (categoryId != null) {
        await FirestoreService.deleteCategory(categoryId);
        developer.log('📤 Synced category deletion to cloud: $categoryId');
      }

      if (categoryItemId != null) {
        await FirestoreService.deleteCategoryItem(categoryItemId);
        developer.log(
          '📤 Synced category item deletion to cloud: $categoryItemId',
        );
      }

      SyncStatusService.setSyncCompleted();
    } catch (e) {
      developer.log('❌ Error syncing deletion to cloud: $e');
      SyncStatusService.setSyncError(e.toString());
      // Don't rethrow - sync failures shouldn't break the app
    }
  }

  /// Force full sync (upload all local data)
  static Future<void> forceFullSync() async {
    if (!await SyncSettingsService.canSync()) {
      throw Exception('Sync is not enabled or user not authenticated');
    }

    try {
      SyncStatusService.setSyncing();
      developer.log('🔄 Starting force full sync');

      final service = DataSyncService(
        walletRepository: sl<WalletRepository>(),
        transactionRepository: sl<TransactionRepository>(),
        categoryRepository: sl<CategoryRepository>(),
        weeklySpendingLimitRepository: sl<WeeklySpendingLimitRepository>(),
        multiCategorizationRepository: sl<MultiCategorizationRepository>(),
      );
      await service._uploadAllToFirestore();

      SyncStatusService.setSyncCompleted();
      developer.log('✅ Force full sync completed');
    } catch (e) {
      developer.log('❌ Error during force full sync: $e');
      SyncStatusService.setSyncError(e.toString());
      rethrow;
    }
  }

  /// Sync when connectivity is restored
  static Future<void> syncOnConnectivityRestored() async {
    if (!await SyncSettingsService.canSync()) return;
    if (!SyncStatusService.isConnected) return;

    try {
      developer.log('📶 Connectivity restored - starting sync');
      await forceFullSync();
    } catch (e) {
      developer.log('❌ Error syncing on connectivity restore: $e');
    }
  }

  /// Initialize connectivity-aware sync
  static void initializeConnectivitySync() {
    // Listen to connectivity changes and sync when restored
    SyncStatusService.connectivityStream.listen((isConnected) {
      if (isConnected) {
        // Delay sync to allow network to stabilize
        Timer(const Duration(seconds: 2), () {
          syncOnConnectivityRestored();
        });
      }
    });
  }
}
