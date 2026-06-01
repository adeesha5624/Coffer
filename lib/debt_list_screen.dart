import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'add_debt_screen.dart';

class DebtListScreen extends StatefulWidget {
  final String initialType; // 'Give' හෝ 'Take'
  const DebtListScreen({super.key, required this.initialType});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  List<Map<String, dynamic>> _debts = [];
  final _settleAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshDebts();
  }

  Future<void> _refreshDebts() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query(
      'debts',
      where: 'type = ? AND status = ?',
      whereArgs: [widget.initialType, 'Pending'],
    );
    setState(() => _debts = data);
  }

  // ණය පියවීමේ Logic එක (Full හෝ Partial)
  void _settleDebt(int id, double currentAmount, String personName) async {
    double enteredAmount = double.tryParse(_settleAmountController.text) ?? 0.0;
    final db = await DatabaseHelper.instance.database;

    if (enteredAmount <= 0) return;

    if (enteredAmount >= currentAmount) {
      // 1. සම්පූර්ණ මුදලම ගෙවා අවසන් නම්
      await db.update(
        'debts',
        {'status': 'Settled', 'amount': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // 2. කොටසක් පමණක් ගෙවා ඇත්නම් (Partial Payment)
      double remaining = currentAmount - enteredAmount;
      await db.update(
        'debts',
        {'amount': remaining},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    // 3. Update account balance — use the account stored on the debt record
    final debtRow = await db.query('debts', where: 'id = ?', whereArgs: [id], limit: 1);
    final int accountId = debtRow.isNotEmpty
        ? (debtRow.first['account_id'] as int? ?? 1)
        : 1;
    double balanceChange =
        widget.initialType == 'Give' ? enteredAmount : -enteredAmount;
    await db.rawUpdate(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [balanceChange, accountId],
    );

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

  void _showSettleSheet(Map<String, dynamic> debt) {
    _settleAmountController.text =
        debt['amount'].toString(); // Default එකට මුළු ගාණම වැටෙන්න හදමු

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(
            context,
          ).viewInsets.bottom, // Keyboard එකට ඉඩ තැබීමට
          left: 25,
          right: 25,
          top: 25,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              debt['person_name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Remaining Balance: Rs. ${debt['amount'].toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.white38),
            ),
            const SizedBox(height: 25),
            const Text(
              "Amount to Settle",
              style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _settleAmountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF020617),
                prefixText: "Rs. ",
                prefixStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () =>
                  _settleDebt(debt['id'], debt['amount'], debt['person_name']),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.initialType == 'Give'
                    ? Colors.greenAccent
                    : Colors.redAccent,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                widget.initialType == 'Give'
                    ? "Confirm Collection"
                    : "Confirm Payment",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: Text(
          widget.initialType == 'Give' ? "Money to Collect" : "Money to Pay",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _debts.isEmpty
          ? const Center(
              child: Text(
                "No active debts found",
                style: TextStyle(color: Colors.white24),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _debts.length,
              itemBuilder: (context, index) {
                final debt = _debts[index];
                return GestureDetector(
                  onTap: () => _showSettleSheet(debt),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
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
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                debt['person_name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "Added: ${debt['date'] != null ? debt['date'].split(' ')[0] : ''}",
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "Rs. ${debt['amount'].toStringAsFixed(2)}",
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDebtScreen(initialType: widget.initialType),
            ),
          );
          _refreshDebts();
        },
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }
}
