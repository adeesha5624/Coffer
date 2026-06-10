import 'package:flutter/material.dart';
import 'database_helper.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _selectedType = 'Bank'; // Default type

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Add New Account"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Account Name", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
            SizedBox(height: 10),
            _buildTextField(_nameController, "e.g. HNB Bank, Commercial"),
            SizedBox(height: 20),

            Text(
              "Initial Balance (Rs.)",
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
            ),
            SizedBox(height: 10),
            _buildTextField(_balanceController, "0.00", isNumber: true),
            SizedBox(height: 20),

            Text("Account Type", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
            SizedBox(height: 10),
            _buildTypeDropdown(),
            SizedBox(height: 40),

            ElevatedButton(
              onPressed: () async {
                String name = _nameController.text.trim();
                double balance =
                    double.tryParse(_balanceController.text) ?? 0.0;

                if (name.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter an account name')),
                  );
                  return;
                }
                final db = await DatabaseHelper.instance.database;
                await db.insert('accounts', {
                  'name': name,
                  'balance': balance,
                  'type': _selectedType,
                });
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Theme.of(context).primaryColor,
                minimumSize: Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                "Save Account",
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.3)),
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
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
      ),
      child: DropdownButton<String>(
        value: _selectedType,
        dropdownColor: Theme.of(context).cardColor,
        isExpanded: true,
        underline: SizedBox(),
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        items: [
          'Bank',
          'Cash',
          'Card',
        ].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
        onChanged: (val) => setState(() => _selectedType = val!),
      ),
    );
  }
}
