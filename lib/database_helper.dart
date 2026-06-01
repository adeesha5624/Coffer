import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // 💡 Reset/Close the database connection (called on logout)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // 💡 ඩේටාබේස් එක මුලින්ම හැදෙද්දී ඔක්කොම ටේබල් ටික නිවැරදිව ක්‍රියේට් කිරීම
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

    // 💡 Default Accounts දෙක ඇතුළත් කිරීම
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
  // 🌐 GLOBAL SEARCH FUNCTION (පිළිවෙළට සකස් කළා)
  // ==========================================

  // 🔍 Name හෝ Reason (Food/Transport) හරහා ණය දත්ත සර්ච් කිරීමේ Universal Query එක
  Future<List<Map<String, dynamic>>> searchGlobalHistory(String query) async {
    final db = await instance.database;

    // %query% දාන්නේ වචනය මැද තිබුණත් (e.g., "Kema Food") ලස්සනට අහුවෙන්නයි
    String searchQuery = '%$query%';

    return await db.query(
      'debts',
      where: 'person_name LIKE ? OR reason LIKE ?',
      whereArgs: [searchQuery, searchQuery],
      orderBy: 'date DESC', // අලුත්ම ගනුදෙනු උඩට එන්න සෙට් කරනවා
    );
  }

  // ==========================================
  // 🤝 TRANSFER & DEBTS FUNCTIONS
  // ==========================================

  // 💡 එකවුන්ට් එකකින් තව එකකට සල්ලි මාරු කිරීමේ සුපිරිම Function එක
  Future<void> addTransfer(
    int fromAccountId,
    int toAccountId,
    double amount,
    String date,
  ) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // 1. සල්ලි කැපෙන එකවුන්ට් එකෙන් අඩු කරනවා
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [amount, fromAccountId],
      );

      // 2. සල්ලි වැටෙන එකවුන්ට් එකට එකතු කරනවා
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [amount, toAccountId],
      );

      // 3. පස්සේ ඉතිහාසය (History) බලන්න Transactions එකට Record එකක් දානවා
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

  // ==========================================
  // 🔍 ADVANCED SEARCH & ANALYTICS
  // ==========================================

  /// Name/Reason search + Date Range filter combine කරලා debts return කරනවා
  /// query empty නම් date range එකට ඔක්කොම debts return කරනවා
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

  /// Category/reason එකට match වෙන debts date range එකට analytics return කරනවා
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

  /// Date range එකට ඔක්කොම debts, reason wise group කරලා totals return කරනවා
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
