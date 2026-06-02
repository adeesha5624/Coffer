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
  List<_GlobalRecord> _displayedRecords = [];
  bool _isLoading = true;
  late double _currentNetWorth;

  final _searchController = TextEditingController();
  String _currentQuery = "";

  // Date Range
  DateTime _dateFrom = DateTime(2000);
  DateTime _dateTo = DateTime.now();
  String _selectedPeriod = 'All';

  @override
  void initState() {
    super.initState();
    _currentNetWorth = widget.totalNetWorth;
    _setDatePeriod('All');
  }

  void _setDatePeriod(String period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = period;
      switch (period) {
        case 'Today':
          _dateFrom = DateTime(now.year, now.month, now.day);
          _dateTo = now;
          break;
        case 'Week':
          _dateFrom = now.subtract(Duration(days: now.weekday - 1));
          _dateTo = now;
          break;
        case 'Month':
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = now;
          break;
        case 'All':
          _dateFrom = DateTime(2000);
          _dateTo = now;
          break;
      }
    });
    _loadAllWalletRecords();
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigoAccent,
              onPrimary: Colors.black,
              surface: Theme.of(context).cardColor,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
        _selectedPeriod = 'Custom';
      });
      _loadAllWalletRecords();
    }
  }

  void _filterRecords() {
    setState(() {
      _currentQuery = _searchController.text.trim().toLowerCase();
      _displayedRecords = _allRecords.where((rec) {
        DateTime recDate;
        try {
          recDate = DateTime.parse(rec.date);
        } catch (e) {
          recDate = DateTime.now();
        }
        
        bool isAfterFrom = recDate.isAfter(_dateFrom.subtract(const Duration(days: 1)));
        bool isBeforeTo = recDate.isBefore(_dateTo.add(const Duration(days: 1)));
        bool dateMatch = isAfterFrom && isBeforeTo;

        bool textMatch = true;
        if (_currentQuery.isNotEmpty) {
          textMatch = rec.title.toLowerCase().contains(_currentQuery) ||
                      rec.subtitle.toLowerCase().contains(_currentQuery);
        }

        return dateMatch && textMatch;
      }).toList();
    });
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
    _filterRecords();
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Net Worth Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Net Worth Panel
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Theme.of(context).cardColor, Theme.of(context).scaffoldBackgroundColor]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.1) ?? Colors.transparent),
                  ),
                  child: Column(
                    children: [
                      Text("Current Net Worth",
                          style:
                              TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.38), fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(
                        "Rs. ${_currentNetWorth.toStringAsFixed(2)}",
                        style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigoAccent,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // 🔍 Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _filterRecords(),
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigoAccent),
                      hintText: "Search Food, Reason, Category...",
                      hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.38)),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
                      suffixIcon: _currentQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                              onPressed: () {
                                _searchController.clear();
                                _filterRecords();
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // 📅 Date Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: ['Today', 'Week', 'Month', 'All'].map((period) {
                      bool isSelected = _selectedPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(period),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) _setDatePeriod(period);
                          },
                          backgroundColor: Theme.of(context).cardColor,
                          selectedColor: (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.indigoAccent.withValues(alpha: 0.2)),
                          labelStyle: TextStyle(
                            color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigoAccent) : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigoAccent) : (Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.1) ?? Colors.transparent),
                            ),
                          ),
                        ),
                      );
                    }).toList()
                      ..add(
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ActionChip(
                            label: const Text('Custom'),
                            avatar: Icon(Icons.date_range, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                            backgroundColor: Theme.of(context).cardColor,
                            labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.1) ?? Colors.transparent),
                            ),
                            onPressed: () => _pickDateRange(),
                          ),
                        ),
                      ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("All Statements (Swipe left to delete)",
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ),
                ),

                // History List
                Expanded(
                  child: _displayedRecords.isEmpty
                      ? Center(
                          child: Text("No statement records found",
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.24))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _displayedRecords.length,
                          itemBuilder: (context, index) {
                            final rec = _displayedRecords[index];

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
                                      backgroundColor: Theme.of(context).cardColor,
                                      title: Text(
                                        "Confirm Delete",
                                        style: TextStyle(
                                            color: Theme.of(context).textTheme.bodyLarge?.color,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      content: Text(
                                        "Are you sure you want to delete '${rec.title}'? This will revert your account balance.",
                                        style: TextStyle(
                                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text("Cancel",
                                              style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.38))),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.redAccent),
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text("Delete",
                                              style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodyLarge?.color)),
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
                                child: Icon(Icons.delete_sweep,
                                    color: Theme.of(context).textTheme.bodyLarge?.color, size: 28),
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
                                              style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)),
                                          Text(rec.date,
                                              style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.38),
                                                  fontSize: 11)),
                                          if (rec.subtitle.isNotEmpty)
                                            Text(rec.subtitle,
                                                style: TextStyle(
                                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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
