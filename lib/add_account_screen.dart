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
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text(
          "Add New Account",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Account Name", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            _buildTextField(_nameController, "e.g. HNB Bank, Commercial"),
            const SizedBox(height: 20),

            const Text(
              "Initial Balance (Rs.)",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            _buildTextField(_balanceController, "0.00", isNumber: true),
            const SizedBox(height: 20),

            const Text("Account Type", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            _buildTypeDropdown(),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () async {
                String name = _nameController.text.trim();
                double balance =
                    double.tryParse(_balanceController.text) ?? 0.0;

                if (name.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an account name')),
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
                backgroundColor: Colors.cyanAccent,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Save Account",
                style: TextStyle(
                  color: Colors.black,
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white10),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
      ),
      child: DropdownButton<String>(
        value: _selectedType,
        dropdownColor: const Color(0xFF1E293B),
        isExpanded: true,
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white),
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
