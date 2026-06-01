import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class AddDebtScreen extends StatefulWidget {
  final String initialType;
  const AddDebtScreen({super.key, this.initialType = 'Give'});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  late String _debtType;
  DateTime _selectedDate = DateTime.now();

  // Dynamic Accounts Variables
  List<Map<String, dynamic>> _accountsList = [];
  int? _selectedAccountId;
  bool _isLoadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _debtType = widget.initialType;
    _loadDatabaseAccounts();
  }

  // ඩේටාබේස් එකෙන් ඇත්තම එකවුන්ට්ස් ටික ගන්නවා
  Future<void> _loadDatabaseAccounts() async {
    try {
      final data = await DatabaseHelper.instance.getAccounts();
      setState(() {
        _accountsList = data;
        if (data.isNotEmpty) {
          _selectedAccountId = data.first['id'] as int;
        }
        _isLoadingAccounts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAccounts = false;
      });
      debugPrint("Error loading accounts: $e");
    }
  }

  // දින වකවානු තෝරන හැටි
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // 💡 පිරිසිදු කරන ලද නිවැරදි සේව් බටන් එකේ Logic එක
  Future<void> _saveDebt() async {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    String personName = _nameController.text.trim();

    if (personName.isEmpty || amount <= 0 || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill name and amount correctly"),
        ),
      );
      return;
    }

    final db = await DatabaseHelper.instance.database;

    // 1. ණය දත්ත ඇතුළත් කිරීම (Insert debt)
    await db.insert(
      'debts',
      {
        'amount': amount,
        'type': _debtType,
        'person_name': personName,
        'reason': _reasonController.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'status': 'Pending',
        'account_id': _selectedAccountId,
      },
    );

    // 2. ගිණුම් ශේෂය යාවත්කාලීන කිරීම (Update account balance)
    double balanceChange = _debtType == 'Give' ? -amount : amount;

    await db.rawUpdate(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [balanceChange, _selectedAccountId],
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text(
          "Add Debt / Loan",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingAccounts
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Switch (I Gave / I Took)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTypeButton(
                            "I Gave",
                            _debtType == 'Give',
                            Colors.greenAccent,
                          ),
                          _buildTypeButton(
                            "I Took",
                            _debtType == 'Take',
                            Colors.redAccent,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Person Name Input
                  _label("Person Name"),
                  _buildTextField(
                    _nameController,
                    "Who is it?",
                    Icons.person_outline,
                  ),

                  const SizedBox(height: 20),

                  // Reason Input
                  _label("Reason / Note"),
                  _buildTextField(
                    _reasonController,
                    "What is this for?",
                    Icons.edit_note,
                  ),

                  const SizedBox(height: 20),

                  // Amount Input
                  _label("Amount (Rs.)"),
                  _buildTextField(
                    _amountController,
                    "0.00",
                    Icons.payments_outlined,
                    isNumber: true,
                  ),

                  const SizedBox(height: 20),

                  // Account Dropdown සහ Date Picker එක එක ළඟින්
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dynamic Account Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label("Account"),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: _accountsList.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        "No Accounts",
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    )
                                  : DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _selectedAccountId,
                                        dropdownColor: const Color(0xFF1E293B),
                                        isExpanded: true,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        items: _accountsList.map((acc) {
                                          return DropdownMenuItem<int>(
                                            value: acc['id'] as int,
                                            child: Text(acc['name'].toString()),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedAccountId = val;
                                          });
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 15),

                      // Date Picker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label("Date"),
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.cyanAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      DateFormat('MMM dd')
                                          .format(_selectedDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveDebt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _debtType == 'Give'
                            ? Colors.greenAccent
                            : Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _debtType == 'Give' ? "Save & Collect" : "Save & Pay",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Label Widget
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
      ),
    );
  }

  // Type Selector Button
  Widget _buildTypeButton(String label, bool isSelected, Color activeColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _debtType = label == "I Gave" ? 'Give' : 'Take';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Reusable TextField
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.cyanAccent, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
