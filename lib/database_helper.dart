import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    // Get the current logged in user's UID to create a specific DB
    final User? user = FirebaseAuth.instance.currentUser;
    final String dbName = user != null ? 'wallet_${user.uid}.db' : 'wallet.db';
    
    _database = await _initDB(dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // 🌐 Web platform database initialization
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(filePath, version: 1, onCreate: _onCreate);
    } else {
      // 📱 Mobile platform database initialization
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(path, version: 1, onCreate: _onCreate);
    }
  }

  // 💡 Reset/Close the database connection (called on logout)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Initialize all database tables on first creation
  Future _onCreate(Database db, int version) async {
    // 1. Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type TEXT,
        balance REAL
      )
    ''');

    // 2. Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL,
        type TEXT,
        category TEXT,
        date TEXT,
        description TEXT,
        account_id INTEGER
      )
    ''');

    // 3. Debts Table
    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL,
        type TEXT,
        person_name TEXT,
        reason TEXT,
        date TEXT,
        status TEXT,
        account_id INTEGER
      )
    ''');

    // Insert default accounts
    await db.insert('accounts', {
      'name': 'Purse',
      'type': 'Cash',
      'balance': 0.00,
    });
    await db.insert('accounts', {
      'name': 'BOC',
      'type': 'Bank',
      'balance': 0.00,
    });
  }

  // ==========================================
  // 💳 ACCOUNTS FUNCTIONS
  // ==========================================

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await instance.database;
    return await db.query('accounts');
  }

  Future<int> updateAccountName(int id, String newName) async {
    final db = await instance.database;
    return await db.update(
      'accounts',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await instance.database;
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // 🌐 GLOBAL SEARCH FUNCTION
  // ==========================================

  // Universal query to search debt records by Person Name or Reason
  Future<List<Map<String, dynamic>>> searchGlobalHistory(String query) async {
    final db = await instance.database;

    // Use %query% wildcard to match terms anywhere in the string
    String searchQuery = '%$query%';

    return await db.query(
      'debts',
      where: 'person_name LIKE ? OR reason LIKE ?',
      whereArgs: [searchQuery, searchQuery],
      orderBy: 'date DESC', // Sort newest records first
    );
  }

  // ==========================================
  // 🤝 TRANSFER & DEBTS FUNCTIONS
  // ==========================================

  // Transfer money between accounts
  Future<void> addTransfer(
    int fromAccountId,
    int toAccountId,
    double amount,
    String date,
  ) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // 1. Deduct from source account
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [amount, fromAccountId],
      );

      // 2. Credit to destination account
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [amount, toAccountId],
      );

      // 3. Insert transaction record for transfer history
      await txn.insert('transactions', {
        'amount': amount,
        'type': 'Transfer',
        'category': 'Transfer',
        'date': date,
        'description': 'Transferred to another account',
        'account_id': fromAccountId,
      });
    });
  }

  Future<List<Map<String, dynamic>>> getDebtHistoryByPerson(
    String personName,
  ) async {
    final db = await instance.database;
    return await db.query(
      'debts',
      where: 'person_name = ? COLLATE NOCASE',
      whereArgs: [personName],
      orderBy: 'date DESC',
    );
  }

  // ==========================================
  // 📊 ANALYTICS & DELETE FUNCTIONS
  // ==========================================

  Future<List<Map<String, dynamic>>> getCategorySummary() async {
    final db = await instance.database;
    return await db.rawQuery(
      "SELECT category, SUM(amount) as total FROM transactions WHERE type = 'Expense' GROUP BY category",
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteDebt(int id) async {
    final db = await instance.database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateDebtReason(int id, String reason) async {
    final db = await instance.database;
    return await db.update(
      'debts',
      {'reason': reason},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reset database to default state (clears all records and leaves default Purse and BOC accounts)
  Future<void> resetDatabaseToDefaults() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('debts');
      await txn.delete('accounts');
      await txn.insert('accounts', {
        'name': 'Purse',
        'type': 'Cash',
        'balance': 0.00,
      });
      await txn.insert('accounts', {
        'name': 'BOC',
        'type': 'Bank',
        'balance': 0.00,
      });
    });
  }

  /// Restore all records from cloud into local SQLite database
  Future<void> restoreAllData({
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> debts,
  }) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('debts');
      await txn.delete('accounts');

      for (var acc in accounts) {
        await txn.insert('accounts', {
          if (acc['id'] != null) 'id': acc['id'],
          'name': acc['name'] ?? 'Account',
          'type': acc['type'] ?? 'Cash',
          'balance': (acc['balance'] as num?)?.toDouble() ?? 0.00,
        });
      }

      if (accounts.isEmpty) {
        await txn.insert('accounts', {
          'name': 'Purse',
          'type': 'Cash',
          'balance': 0.00,
        });
        await txn.insert('accounts', {
          'name': 'BOC',
          'type': 'Bank',
          'balance': 0.00,
        });
      }

      for (var tx in transactions) {
        await txn.insert('transactions', {
          if (tx['id'] != null) 'id': tx['id'],
          'amount': (tx['amount'] as num?)?.toDouble() ?? 0.00,
          'type': tx['type'] ?? 'Expense',
          'category': tx['category'] ?? 'General',
          'date': tx['date'] ?? '',
          'description': tx['description'] ?? '',
          'account_id': tx['account_id'],
        });
      }

      for (var debt in debts) {
        await txn.insert('debts', {
          if (debt['id'] != null) 'id': debt['id'],
          'amount': (debt['amount'] as num?)?.toDouble() ?? 0.00,
          'type': debt['type'] ?? 'Give',
          'person_name': debt['person_name'] ?? '',
          'reason': debt['reason'] ?? '',
          'date': debt['date'] ?? '',
          'status': debt['status'] ?? 'Pending',
          'account_id': debt['account_id'],
        });
      }
    });
  }

  // ==========================================
  // 🔍 ADVANCED SEARCH & ANALYTICS
  // ==========================================

  /// Return debts filtered by Name/Reason search and Date Range
  /// If query is empty, return all debts within date range
  Future<List<Map<String, dynamic>>> searchByDateRange({
    String? query,
    required String dateFrom,
    required String dateTo,
  }) async {
    final db = await instance.database;

    if (query != null && query.trim().isNotEmpty) {
      String searchQuery = '%${query.trim()}%';
      return await db.query(
        'debts',
        where: 'person_name LIKE ? AND date >= ? AND date <= ?',
        whereArgs: [searchQuery, dateFrom, dateTo],
        orderBy: 'date DESC',
      );
    } else {
      return await db.query(
        'debts',
        where: 'date >= ? AND date <= ?',
        whereArgs: [dateFrom, dateTo],
        orderBy: 'date DESC',
      );
    }
  }

  /// Transaction search with date range, category, and account filter
  Future<List<Map<String, dynamic>>> searchTransactionsByFilters({
    String? category,
    int? accountId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final db = await instance.database;
    String whereClause = 'date >= ? AND date <= ?';
    List<dynamic> whereArgs = [dateFrom, dateTo];

    if (category != null && category.trim().isNotEmpty && category != 'All') {
      whereClause += ' AND category = ?';
      whereArgs.add(category.trim());
    }
    
    if (accountId != null && accountId != -1) {
      whereClause += ' AND account_id = ?';
      whereArgs.add(accountId);
    }

    // Join with accounts to get account name
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT t.*, a.name as account_name 
      FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      WHERE $whereClause
      ORDER BY t.date DESC
    ''', whereArgs);

    return results;
  }

  /// Return debt analytics matching category/reason within date range
  /// totalGiven, totalTaken, netBalance, count
  Future<Map<String, dynamic>> getCategoryAnalytics({
    required String category,
    required String dateFrom,
    required String dateTo,
  }) async {
    final db = await instance.database;
    String searchQuery = '%${category.trim()}%';

    final givenResult = await db.rawQuery(
      "SELECT SUM(amount) as total, COUNT(*) as count FROM debts "
      "WHERE (person_name LIKE ? OR reason LIKE ?) AND type = 'Give' AND date >= ? AND date <= ?",
      [searchQuery, searchQuery, dateFrom, dateTo],
    );

    final takenResult = await db.rawQuery(
      "SELECT SUM(amount) as total, COUNT(*) as count FROM debts "
      "WHERE (person_name LIKE ? OR reason LIKE ?) AND type = 'Take' AND date >= ? AND date <= ?",
      [searchQuery, searchQuery, dateFrom, dateTo],
    );

    double totalGiven =
        (givenResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double totalTaken =
        (takenResult.first['total'] as num?)?.toDouble() ?? 0.0;
    int givenCount = (givenResult.first['count'] as int?) ?? 0;
    int takenCount = (takenResult.first['count'] as int?) ?? 0;

    return {
      'totalGiven': totalGiven,
      'totalTaken': totalTaken,
      'netBalance': totalTaken - totalGiven,
      'totalCount': givenCount + takenCount,
    };
  }

  /// Group debts by reason and return totals within date range
  Future<List<Map<String, dynamic>>> getExpenseAnalyticsByCategory({
    required String dateFrom,
    required String dateTo,
  }) async {
    final db = await instance.database;
    return await db.rawQuery(
      "SELECT reason, SUM(amount) as total, COUNT(*) as count "
      "FROM debts WHERE date >= ? AND date <= ? AND reason IS NOT NULL AND reason != '' "
      "GROUP BY reason ORDER BY total DESC",
      [dateFrom, dateTo],
    );
  }
}
