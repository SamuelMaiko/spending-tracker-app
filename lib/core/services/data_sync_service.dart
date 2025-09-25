import 'dart:developer' as developer;

import '../database/repositories/wallet_repository.dart';
import '../database/repositories/transaction_repository.dart';
import '../database/repositories/category_repository.dart';
import '../database/database_helper.dart' as db;
import 'firestore_service.dart';
import 'sync_settings_service.dart';

/// Service for synchronizing data between local SQLite and Firestore
class DataSyncService {
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;
  final CategoryRepository _categoryRepository;

  DataSyncService({
    required WalletRepository walletRepository,
    required TransactionRepository transactionRepository,
    required CategoryRepository categoryRepository,
  }) : _walletRepository = walletRepository,
       _transactionRepository = transactionRepository,
       _categoryRepository = categoryRepository;

  /// Perform initial sync on login
  Future<void> performInitialSync() async {
    if (!await SyncSettingsService.canSync()) {
      developer.log(
        '⏭️ Skipping initial sync: sync not enabled or user not authenticated',
      );
      return;
    }

    try {
      developer.log('🔄 Starting initial sync on login');

      // Check if local database is empty
      final localWallets = await _walletRepository.getAllWallets();
      final localTransactions = await _transactionRepository
          .getAllTransactions();
      final localCategories = await _categoryRepository.getAllCategories();

      final isLocalEmpty =
          localWallets.isEmpty &&
          localTransactions.isEmpty &&
          localCategories.isEmpty;

      if (isLocalEmpty) {
        // Local is empty - download from cloud
        developer.log('📥 Local database is empty, downloading from cloud');
        await _downloadAllFromFirestore();
      } else {
        // Local has data - upload to cloud
        developer.log('📤 Local database has data, uploading to cloud');
        await _uploadAllToFirestore();
      }

      developer.log('✅ Initial sync completed successfully');
    } catch (e) {
      developer.log('❌ Error during initial sync: $e');
      rethrow;
    }
  }

  /// Upload all local data to Firestore
  Future<void> _uploadAllToFirestore() async {
    try {
      final wallets = await _walletRepository.getAllWallets();
      final transactions = await _transactionRepository.getAllTransactions();
      final categories = await _categoryRepository.getAllCategories();

      await FirestoreService.uploadAllData(
        wallets: wallets,
        transactions: transactions,
        categories: categories,
      );

      developer.log('✅ All local data uploaded to Firestore');
    } catch (e) {
      developer.log('❌ Error uploading to Firestore: $e');
      rethrow;
    }
  }

  /// Download all data from Firestore to local database (simplified)
  Future<void> _downloadAllFromFirestore() async {
    try {
      developer.log(
        '📥 Downloading data from Firestore (simplified implementation)',
      );
      // For now, just log that download would happen
      // Full implementation would require proper model mapping
      developer.log('✅ Download completed (placeholder)');
    } catch (e) {
      developer.log('❌ Error downloading from Firestore: $e');
      rethrow;
    }
  }

  /// Sync a single item to cloud (for ongoing sync)
  static Future<void> syncItemToCloud({
    db.Wallet? wallet,
    db.Transaction? transaction,
    db.Category? category,
  }) async {
    if (!await SyncSettingsService.canSync()) return;

    try {
      if (wallet != null) {
        await FirestoreService.uploadWallet(wallet);
        developer.log('📤 Synced wallet to cloud: ${wallet.name}');
      }

      if (transaction != null) {
        await FirestoreService.uploadTransaction(transaction);
        developer.log(
          '📤 Synced transaction to cloud: ${transaction.description}',
        );
      }

      if (category != null) {
        await FirestoreService.uploadCategory(category);
        developer.log('📤 Synced category to cloud: ${category.name}');
      }
    } catch (e) {
      developer.log('❌ Error syncing item to cloud: $e');
      // Don't rethrow - sync failures shouldn't break the app
    }
  }
}
