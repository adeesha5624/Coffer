import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'add_debt_screen.dart';
import 'sync_helper.dart';

class DebtListScreen extends StatefulWidget {
  final String initialType; // 'Give' or 'Take'
  const DebtListScreen({super.key, required this.initialType});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  List<Map<String, dynamic>> _allDebts = [];
  List<Map<String, dynamic>> _filteredDebts = [];
  final _settleAmountController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshDebts();
  }

  @override
  void dispose() {
    _settleAmountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshDebts() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query(
      'debts',
      where: 'type = ? AND status = ?',
      whereArgs: [widget.initialType, 'Pending'],
      orderBy: 'id DESC',
    );
    if (mounted) {
      setState(() {
        _allDebts = data;
        _isLoading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredDebts = List.from(_allDebts);
    } else {
      _filteredDebts = _allDebts.where((debt) {
        final name = (debt['person_name'] ?? '').toString().toLowerCase();
        final reason = (debt['reason'] ?? '').toString().toLowerCase();
        final amount = (debt['amount'] ?? '').toString().toLowerCase();
        final date = (debt['date'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            reason.contains(query) ||
            amount.contains(query) ||
            date.contains(query);
      }).toList();
    }
  }

  // Settle debt logic (Full or Partial)
  void _settleDebt(int id, double currentAmount, String personName) async {
    double enteredAmount = double.tryParse(_settleAmountController.text) ?? 0.0;
    final db = await DatabaseHelper.instance.database;

    if (enteredAmount <= 0) return;

    if (enteredAmount >= currentAmount) {
      // 1. Fully settled
      await db.update(
        'debts',
        {'status': 'Settled', 'amount': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // 2. Partial payment
      double remaining = currentAmount - enteredAmount;
      await db.update(
        'debts',
        {'amount': remaining},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    // 3. Update account balance — use the account stored on the debt record
    final debtRow = await db.query(
      'debts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final int accountId = debtRow.isNotEmpty
        ? (debtRow.first['account_id'] as int? ?? 1)
        : 1;
    double balanceChange = widget.initialType == 'Give'
        ? enteredAmount
        : -enteredAmount;
    await db.rawUpdate(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [balanceChange, accountId],
    );

    SyncHelper.syncAllToCloud();
    if (mounted) {
      _settleAmountController.clear();
      Navigator.pop(context);
      _refreshDebts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enteredAmount >= currentAmount
                ? "Fully Settled with $personName"
                : "Received Rs. $enteredAmount from $personName",
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showEditReasonDialog(Map<String, dynamic> debt) {
    final editReasonController =
        TextEditingController(text: debt['reason']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Description (What it was for)",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add or edit why money was taken/given for ${debt['person_name']}:",
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editReasonController,
              autofocus: true,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: "e.g., Food, Loan, Purchase, Medical...",
                hintStyle: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.38),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).scaffoldBackgroundColor
                    : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "Cancel",
              style: TextStyle(color: AppTheme.textMuted(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newReason = editReasonController.text.trim();
              Navigator.pop(dialogCtx);
              await DatabaseHelper.instance.updateDebtReason(
                debt['id'] as int,
                newReason,
              );
              SyncHelper.syncAllToCloud();
              if (mounted) {
                _refreshDebts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Description updated successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.cyanAccent
                  : Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Save",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettleSheet(Map<String, dynamic> debt) {
    _settleAmountController.text = debt['amount']
        .toString(); // Set full remaining amount as default

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(
            context,
          ).viewInsets.bottom, // Padding for keyboard
          left: 25,
          right: 25,
          top: 25,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    debt['person_name'] ?? '',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_note_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.cyanAccent
                        : Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  tooltip: "Edit description",
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditReasonDialog(debt);
                  },
                ),
              ],
            ),
            if (debt['reason'] != null &&
                debt['reason'].toString().trim().isNotEmpty) ...[
              SizedBox(height: 6),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showEditReasonDialog(debt);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (widget.initialType == 'Give'
                            ? Colors.greenAccent
                            : Colors.redAccent)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 15,
                        color: widget.initialType == 'Give'
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "For: ${debt['reason'].toString().trim()}",
                          style: TextStyle(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? AppTheme.textSecondary(context)
                                : Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: AppTheme.textMuted(context),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              SizedBox(height: 6),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showEditReasonDialog(debt);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 14,
                        color: AppTheme.textMuted(context),
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Add description (what it was for)...",
                        style: TextStyle(
                          color: AppTheme.textMuted(context),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: 8),
            Text(
              "Remaining Balance: Rs. ${debt['amount'].toStringAsFixed(2)}",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textMuted(context)
                    : Colors.black54,
              ),
            ),
            SizedBox(height: 25),
            Text(
              "Amount to Settle",
              style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _settleAmountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).scaffoldBackgroundColor
                    : Colors.grey[200],
                prefixText: "Rs. ",
                prefixStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.textSecondary(context)
                      : Colors.black87,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black26
                        : Colors.transparent,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black26
                        : Colors.transparent,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () =>
                  _settleDebt(debt['id'], debt['amount'], debt['person_name']),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.initialType == 'Give'
                    ? Colors.greenAccent
                    : Colors.redAccent,
                minimumSize: Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                widget.initialType == 'Give'
                    ? "Confirm Collection"
                    : "Confirm Payment",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalAmount = 0.0;
    for (final d in _filteredDebts) {
      totalAmount += (d['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.initialType == 'Give' ? "Money to Collect" : "Money to Pay",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.cyanAccent
                    : Colors.indigoAccent,
              ),
            )
          : Column(
              children: [
                // 🔍 Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFilter();
                      });
                    },
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.cyanAccent
                            : Colors.indigoAccent,
                      ),
                      hintText: "Search by person or description...",
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.38),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.black26
                              : Colors.transparent,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.black26
                              : Colors.transparent,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.5),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilter();
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // 📊 Summary row
                if (_allDebts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${_filteredDebts.length} ${_filteredDebts.length == 1 ? 'record' : 'records'}",
                          style: TextStyle(
                            color: AppTheme.textMuted(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Total: Rs. ${totalAmount.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: widget.initialType == 'Give'
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // List or empty state
                Expanded(
                  child: _allDebts.isEmpty
                      ? Center(
                          child: Text(
                            "No active debts found",
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white24
                                  : Colors.black38,
                            ),
                          ),
                        )
                      : _filteredDebts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 48,
                                    color: AppTheme.textMuted(context),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "No results found for \"$_searchQuery\"",
                                    style: TextStyle(
                                      color: AppTheme.textMuted(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _applyFilter();
                                      });
                                    },
                                    child: const Text("Clear search"),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _filteredDebts.length,
                              itemBuilder: (context, index) {
                                final debt = _filteredDebts[index];
                                final reason =
                                    debt['reason']?.toString().trim();
                                final bool hasReason =
                                    reason != null && reason.isNotEmpty;

                                return GestureDetector(
                                  onTap: () => _showSettleSheet(debt),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 15),
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                                .withValues(alpha: 0.05)
                                            : Colors.black26,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.05)
                                                  : Colors.black
                                                      .withValues(alpha: 0.05),
                                          child: Icon(
                                            widget.initialType == 'Give'
                                                ? Icons.arrow_downward
                                                : Icons.arrow_upward,
                                            color: widget.initialType == 'Give'
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            size: 18,
                                          ),
                                        ),
                                        SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                debt['person_name'] ?? '',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (hasReason) ...[
                                                const SizedBox(height: 5),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: (widget.initialType ==
                                                                'Give'
                                                            ? Colors.greenAccent
                                                            : Colors.redAccent)
                                                        .withValues(
                                                            alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .description_outlined,
                                                        size: 13,
                                                        color: widget.initialType ==
                                                                'Give'
                                                            ? Colors.greenAccent
                                                            : Colors.redAccent,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Flexible(
                                                        child: Text(
                                                          reason,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                                            context)
                                                                        .brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? AppTheme
                                                                    .textSecondary(
                                                                        context)
                                                                : Colors.black87,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Text(
                                                "Added: ${debt['date'] != null ? debt['date'].split(' ')[0] : ''}",
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? AppTheme.textMuted(
                                                          context,
                                                        )
                                                      : Colors.black54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          "Rs. ${(debt['amount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}",
                                          style: TextStyle(
                                            color: widget.initialType == 'Give'
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddDebtScreen(initialType: widget.initialType),
            ),
          );
          _refreshDebts();
        },
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.cyanAccent
            : Theme.of(context).primaryColor,
        child: Icon(
          Icons.add,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
