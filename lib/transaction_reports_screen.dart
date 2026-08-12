import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database_helper.dart';

class TransactionReportsScreen extends StatefulWidget {
  const TransactionReportsScreen({super.key});

  @override
  State<TransactionReportsScreen> createState() => _TransactionReportsScreenState();
}

class _TransactionReportsScreenState extends State<TransactionReportsScreen> {
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  
  // Accounts for filter
  List<Map<String, dynamic>> _accounts = [];
  int _selectedAccountId = -1; // -1 for All

  // Categories for filter
  final List<String> _expenseCategories = [
    'Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Other Expense'
  ];
  final List<String> _incomeCategories = [
    'Salary', 'Business', 'Gift', 'Investment', 'Other Income'
  ];
  String _selectedCategory = 'All';

  // 📊 Analytics data
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _netBalance = 0.0;
  int _totalCount = 0;

  // 📅 Date Range
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  String _selectedPeriod = 'Month'; // Day, Month, Year, Custom

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _setDatePeriod('Month');
  }

  Future<void> _loadAccounts() async {
    final accountData = await DatabaseHelper.instance.getAccounts();
    setState(() {
      _accounts = accountData;
    });
  }

  List<String> get _allCategories {
    return ['All', ..._expenseCategories, ..._incomeCategories, 'Transfer'];
  }

  // 📅 Quick date period chips
  void _setDatePeriod(String period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = period;
      switch (period) {
        case 'Day':
          _dateFrom = DateTime(now.year, now.month, now.day);
          _dateTo = now;
          break;
        case 'Month':
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = now;
          break;
        case 'Year':
          _dateFrom = DateTime(now.year, 1, 1);
          _dateTo = now;
          break;
        case 'All':
          _dateFrom = DateTime(2000);
          _dateTo = now;
          break;
      }
    });

    _handleSearch();
  }

  // 📅 Date Picker
  Future<void> _pickDate({required bool isFrom}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).brightness == Brightness.dark
                  ? Colors.cyanAccent
                  : const Color(0xFF00ADB5),
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
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
        _selectedPeriod = 'Custom';
      });

      _handleSearch();
    }
  }

  // 🔍 Fetch Data
  Future<void> _handleSearch() async {
    setState(() {
      _isLoading = true;
    });

    final String dateFromStr = DateFormat('yyyy-MM-dd').format(_dateFrom);
    final String dateToStr = DateFormat('yyyy-MM-dd').format(_dateTo);

    final data = await DatabaseHelper.instance.searchTransactionsByFilters(
      category: _selectedCategory,
      accountId: _selectedAccountId,
      dateFrom: dateFromStr,
      dateTo: dateToStr,
    );

    double income = 0.0;
    double expense = 0.0;
    int count = data.length;

    for (var row in data) {
      double amt = (row['amount'] as num).toDouble();
      if (row['type'] == 'Income') {
        income += amt;
      } else if (row['type'] == 'Expense') {
        expense += amt;
      }
    }

    setState(() {
      _searchResults = data;
      _totalIncome = income;
      _totalExpense = expense;
      _netBalance = income - expense;
      _totalCount = count;
      _isLoading = false;
    });
  }

  // 📄 PDF Report with Date Range
  Future<void> _generatePDFReport() async {
    if (_searchResults.isEmpty) return;

    final pdf = pw.Document();
    final dateRange =
        "${DateFormat('MMM dd, yyyy').format(_dateFrom)} - ${DateFormat('MMM dd, yyyy').format(_dateTo)}";
    
    String accountName = "All Accounts";
    if (_selectedAccountId != -1) {
      final acc = _accounts.firstWhere((element) => element['id'] == _selectedAccountId, orElse: () => {});
      if (acc.isNotEmpty) accountName = acc['name'];
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "TRANSACTION REPORT",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  "Generated: ${DateTime.now().toString().split(' ').first}",
                  style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                ),
                pw.Text(
                  "Period: $dateRange",
                  style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                ),
                pw.Text(
                  "Category: $_selectedCategory | Account: $accountName",
                  style: const pw.TextStyle(color: PdfColors.blue800, fontSize: 11),
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.blue900),
                pw.SizedBox(height: 15),

                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Total Income: Rs. ${_totalIncome.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.green800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "Total Expense: Rs. ${_totalExpense.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.red800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            "Net Change:",
                            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                          ),
                          pw.Text(
                            "${_netBalance >= 0 ? '+' : ''} Rs. ${_netBalance.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: _netBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                pw.Text(
                  "Transactions ($_totalCount records)",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                      children: [
                        _pdfHeader("Date"),
                        _pdfHeader("Category"),
                        _pdfHeader("Type"),
                        _pdfHeader("Account"),
                        _pdfHeader("Amount"),
                      ],
                    ),
                    ..._searchResults.map((row) {
                      double amt = (row['amount'] as num).toDouble();
                      bool isIncome = row['type'] == 'Income';
                      bool isTransfer = row['type'] == 'Transfer';
                      String typeName = isTransfer ? 'Transfer' : (isIncome ? 'Income' : 'Expense');
                      return pw.TableRow(
                        children: [
                          _pdfCell(row['date'].toString()),
                          _pdfCell(row['category'].toString()),
                          _pdfCell(typeName),
                          _pdfCell((row['account_name'] ?? 'Unknown').toString()),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              "${isIncome ? '+' : (isTransfer ? '' : '-')} ${amt.toStringAsFixed(0)}",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: isTransfer ? PdfColors.blue800 : (isIncome ? PdfColors.green800 : PdfColors.red800),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Center(
                  child: pw.Text(
                    "Thank you for using Universal Wallet App",
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final fileName = "TransactionReport_${DateFormat('yyyyMMdd').format(_dateFrom)}_${DateFormat('yyyyMMdd').format(_dateTo)}";
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: "$fileName.pdf",
      );
    } catch (e) {
      debugPrint("PDF Generation Error: $e");
    }
  }

  pw.Widget _pdfHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color secondaryTextColor = isDark ? AppTheme.textSecondary(context) : const Color(0xFF334155);
    final Color mutedTextColor = isDark ? AppTheme.textMuted(context) : const Color(0xFF64748B);
    final Color containerBg = isDark ? Theme.of(context).cardColor : const Color(0xFFF1F5F9);
    final Color itemTileBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color accentColor = isDark ? Colors.cyanAccent : const Color(0xFF00ADB5);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Transaction Reports",
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primaryTextColor,
        iconTheme: IconThemeData(color: primaryTextColor),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: accentColor),
            tooltip: "Export as PDF",
            onPressed: _searchResults.isEmpty ? null : _generatePDFReport,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Filters Row (Category & Account)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: containerBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedCategory,
                        dropdownColor: Theme.of(context).cardColor,
                        icon: Icon(Icons.arrow_drop_down, color: accentColor),
                        style: TextStyle(color: primaryTextColor, fontSize: 14),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedCategory = newValue);
                            _handleSearch();
                          }
                        },
                        items: _allCategories.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: containerBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedAccountId,
                        dropdownColor: Theme.of(context).cardColor,
                        icon: Icon(Icons.arrow_drop_down, color: accentColor),
                        style: TextStyle(color: primaryTextColor, fontSize: 14),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedAccountId = newValue);
                            _handleSearch();
                          }
                        },
                        items: [
                          const DropdownMenuItem<int>(
                            value: -1,
                            child: Text('All Accounts'),
                          ),
                          ..._accounts.map<DropdownMenuItem<int>>((Map<String, dynamic> acc) {
                            return DropdownMenuItem<int>(
                              value: acc['id'] as int,
                              child: Text(acc['name'] as String),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),

            // 📅 Date Range Row
            Row(
              children: [
                // From date
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(isFrom: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: containerBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: accentColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd, yyyy').format(_dateFrom),
                            style: TextStyle(color: primaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: mutedTextColor, size: 16),
                ),
                // To date
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(isFrom: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: containerBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: accentColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd, yyyy').format(_dateTo),
                            style: TextStyle(color: primaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 📅 Quick Period Chips
            Row(
              children: ['Day', 'Month', 'Year', 'All'].map((period) {
                final isSelected = _selectedPeriod == period;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _setDatePeriod(period),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? accentColor : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          period,
                          style: TextStyle(
                            color: isSelected ? (isDark ? Colors.cyanAccent : const Color(0xFF00ADB5)) : mutedTextColor,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 15),

            // Results Area
            _isLoading
                ? Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: accentColor),
                    ),
                  )
                : Expanded(
                    child: _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                  size: 80,
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  "No transactions found\nfor this period and filters.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: mutedTextColor, height: 1.5),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // 📊 Analytics Summary Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [containerBg, containerBg.withValues(alpha: 0.8)],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.analytics_rounded, color: accentColor, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Summary",
                                          style: TextStyle(color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "$_totalCount records",
                                            style: TextStyle(
                                              color: isDark ? Colors.cyanAccent : const Color(0xFF00ADB5),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    Row(
                                      children: [
                                        _buildStatItem("Income", "Rs. ${_totalIncome.toStringAsFixed(0)}", Colors.greenAccent, Icons.arrow_upward_rounded),
                                        const SizedBox(width: 10),
                                        _buildStatItem("Expense", "Rs. ${_totalExpense.toStringAsFixed(0)}", Colors.redAccent, Icons.arrow_downward_rounded),
                                        const SizedBox(width: 10),
                                        _buildStatItem("Net", "Rs. ${_netBalance.toStringAsFixed(0)}", _netBalance >= 0 ? Colors.greenAccent : Colors.redAccent, _netBalance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // 📋 Results List
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final row = _searchResults[index];
                                    bool isIncome = row['type'] == 'Income';
                                    bool isTransfer = row['type'] == 'Transfer';
                                    double amt = (row['amount'] as num).toDouble();
                                    String dateStr = row['date'] ?? '';
                                    String accountName = row['account_name'] ?? 'Unknown';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: itemTileBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isTransfer ? Colors.blueAccent.withValues(alpha: 0.1) : (isIncome ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              isTransfer ? Icons.swap_horiz : (isIncome ? Icons.download : Icons.upload),
                                              color: isTransfer ? Colors.blueAccent : (isIncome ? Colors.greenAccent : Colors.redAccent),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  row['category'] ?? '-',
                                                  style: TextStyle(
                                                    color: primaryTextColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "$accountName • $dateStr",
                                                  style: TextStyle(color: mutedTextColor, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                "${isIncome ? '+' : (isTransfer ? '' : '-')} Rs. ${amt.toStringAsFixed(0)}",
                                                style: TextStyle(
                                                  color: isTransfer ? Colors.blueAccent : (isIncome ? Colors.greenAccent : Colors.redAccent),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              if (row['description'] != null && row['description'].toString().isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    row['description'],
                                                    style: TextStyle(color: mutedTextColor, fontSize: 11),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
