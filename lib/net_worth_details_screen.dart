import 'package:flutter/material.dart';
import 'database_helper.dart';

class NetWorthDetailsScreen extends StatefulWidget {
  final double totalNetWorth;
  const NetWorthDetailsScreen({super.key, required this.totalNetWorth});

  @override
  State<NetWorthDetailsScreen> createState() => _NetWorthDetailsScreenState();
}

class _GlobalRecord {
  final int id;
  final String title;
  final String date;
  final double amount;
  final String type; // Income, Expense, Transfer, Debt
  final String subtitle;

  _GlobalRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.type,
    required this.subtitle,
  });
}

class _NetWorthDetailsScreenState extends State<NetWorthDetailsScreen> {
  List<_GlobalRecord> _allRecords = [];
  bool _isLoading = true;
  late double _currentNetWorth;

  @override
  void initState() {
    super.initState();
    _currentNetWorth = widget.totalNetWorth;
    _loadAllWalletRecords();
  }

  Future<void> _loadAllWalletRecords() async {
    final db = await DatabaseHelper.instance.database;
    List<_GlobalRecord> temp = [];

    // 1. Transactions ඇදලා ගැනීම
    final txData = await db.query('transactions');
    for (var row in txData) {
      double amt = (row['amount'] as num).toDouble();
      String type = row['type'] as String;

      temp.add(_GlobalRecord(
        id: row['id'] as int,
        title: row['category'] as String,
        date: row['date'] as String,
        amount: amt,
        type: type,
        subtitle:
            row['description'] != null ? row['description'] as String : '',
      ));
    }

    // 2. ණය (Debts) ඇදලා ගැනීම
    final debtData = await db.query('debts');
    for (var row in debtData) {
      double amt = (row['amount'] as num).toDouble();
      String type = row['type'] as String;
      String person = row['person_name'] as String;

      temp.add(_GlobalRecord(
        id: row['id'] as int,
        title: type == 'Take' ? "Loan Taken" : "Loan Given",
        date: row['date'] as String,
        amount: amt,
        type: 'Debt',
        subtitle: type == 'Take' ? "Borrowed from $person" : "Lent to $person",
      ));
    }

    // 3. දින අනුව Sort කිරීම
    temp.sort((a, b) => b.date.compareTo(a.date));

    // 4. Net Worth එක ගණනය කිරීම
    final accountData = await DatabaseHelper.instance.getAccounts();
    double netWorth = 0;
    for (var item in accountData) {
      netWorth += (item['balance'] as num).toDouble();
    }

    setState(() {
      _allRecords = temp;
      _currentNetWorth = netWorth;
      _isLoading = false;
    });
  }

  // Reverse balance and delete the record
  Future<void> _deleteRecord(_GlobalRecord record) async {
    final db = await DatabaseHelper.instance.database;

    if (record.type == 'Debt') {
      // Fetch the debt row to get account_id and type before deleting
      final rows = await db.query('debts', where: 'id = ?', whereArgs: [record.id], limit: 1);
      if (rows.isNotEmpty) {
        final row = rows.first;
        final int accountId = (row['account_id'] as int? ?? 1);
        final double amount = (row['amount'] as num).toDouble();
        final String debtType = row['type'] as String;
        // Reverse: Give added money to account, Take reduced it
        final double reversal = debtType == 'Take' ? -amount : amount;
        await db.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?',
          [reversal, accountId],
        );
      }
      await DatabaseHelper.instance.deleteDebt(record.id);
    } else {
      // Fetch the transaction row
      final rows = await db.query('transactions', where: 'id = ?', whereArgs: [record.id], limit: 1);
      if (rows.isNotEmpty) {
        final row = rows.first;
        final int accountId = (row['account_id'] as int? ?? 1);
        final double amount = (row['amount'] as num).toDouble();
        final String txType = row['type'] as String;
        double reversal = 0;
        if (txType == 'Income') reversal = -amount;   // undo income
        if (txType == 'Expense') reversal = amount;   // undo expense
        if (txType == 'Transfer') reversal = amount;  // undo from-account deduction
        await db.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?',
          [reversal, accountId],
        );
      }
      await DatabaseHelper.instance.deleteTransaction(record.id);
    }

    _loadAllWalletRecords();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${record.title} deleted and balance reversed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text("Net Worth Analytics",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Column(
              children: [
                // Top Net Worth Panel
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Text("Current Net Worth",
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(
                        "Rs. ${_currentNetWorth.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("All Statements (Swipe left to delete)",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ),
                ),

                // History List
                Expanded(
                  child: _allRecords.isEmpty
                      ? const Center(
                          child: Text("No statement records found",
                              style: TextStyle(color: Colors.white24)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _allRecords.length,
                          itemBuilder: (context, index) {
                            final rec = _allRecords[index];

                            bool isPlus = rec.type == 'Income' ||
                                (rec.type == 'Debt' &&
                                    rec.title == "Loan Taken");
                            Color amtColor = isPlus
                                ? Colors.greenAccent
                                : (rec.type == 'Transfer'
                                    ? Colors.blueAccent
                                    : Colors.redAccent);

                            return Dismissible(
                              key: Key("${rec.type}_${rec.id}_$index"),
                              direction: DismissDirection.endToStart,

                              // 💡 මෙන්න මකන්න කලින් Confirm කරගන්න Pop-up එක අහන කෑල්ල
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      title: const Text(
                                        "Confirm Delete",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      content: Text(
                                        "Are you sure you want to delete '${rec.title}'? This will revert your account balance.",
                                        style: const TextStyle(
                                            color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text("Cancel",
                                              style: TextStyle(
                                                  color: Colors.white38)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.redAccent),
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text("Delete",
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },

                              background: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(18)),
                                alignment: Alignment.centerRight,
                                child: const Icon(Icons.delete_sweep,
                                    color: Colors.white, size: 28),
                              ),
                              onDismissed: (direction) {
                                _deleteRecord(rec);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(18)),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          amtColor.withValues(alpha: 0.1),
                                      child: Icon(
                                          isPlus
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: amtColor,
                                          size: 18),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(rec.title,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)),
                                          Text(rec.date,
                                              style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11)),
                                          if (rec.subtitle.isNotEmpty)
                                            Text(rec.subtitle,
                                                style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      "${isPlus ? '+' : '-'} Rs. ${rec.amount.toStringAsFixed(0)}",
                                      style: TextStyle(
                                          color: amtColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
