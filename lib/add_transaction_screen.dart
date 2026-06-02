import 'package:flutter/material.dart';
import 'database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType =
      'Expense'; // Expense, Income, Transfer 👈 අලුතින් ඇඩ් කළා
  String _selectedCategory = 'Food';
  int? _selectedFromAccountId; // සල්ලි කැපෙන Account එක
  int? _selectedToAccountId; // 💡 Transfer එකකදී සල්ලි වැටෙන Account එක

  List<Map<String, dynamic>> _accounts = [];

  final List<String> _expenseCategories = [
    'Food',
    'Fuel',
    'Rent',
    'Bills',
    'Entertainment',
    'Other'
  ];
  final List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investments',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final data = await DatabaseHelper.instance.getAccounts();
    setState(() {
      _accounts = data;
      if (data.isNotEmpty) {
        _selectedFromAccountId =
            data.first['id']; // Default එකට පළමු එකවුන්ට් එක ගන්නවා
      }
    });
  }

  void _saveTransaction() async {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty || _selectedFromAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount greater than 0")),
      );
      return;
    }

    // 💡 1. TRANSFER එකක් නම් කරන්නේ මෙන්න මේකයි:
    if (_selectedType == 'Transfer') {
      if (_selectedToAccountId == null ||
          _selectedFromAccountId == _selectedToAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Please select two different accounts for transfer")),
        );
        return;
      }

      await DatabaseHelper.instance.addTransfer(
        _selectedFromAccountId!,
        _selectedToAccountId!,
        amount,
        DateTime.now().toString().split(' ').first, // YYYY-MM-DD
      );
    }
    // 2. සාමාන්‍ය INCOME / EXPENSE එකක් නම්:
    else {
      final db = await DatabaseHelper.instance.database;

      // Transactions ටේබල් එකට දානවා
      await db.insert('transactions', {
        'amount': amount,
        'type': _selectedType,
        'category': _selectedCategory,
        'date': DateTime.now().toString().split(' ').first,
        'description': _descriptionController.text,
        'account_id': _selectedFromAccountId,
      });

      // අදාළ එකවුන්ට් එකේ බැලන්ස් එක අප්ඩේට් කරනවා
      double balanceChange = _selectedType == 'Income' ? amount : -amount;
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [balanceChange, _selectedFromAccountId],
      );
    }

    if (mounted) Navigator.pop(context); // ඉවර වෙලා ආපහු Dashboard එකට යනවා
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Record",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. TYPE SELECTOR (Segmented Buttons) ---
            Row(
              children: ['Expense', 'Income', 'Transfer'].map((type) {
                bool isSelected = _selectedType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                        _selectedCategory = type == 'Income'
                            ? _incomeCategories.first
                            : _expenseCategories.first;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigoAccent)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),

            // --- 2. AMOUNT INPUT ---
            Text("Amount (Rs.)",
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
                hintText: "0.00",
              ),
            ),
            const SizedBox(height: 20),

            // --- 3. FROM ACCOUNT DROPDOWN ---
            Text(
                _selectedType == 'Transfer' ? "From Account" : "Select Account",
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            _buildAccountDropdown(_selectedFromAccountId, (val) {
              setState(() => _selectedFromAccountId = val);
            }),
            const SizedBox(height: 20),

            // --- 4. 💡 TO ACCOUNT DROPDOWN (Transfer එකක් නම් විතරක් පෙනේ) ---
            if (_selectedType == 'Transfer') ...[
              Text("To Account",
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5), fontSize: 13)),
              const SizedBox(height: 8),
              _buildAccountDropdown(_selectedToAccountId, (val) {
                setState(() => _selectedToAccountId = val);
              }),
              const SizedBox(height: 20),
            ],

            // --- 5. CATEGORY DROPDOWN (Transfer වලට ඕන නෑ) ---
            if (_selectedType != 'Transfer') ...[
              Text("Category",
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5), fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: Theme.of(context).cardColor,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
                ),
                items: (_selectedType == 'Income'
                        ? _incomeCategories
                        : _expenseCategories)
                    .map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 20),
            ],

            // --- 6. DESCRIPTION ---
            if (_selectedType != 'Transfer') ...[
              Text("Description (Optional)",
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5), fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
                  hintText: "Notes...",
                ),
              ),
              const SizedBox(height: 30),
            ],

            // --- 7. SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigoAccent,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Save Record",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // එකවුන්ට් ඩ්‍රොප්ඩවුන් එක ලේසියෙන් හදන්න Helper Widget එකක්
  Widget _buildAccountDropdown(int? currentValue, Function(int?) onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: currentValue,
      dropdownColor: Theme.of(context).cardColor,
      hint:
          Text("Select Account", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.3))),
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      items: _accounts.map((acc) {
        return DropdownMenuItem<int>(
          value: acc['id'],
          child: Text("${acc['name']} (Rs. ${acc['balance']})"),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
