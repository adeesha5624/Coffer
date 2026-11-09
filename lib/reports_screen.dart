import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String _currentQuery = "";

  // 📊 Analytics data
  double _totalGiven = 0.0;
  double _totalTaken = 0.0;
  double _netBalance = 0.0;
  int _totalCount = 0;

  // 📅 Date Range
  DateTime _dateFrom = DateTime.now().subtract(Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  String _selectedPeriod = 'Month'; // Today, Week, Month, Custom

  @override
  void initState() {
    super.initState();
    _setDatePeriod('Month');
  }

  // 📅 Quick date period chips
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
                  : Color(0xFF00ADB5),
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

  // 🔍 Enhanced Universal Search with Date Range
  Future<void> _handleSearch() async {
    String query = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _currentQuery = query;
    });

    final String dateFromStr = DateFormat('yyyy-MM-dd').format(_dateFrom);
    final String dateToStr = DateFormat('yyyy-MM-dd').format(_dateTo);

    final data = await DatabaseHelper.instance.searchByDateRange(
      query: query.isEmpty ? null : query,
      dateFrom: dateFromStr,
      dateTo: dateToStr,
    );

    double given = 0.0;
    double taken = 0.0;
    int count = data.length;

    for (var row in data) {
      double amt = (row['amount'] as num).toDouble();
      if (row['type'] == 'Give') {
        given += amt;
      } else {
        taken += amt;
      }
    }

    setState(() {
      _searchResults = data;
      _totalGiven = given;
      _totalTaken = taken;
      _netBalance = taken - given;
      _totalCount = count;
      _isLoading = false;
    });
  }

  // 📄 PDF Report with Date Range
  Future<void> _generatePDFReport() async {
    if (_searchResults.isEmpty) return;

    // Filter out records with 0 or -0 and keep only active non-zero balances
    final validDebts = _searchResults.where((row) {
      final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
      return amt.abs() > 0.001;
    }).toList();

    if (validDebts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No debts with active balance found to generate report.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    double pdfGiven = 0.0;
    double pdfTaken = 0.0;
    for (var row in validDebts) {
      double amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
      if (row['type'] == 'Give') {
        pdfGiven += amt;
      } else {
        pdfTaken += amt;
      }
    }
    double pdfNetBalance = pdfTaken - pdfGiven;

    final pdf = pw.Document();
    final dateRange =
        "${DateFormat('MMM dd, yyyy').format(_dateFrom)} - ${DateFormat('MMM dd, yyyy').format(_dateTo)}";

    // Use MultiPage so data dynamically flows across multiple pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "COFFER - DEBT & LOAN REPORT",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  dateRange,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Generated: ${DateTime.now().toString().split('.').first}",
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(
                  "Page ${context.pageNumber} of ${context.pagesCount}",
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // Period & Query details
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Period: $dateRange",
                    style: const pw.TextStyle(
                      color: PdfColors.grey700,
                      fontSize: 10,
                    ),
                  ),
                  if (_currentQuery.isNotEmpty)
                    pw.Text(
                      "Filter: \"$_currentQuery\"",
                      style: const pw.TextStyle(
                        color: PdfColors.blue800,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              pw.Text(
                "Active Records: ${validDebts.length}",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Total Given (To Collect): Rs. ${pdfGiven.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.red800,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      "Total Taken (To Pay): Rs. ${pdfTaken.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.green800,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Net Balance:",
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      "${pdfNetBalance >= 0 ? '+' : ''} Rs. ${pdfNetBalance.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfNetBalance >= 0
                            ? PdfColors.green800
                            : PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),

          // Multi-page Table with repeating headers
          pw.TableHelper.fromTextArray(
            headers: ["Date", "Name", "Type", "Reason / Description", "Amount"],
            data: validDebts.map((row) {
              final double amt = (row['amount'] as num).toDouble();
              final bool isTake = row['type'] == 'Take';
              final String sign = isTake ? "+" : "-";
              final String reasonStr =
                  (row['reason'] != null &&
                          row['reason'].toString().trim().isNotEmpty)
                      ? row['reason'].toString().trim()
                      : '-';
              return [
                row['date']?.toString().split(' ').first ?? '',
                row['person_name']?.toString() ?? '',
                isTake ? "Taken (To Pay)" : "Given (To Collect)",
                reasonStr,
                "$sign Rs. ${amt.toStringAsFixed(2)}",
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue900,
            ),
            headerHeight: 24,
            cellHeight: 22,
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 4,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );

    try {
      final fileName = _currentQuery.isNotEmpty
          ? "DebtReport_${_currentQuery}_${DateFormat('yyyyMMdd').format(_dateFrom)}"
          : "DebtReport_${DateFormat('yyyyMMdd').format(_dateFrom)}_${DateFormat('yyyyMMdd').format(_dateTo)}";

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: "$fileName.pdf",
      );
    } catch (e) {
      debugPrint("PDF Generation Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check theme mode and configure dynamic colors
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryTextColor = isDark
        ? Colors.white
        : Color(0xFF0F172A);
    final Color secondaryTextColor = isDark
        ? AppTheme.textSecondary(context)
        : Color(0xFF334155);
    final Color mutedTextColor = isDark
        ? AppTheme.textMuted(context)
        : Color(0xFF64748B);
    final Color containerBg = isDark
        ? Theme.of(context).cardColor
        : Color(0xFFF1F5F9);
    final Color itemTileBg = isDark ? Color(0xFF0F172A) : Colors.white;
    final Color accentColor = isDark
        ? Colors.cyanAccent
        : Color(0xFF00ADB5);
    final Color searchIconColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        // 1. AppBar Title color in light mode
        title: Text(
          "Universal Reports",
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primaryTextColor,
        // 2. Back button color in light mode
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔍 Search Input Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    // 3. Text field input color adapts to theme mode
                    style: TextStyle(color: primaryTextColor),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.manage_search, color: accentColor),
                      hintText: "Search Friend Name...",
                      hintStyle: TextStyle(color: mutedTextColor),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: isDark ? Colors.transparent : Colors.black12,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: isDark ? Colors.transparent : Colors.black12,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                      suffixIcon: _currentQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: mutedTextColor,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _currentQuery = "";
                                  _searchResults = [];
                                  _totalGiven = 0;
                                  _totalTaken = 0;
                                  _netBalance = 0;
                                  _totalCount = 0;
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: _handleSearch,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: searchIconColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 15),

            // 📅 Date Range Row
            Row(
              children: [
                // From date
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(isFrom: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            containerBg, // 4. Background color adapts to dark/light mode
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: accentColor,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd').format(_dateFrom),
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: mutedTextColor,
                    size: 16,
                  ),
                ),
                // To date
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(isFrom: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: containerBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: accentColor,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd').format(_dateTo),
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 10),

            // 📅 Quick Period Chips
            Row(
              children: ['Today', 'Week', 'Month', 'All'].map((period) {
                final isSelected = _selectedPeriod == period;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _setDatePeriod(period),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          period,
                          // 5. Filter tab label styling
                          style: TextStyle(
                            color: isSelected
                                ? (isDark
                                      ? Colors.cyanAccent
                                      : Color(0xFF00ADB5))
                                : mutedTextColor,
                            fontSize: 11,
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

            SizedBox(height: 15),

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
                                  Icons.search_rounded,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  size: 80,
                                ),
                                SizedBox(height: 15),
                                Text(
                                  "Search by Friend Name\nwith date filters to view reports",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    height: 1.5,
                                  ),
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
                                    colors: [
                                      containerBg,
                                      containerBg.withValues(alpha: 0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.analytics_rounded,
                                          color: accentColor,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          _currentQuery.isNotEmpty
                                              ? "Analytics for '$_currentQuery'"
                                              : "Analytics Summary",
                                          style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            "$_totalCount records",
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.cyanAccent
                                                  : Color(0xFF00ADB5),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 14),

                                    Row(
                                      children: [
                                        _buildStatItem(
                                          "Given",
                                          "Rs. ${_totalGiven.toStringAsFixed(0)}",
                                          Colors.redAccent,
                                          Icons.arrow_upward_rounded,
                                        ),
                                        SizedBox(width: 10),
                                        _buildStatItem(
                                          "Taken",
                                          "Rs. ${_totalTaken.toStringAsFixed(0)}",
                                          Colors.greenAccent,
                                          Icons.arrow_downward_rounded,
                                        ),
                                        SizedBox(width: 10),
                                        _buildStatItem(
                                          "Net",
                                          "Rs. ${_netBalance.toStringAsFixed(0)}",
                                          _netBalance >= 0
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                          _netBalance >= 0
                                              ? Icons.trending_up_rounded
                                              : Icons.trending_down_rounded,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 12),

                              // 📋 Results List
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final row = _searchResults[index];
                                    bool isTake = row['type'] == 'Take';
                                    double amt = (row['amount'] as num)
                                        .toDouble();
                                    String dateStr = row['date'] ?? '';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            itemTileBg, // 6. List item tile background adapts to light/dark mode
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.04,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isTake
                                                  ? Colors.greenAccent
                                                        .withValues(alpha: 0.1)
                                                  : Colors.redAccent.withValues(
                                                      alpha: 0.1,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              isTake
                                                  ? Icons.call_received
                                                  : Icons.call_made,
                                              color: isTake
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                              size: 16,
                                            ),
                                          ),
                                          SizedBox(width: 12),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "${row['person_name']}",
                                                  style: TextStyle(
                                                    color:
                                                        primaryTextColor, // 7. Person name text color
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.05,
                                                                  )
                                                            : Colors.black
                                                                  .withValues(
                                                                    alpha: 0.05,
                                                                  ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              5,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        dateStr.split(' ')[0],
                                                        style: TextStyle(
                                                          color: mutedTextColor,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                    if (row['reason'] != null &&
                                                        row['reason']
                                                            .toString()
                                                            .isNotEmpty) ...[
                                                      SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              (isDark
                                                                      ? Colors
                                                                            .cyanAccent
                                                                      : Color(
                                                                          0xFF00ADB5,
                                                                        ))
                                                                  .withValues(
                                                                    alpha: 0.08,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                5,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          row['reason'],
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors
                                                                      .cyanAccent
                                                                : Color(
                                                                    0xFF00ADB5,
                                                                  ),
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          Text(
                                            amt == 0
                                                ? "Settled (Rs. 0)"
                                                : "${isTake ? '+' : '-'} Rs. ${amt.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              color: amt == 0
                                                  ? AppTheme.textMuted(context)
                                                  : (isTake
                                                      ? Colors.greenAccent
                                                      : Colors.redAccent),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              SizedBox(height: 8),

                              // 📄 PDF Generate Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _generatePDFReport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? Colors.cyanAccent
                                        : Theme.of(context).primaryColor,
                                    foregroundColor: isDark
                                        ? Colors.black
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  icon: Icon(Icons.picture_as_pdf),
                                  label: Text(
                                    "Download PDF Statement",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
