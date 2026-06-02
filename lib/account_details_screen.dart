import 'package:flutter/material.dart';
import 'database_helper.dart';

class AccountDetailsScreen extends StatefulWidget {
  final int accountId;
  final String accountName;
  const AccountDetailsScreen({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _InsideItem {
  final String category;
  final String date;
  final double amount;
  final String subInfo;

  _InsideItem({
    required this.category,
    required this.date,
    required this.amount,
    required this.subInfo,
  });
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  List<_InsideItem> _combinedList = [];
  bool _isLoading = true;
  late String _currentAccountName;

  @override
  void initState() {
    super.initState();
    _currentAccountName = widget.accountName;
    _loadAllRecords();
  }

  Future<void> _loadAllRecords() async {
    final db = await DatabaseHelper.instance.database;
    List<_InsideItem> temp = [];

    // 1. සාමාන්‍ය Transactions ඇදලා ගැනීම
    final txData = await db.query(
      'transactions',
      where: 'account_id = ?',
      whereArgs: [widget.accountId],
    );

    for (var row in txData) {
      double amt = (row['amount'] as num).toDouble();
      // Transfer හෝ Expense නම් සල්ලි අඩු වෙනවා, Income නම් වැඩි වෙනවා
      if (row['type'] == 'Expense' || row['type'] == 'Transfer') {
        amt = -amt.abs();
      } else if (row['type'] == 'Income') {
        amt = amt.abs();
      }

      temp.add(_InsideItem(
        category: row['category'] as String,
        date: row['date'] as String,
        amount: amt,
        subInfo: row['description'] != null ? row['description'] as String : '',
      ));
    }

    // 2. 💡 ණය (Debts) ටේබල් එකෙන් මේ එකවුන්ට් එකට අදාළ දත්ත ඇදලා ගැනීම
    final debtData = await db.query(
      'debts',
      where: 'account_id = ?',
      whereArgs: [widget.accountId],
    );

    for (var row in debtData) {
      double amt = (row['amount'] as num).toDouble();
      String type = row['type'] as String; // 'Give' හෝ 'Take'
      String person = row['person_name'] as String;
      String reason = row['reason'] != null ? row['reason'] as String : '';

      // ණය ගත්තා නම් (Take) සල්ලි එකතු වෙනවා, ණය දුන්නා නම් (Give) සල්ලි අඩු වෙනවා
      double calculatedAmt = type == 'Take' ? amt.abs() : -amt.abs();
      String displayText =
          type == 'Take' ? "Borrowed from $person" : "Lent to $person";

      temp.add(_InsideItem(
        category: type == 'Take' ? "Loan Taken" : "Loan Given",
        date: row['date'] as String,
        amount: calculatedAmt,
        subInfo: reason.isNotEmpty ? "$displayText ($reason)" : displayText,
      ));
    }

    // 3. 📅 දත්ත ඔක්කොම දිනය අනුව අලුත්ම ඒවා උඩට එන විදිහට Sort කිරීම
    temp.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _combinedList = temp;
      _isLoading = false;
    });
  }

  void _showRenameDialog() {
    final nameController = TextEditingController(text: _currentAccountName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Rename Account",
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(
              hintText: "New name...",
              hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.24))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Theme.of(context).primaryColor),
            onPressed: () async {
              String newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                final nav = Navigator.of(context);
                await DatabaseHelper.instance
                    .updateAccountName(widget.accountId, newName);
                if (!mounted) return;
                setState(() => _currentAccountName = newName);
                nav.pop();
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Delete Account?"),
        content: const Text("Are you sure you want to delete this account?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await DatabaseHelper.instance.deleteAccount(widget.accountId);
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_currentAccountName,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_note,
                  color: Colors.cyanAccent, size: 28),
              onPressed: _showRenameDialog),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 24),
              onPressed: _showDeleteConfirmation),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent))
          : _combinedList.isEmpty
              ? Center(
                  child: Text("No records found for this account",
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.24))))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _combinedList.length,
                  itemBuilder: (context, index) {
                    final item = _combinedList[index];
                    bool isPlus = item.amount > 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isPlus
                              ? Colors.greenAccent.withValues(alpha: 0.1)
                              : Colors.redAccent.withValues(alpha: 0.1),
                          child: Icon(isPlus ? Icons.add : Icons.remove,
                              color: isPlus
                                  ? Colors.greenAccent
                                  : Colors.redAccent),
                        ),
                        title: Text(item.category,
                            style: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.date,
                                style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.38), fontSize: 11)),
                            if (item.subInfo.isNotEmpty)
                              Text(item.subInfo,
                                  style: const TextStyle(
                                      color: Colors.cyanAccent, fontSize: 12)),
                          ],
                        ),
                        trailing: Text(
                          "${isPlus ? '+' : '-'} Rs. ${item.amount.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                              color: isPlus
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
