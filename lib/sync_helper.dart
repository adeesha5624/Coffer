import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'pin_helper.dart';

/// ☁️ Cloud Sync Helper — Multi-device synchronization & Cloud backup via Firestore
class SyncHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _syncedUserKey = 'user_synced_uid';

  /// Check if this device has already confirmed / synced the session for this user
  static Future<bool> isSessionSynced(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncedUserKey) == uid;
  }

  /// Mark the session as synced on this device
  static Future<void> markSessionSynced(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncedUserKey, uid);
  }

  /// Clear the synced session flag (called on logout)
  static Future<void> clearSessionSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncedUserKey);
  }

  /// Check if Cloud Firestore has existing records for this user
  static Future<bool> hasCloudData(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('sync')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List txs = data['transactions'] as List? ?? [];
        final List debts = data['debts'] as List? ?? [];
        final List accounts = data['accounts'] as List? ?? [];

        if (txs.isNotEmpty || debts.isNotEmpty) return true;
        if (accounts.length > 2) return true;

        for (var acc in accounts) {
          if (acc is Map && (acc['balance'] as num?)?.toDouble() != 0.0) {
            return true;
          }
        }
      }

      // Check root document as fallback
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        final txCount = uData['transaction_count'] as int? ?? 0;
        final debtCount = uData['debt_count'] as int? ?? 0;
        if (txCount > 0 || debtCount > 0) return true;
      }

      return false;
    } catch (e) {
      debugPrint("SyncHelper.hasCloudData error: $e");
      return false;
    }
  }

  /// Get quick summary of cloud records to display in decision dialog
  static Future<Map<String, dynamic>> getCloudSummary(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('sync')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List txs = data['transactions'] as List? ?? [];
        final List debts = data['debts'] as List? ?? [];
        final List accounts = data['accounts'] as List? ?? [];

        return {
          'has_data': true,
          'transactions': txs.length,
          'debts': debts.length,
          'accounts': accounts.length,
          'updated_at': data['updated_at'],
        };
      }
    } catch (e) {
      debugPrint("SyncHelper.getCloudSummary error: $e");
    }
    return {'has_data': false, 'transactions': 0, 'debts': 0, 'accounts': 0};
  }

  /// Upload all local records from SQLite to Cloud Firestore
  static Future<void> syncAllToCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final db = await DatabaseHelper.instance.database;
      final accounts = await db.query('accounts');
      final transactions = await db.query('transactions');
      final debts = await db.query('debts');

      final prefs = await SharedPreferences.getInstance();
      final pinHash = prefs.getString('user_pin_hash');

      final userRef = _firestore.collection('users').doc(user.uid);
      final syncRef = userRef.collection('sync').doc('current');

      final bool hasRealData = transactions.isNotEmpty || debts.isNotEmpty;

      await syncRef.set({
        'accounts': accounts,
        'transactions': transactions,
        'debts': debts,
        'pin_hash': pinHash,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await userRef.set({
        'email': user.email,
        'has_data': hasRealData,
        'last_synced': FieldValue.serverTimestamp(),
        'transaction_count': transactions.length,
        'debt_count': debts.length,
        'account_count': accounts.length,
        'pin_hash': pinHash,
      }, SetOptions(merge: true));

      await markSessionSynced(user.uid);
      debugPrint("SyncHelper: Synced ${transactions.length} txs, ${debts.length} debts, ${accounts.length} accs.");
    } catch (e) {
      debugPrint("SyncHelper.syncAllToCloud error: $e");
    }
  }

  /// Restore all records from Cloud Firestore into local SQLite database
  static Future<bool> restoreFromCloud(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('sync')
          .doc('current')
          .get();

      if (!doc.exists || doc.data() == null) return false;

      final data = doc.data()!;
      final rawAccounts = (data['accounts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final rawTxs = (data['transactions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final rawDebts = (data['debts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      await DatabaseHelper.instance.restoreAllData(
        accounts: rawAccounts,
        transactions: rawTxs,
        debts: rawDebts,
      );

      // Restore PIN if available
      final pinHash = data['pin_hash'] as String?;
      if (pinHash != null && pinHash.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_pin_hash', pinHash);
        await prefs.setInt('pin_wrong_attempts', 0);
        await prefs.remove('pin_lock_until');
      }

      await markSessionSynced(uid);
      return true;
    } catch (e) {
      debugPrint("SyncHelper.restoreFromCloud error: $e");
      return false;
    }
  }

  /// Erase all cloud records and reset local SQLite to fresh defaults
  static Future<void> eraseCloudAndLocal(String uid) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      await userRef.collection('sync').doc('current').delete();
      await userRef.delete();
    } catch (e) {
      debugPrint("SyncHelper.eraseCloudAndLocal cloud error: $e");
    }

    // Reset local database
    await DatabaseHelper.instance.resetDatabaseToDefaults();

    // Clear PIN
    await PinHelper.clearPin();

    // Mark session synced so it doesn't prompt again
    await markSessionSynced(uid);

    // Sync clean default state to cloud
    await syncAllToCloud();
  }
}
