import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

import '../database/database_helper.dart' as db;
import 'firebase_auth_service.dart';

/// Service for handling Firestore operations
class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user's UID
  static String? get _currentUserUid => FirebaseAuthService.currentUserUid;

  /// Check if user is authenticated
  static bool get _isAuthenticated => _currentUserUid != null;

  // Collection references
  static CollectionReference? get _walletsCollection => _isAuthenticated
      ? _firestore
            .collection('users')
            .doc(_currentUserUid)
            .collection('wallets')
      : null;

  static CollectionReference? get _transactionsCollection => _isAuthenticated
      ? _firestore
            .collection('users')
            .doc(_currentUserUid)
            .collection('transactions')
      : null;

  static CollectionReference? get _categoriesCollection => _isAuthenticated
      ? _firestore
            .collection('users')
            .doc(_currentUserUid)
            .collection('categories')
      : null;

  // New: Category Items collection (flat under user for easy lookup)
  static CollectionReference? get _categoryItemsCollection => _isAuthenticated
      ? _firestore
            .collection('users')
            .doc(_currentUserUid)
            .collection('categoryItems')
      : null;

  // Weekly Spending Limits collection
  static CollectionReference? get _weeklySpendingLimitsCollection =>
      _isAuthenticated
      ? _firestore
            .collection('users')
            .doc(_currentUserUid)
            .collection('weeklySpendingLimits')
      : null;

  static DocumentReference? get _settingsDocument => _isAuthenticated
      ? _firestore.collection('users').doc(_currentUserUid)
      : null;

  // WALLET OPERATIONS

  /// Upload wallet to Firestore with name-based upsert to prevent duplicates
  static Future<void> uploadWallet(db.Wallet wallet) async {
    if (!_isAuthenticated || _walletsCollection == null) {
      developer.log('❌ Cannot upload wallet: User not authenticated');
      return;
    }

    try {
      developer.log('📤 Uploading wallet (name-based upsert): ${wallet.name}');

      // Find existing wallet doc by name to avoid creating duplicates
      String targetDocId = wallet.id.toString();
      final existing = await _walletsCollection!
          .where('name', isEqualTo: wallet.name)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        targetDocId = existing.docs.first.id;
        developer.log(
          '🔄 Found existing wallet doc by name. Using docId=$targetDocId',
        );
      }

      await _walletsCollection!.doc(targetDocId).set({
        'id': wallet.id,
        'name': wallet.name,
        'transactionSenderName': wallet.transactionSenderName,
        'balance': wallet.amount,
        'createdAt': wallet.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      developer.log('✅ Wallet uploaded successfully');
    } catch (e) {
      developer.log('❌ Error uploading wallet: $e');
      rethrow;
    }
  }

  /// Download wallets from Firestore
  static Future<List<Map<String, dynamic>>> downloadWallets() async {
    if (!_isAuthenticated || _walletsCollection == null) {
      developer.log('❌ Cannot download wallets: User not authenticated');
      return [];
    }

    try {
      developer.log('📥 Downloading wallets from Firestore');
      final snapshot = await _walletsCollection!.get();
      final wallets = snapshot.docs
          .map(
            (doc) => {
              ...doc.data() as Map<String, dynamic>,
              'firestoreId': doc.id,
            },
          )
          .toList();
      developer.log('✅ Downloaded ${wallets.length} wallets');
      return wallets;
    } catch (e) {
      developer.log('❌ Error downloading wallets: $e');
      return [];
    }
  }

  /// Delete wallet from Firestore
  static Future<void> deleteWallet(String walletId) async {
    if (!_isAuthenticated || _walletsCollection == null) return;

    try {
      await _walletsCollection!.doc(walletId).delete();
      developer.log('✅ Wallet deleted from Firestore: $walletId');
    } catch (e) {
      developer.log('❌ Error deleting wallet: $e');
      rethrow;
    }
  }

  // TRANSACTION OPERATIONS

  /// Upload transaction to Firestore with deduplication by smsHash
  static Future<void> uploadTransaction(
    db.Transaction transaction, {
    String? walletName,
    String? walletSenderName,
    String? categoryName,
    String? categoryItemName,
  }) async {
    if (!_isAuthenticated || _transactionsCollection == null) {
      developer.log('❌ Cannot upload transaction: User not authenticated');
      return;
    }

    try {
      developer.log('📤 Uploading transaction: ${transaction.description}');

      // Use smsHash as document ID for deduplication if available
      String docId;
      if (transaction.smsHash != null && transaction.smsHash!.isNotEmpty) {
        // Check if document with this smsHash already exists
        final existing = await _transactionsCollection!
            .where('smsHash', isEqualTo: transaction.smsHash)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          docId = existing.docs.first.id;
          developer.log(
            '🔄 Updating existing transaction with smsHash: ${transaction.smsHash}',
          );
        } else {
          // Use smsHash as stable document ID
          docId = transaction.smsHash!;
        }
      } else {
        // Fallback to local ID
        docId = transaction.id.toString();
      }

      final data = {
        'id': transaction.id,
        'walletId': transaction.walletId,
        'categoryId': transaction.categoryItemId,
        'amount': transaction.amount,
        'transactionCost': transaction.transactionCost,
        'description': transaction.description,
        'type': transaction.type,
        'date': transaction.date.toIso8601String(),
        'createdAt': transaction.createdAt.toIso8601String(),
        'smsHash': transaction.smsHash,
        'updatedAt': DateTime.now().toIso8601String(),
        if (walletName != null) 'walletName': walletName,
        if (walletSenderName != null) 'walletSenderName': walletSenderName,
        if (categoryName != null) 'categoryName': categoryName,
        if (categoryItemName != null) 'categoryItemName': categoryItemName,
      };

      await _transactionsCollection!
          .doc(docId)
          .set(data, SetOptions(merge: true));
      developer.log('✅ Transaction uploaded successfully (doc: $docId)');
    } catch (e) {
      developer.log('❌ Error uploading transaction: $e');
      rethrow;
    }
  }

  /// Download transactions from Firestore
  static Future<List<Map<String, dynamic>>> downloadTransactions() async {
    if (!_isAuthenticated || _transactionsCollection == null) {
      developer.log('❌ Cannot download transactions: User not authenticated');
      return [];
    }

    try {
      developer.log('📥 Downloading transactions from Firestore');
      final snapshot = await _transactionsCollection!.get();
      final transactions = snapshot.docs
          .map(
            (doc) => {
              ...doc.data() as Map<String, dynamic>,
              'firestoreId': doc.id,
            },
          )
          .toList();
      developer.log('✅ Downloaded ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      developer.log('❌ Error downloading transactions: $e');
      return [];
    }
  }

  /// Delete transaction from Firestore
  static Future<void> deleteTransaction(String transactionId) async {
    if (!_isAuthenticated || _transactionsCollection == null) return;

    try {
      await _transactionsCollection!.doc(transactionId).delete();
      developer.log('✅ Transaction deleted from Firestore: $transactionId');
    } catch (e) {
      developer.log('❌ Error deleting transaction: $e');
      rethrow;
    }
  }

  // CATEGORY OPERATIONS

  /// Upload category to Firestore
  static Future<void> uploadCategory(db.Category category) async {
    if (!_isAuthenticated || _categoriesCollection == null) {
      developer.log('❌ Cannot upload category: User not authenticated');
      return;
    }

    try {
      developer.log('📤 Uploading category: ${category.name}');
      await _categoriesCollection!.doc(category.id.toString()).set({
        'id': category.id,
        'name': category.name,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      developer.log('✅ Category uploaded successfully');
    } catch (e) {
      developer.log('❌ Error uploading category: $e');
      rethrow;
    }
  }

  /// Download categories from Firestore
  static Future<List<Map<String, dynamic>>> downloadCategories() async {
    if (!_isAuthenticated || _categoriesCollection == null) {
      developer.log('❌ Cannot download categories: User not authenticated');
      return [];
    }

    try {
      developer.log('📥 Downloading categories from Firestore');
      final snapshot = await _categoriesCollection!.get();
      final categories = snapshot.docs
          .map(
            (doc) => {
              ...doc.data() as Map<String, dynamic>,
              'firestoreId': doc.id,
            },
          )
          .toList();
      developer.log('✅ Downloaded ${categories.length} categories');
      return categories;
    } catch (e) {
      developer.log('❌ Error downloading categories: $e');
      return [];
    }
  }

  /// Delete category from Firestore
  static Future<void> deleteCategory(String categoryId) async {
    if (!_isAuthenticated || _categoriesCollection == null) return;

    try {
      await _categoriesCollection!.doc(categoryId).delete();
      developer.log('✅ Category deleted from Firestore: $categoryId');
    } catch (e) {
      developer.log('❌ Error deleting category: $e');
      rethrow;
    }
  }

  // CATEGORY ITEM OPERATIONS

  /// Upload category item with name+categoryId upsert to avoid duplicates
  static Future<void> uploadCategoryItem(db.CategoryItem item) async {
    if (!_isAuthenticated || _categoryItemsCollection == null) {
      developer.log('❌ Cannot upload category item: User not authenticated');
      return;
    }
    try {
      developer.log(
        '📤 Uploading category item: ${item.name} (catId=${item.categoryId})',
      );

      // Find existing by name+categoryId to avoid duplicates
      String targetDocId = item.id.toString();
      final existing = await _categoryItemsCollection!
          .where('name', isEqualTo: item.name)
          .where('categoryId', isEqualTo: item.categoryId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        targetDocId = existing.docs.first.id;
        developer.log(
          '🔄 Found existing category item doc. Using docId=$targetDocId',
        );
      }

      await _categoryItemsCollection!.doc(targetDocId).set({
        'id': item.id,
        'name': item.name,
        'categoryId': item.categoryId,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      developer.log('✅ Category item uploaded successfully');
    } catch (e) {
      developer.log('❌ Error uploading category item: $e');
      rethrow;
    }
  }

  /// Download category items from Firestore
  static Future<List<Map<String, dynamic>>> downloadCategoryItems() async {
    if (!_isAuthenticated || _categoryItemsCollection == null) {
      developer.log('❌ Cannot download category items: User not authenticated');
      return [];
    }
    try {
      developer.log('📥 Downloading category items from Firestore');
      final snapshot = await _categoryItemsCollection!.get();
      final items = snapshot.docs
          .map(
            (doc) => {
              ...doc.data() as Map<String, dynamic>,
              'firestoreId': doc.id,
            },
          )
          .toList();
      developer.log('✅ Downloaded ${items.length} category items');
      return items;
    } catch (e) {
      developer.log('❌ Error downloading category items: $e');
      return [];
    }
  }

  /// Delete category item from Firestore
  static Future<void> deleteCategoryItem(String categoryItemId) async {
    if (!_isAuthenticated || _categoryItemsCollection == null) return;
    try {
      await _categoryItemsCollection!.doc(categoryItemId).delete();
      developer.log('✅ Category item deleted from Firestore: $categoryItemId');
    } catch (e) {
      developer.log('❌ Error deleting category item: $e');
      rethrow;
    }
  }

  // SETTINGS OPERATIONS

  /// Upload sync settings to Firestore
  static Future<void> uploadSyncSettings({required bool syncEnabled}) async {
    if (!_isAuthenticated || _settingsDocument == null) return;

    try {
      await _settingsDocument!.set({
        'syncEnabled': syncEnabled,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      developer.log('✅ Sync settings uploaded: $syncEnabled');
    } catch (e) {
      developer.log('❌ Error uploading sync settings: $e');
      rethrow;
    }
  }

  /// Download sync settings from Firestore
  static Future<bool> downloadSyncSettings() async {
    if (!_isAuthenticated || _settingsDocument == null) return false;

    try {
      final doc = await _settingsDocument!.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['syncEnabled'] ?? false;
      }
      return false;
    } catch (e) {
      developer.log('❌ Error downloading sync settings: $e');
      return false;
    }
  }

  // AUTO-CATEGORIZE SETTINGS OPERATIONS
  static Future<void> uploadAutoCategorizeSetting({
    required bool enabled,
  }) async {
    if (!_isAuthenticated || _settingsDocument == null) return;
    try {
      await _settingsDocument!.set({
        'autoCategorizeEnabled': enabled,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      developer.log('✅ Auto-categorize setting uploaded: $enabled');
    } catch (e) {
      developer.log('❌ Error uploading auto-categorize setting: $e');
      rethrow;
    }
  }

  static Future<bool> downloadAutoCategorizeSetting() async {
    if (!_isAuthenticated || _settingsDocument == null) return false;
    try {
      final doc = await _settingsDocument!.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['autoCategorizeEnabled'] ?? false;
      }
      return false;
    } catch (e) {
      developer.log('❌ Error downloading auto-categorize setting: $e');
      return false;
    }
  }

  // BATCH OPERATIONS

  /// Upload all local data to Firestore
  static Future<void> uploadAllData({
    required List<db.Wallet> wallets,
    required List<db.Transaction> transactions,
    required List<db.Category> categories,
    required List<db.CategoryItem> categoryItems,
  }) async {
    if (!_isAuthenticated) {
      developer.log('❌ Cannot upload data: User not authenticated');
      return;
    }

    try {
      developer.log('📤 Starting bulk upload to Firestore');

      // Upload in parallel for better performance
      await Future.wait([
        ...wallets.map((wallet) => uploadWallet(wallet)),
        ...categories.map((category) => uploadCategory(category)),
        ...categoryItems.map((item) => uploadCategoryItem(item)),
        ...transactions.map((transaction) => uploadTransaction(transaction)),
      ]);

      developer.log('✅ Bulk upload completed successfully');
    } catch (e) {
      developer.log('❌ Error during bulk upload: $e');
      rethrow;
    }
  }

  /// Download all data from Firestore
  static Future<Map<String, List<Map<String, dynamic>>>>
  downloadAllData() async {
    if (!_isAuthenticated) {
      developer.log('❌ Cannot download data: User not authenticated');
      return {
        'wallets': [],
        'transactions': [],
        'categories': [],
        'categoryItems': [],
        'weeklySpendingLimits': [],
      };
    }

    try {
      developer.log('📥 Starting bulk download from Firestore');

      // Download in parallel for better performance
      final results = await Future.wait([
        downloadWallets(),
        downloadTransactions(),
        downloadCategories(),
        downloadCategoryItems(),
        downloadWeeklySpendingLimits(),
      ]);

      final data = {
        'wallets': results[0],
        'transactions': results[1],
        'categories': results[2],
        'categoryItems': results[3],
        'weeklySpendingLimits': results[4],
      };

      developer.log('✅ Bulk download completed successfully');
      return data;
    } catch (e) {
      developer.log('❌ Error during bulk download: $e');
      return {
        'wallets': [],
        'transactions': [],
        'categories': [],
        'categoryItems': [],
        'weeklySpendingLimits': [],
      };
    }
  }

  // WEEKLY SPENDING LIMITS OPERATIONS

  /// Upload weekly spending limit to Firestore
  static Future<void> uploadWeeklySpendingLimit(
    db.WeeklySpendingLimit limit,
  ) async {
    if (!_isAuthenticated || _weeklySpendingLimitsCollection == null) {
      developer.log(
        '❌ Cannot upload weekly spending limit: User not authenticated',
      );
      return;
    }

    try {
      developer.log('📤 Uploading weekly spending limit: ${limit.id}');

      await _weeklySpendingLimitsCollection!.doc(limit.id.toString()).set({
        'id': limit.id,
        'weekStart': limit.weekStart.toIso8601String(),
        'weekEnd': limit.weekEnd.toIso8601String(),
        'targetAmount': limit.targetAmount,
        'createdAt': limit.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      developer.log('✅ Weekly spending limit uploaded successfully');
    } catch (e) {
      developer.log('❌ Error uploading weekly spending limit: $e');
      rethrow;
    }
  }

  /// Download weekly spending limits from Firestore
  static Future<List<Map<String, dynamic>>>
  downloadWeeklySpendingLimits() async {
    if (!_isAuthenticated || _weeklySpendingLimitsCollection == null) {
      developer.log(
        '❌ Cannot download weekly spending limits: User not authenticated',
      );
      return [];
    }

    try {
      developer.log('📥 Downloading weekly spending limits from Firestore');
      final snapshot = await _weeklySpendingLimitsCollection!.get();
      final limits = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['firestoreId'] = doc.id;
        return data;
      }).toList();
      developer.log('✅ Downloaded ${limits.length} weekly spending limits');
      return limits;
    } catch (e) {
      developer.log('❌ Error downloading weekly spending limits: $e');
      return [];
    }
  }
}
