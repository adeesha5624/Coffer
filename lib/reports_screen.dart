import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
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

    // Auto search if there's already a query
    if (_currentQuery.isNotEmpty || _searchResults.isNotEmpty) {
      _handleSearch();
    }
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
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
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

      if (_currentQuery.isNotEmpty || _searchResults.isNotEmpty) {
        _handleSearch();
      }
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

    // Search with date range filter
    final data = await DatabaseHelper.instance.searchByDateRange(
      query: query.isEmpty ? null : query,
      dateFrom: dateFromStr,
      dateTo: dateToStr,
    );

    // Analytics calculate කරනවා
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

    final pdf = pw.Document();
    final dateRange =
        "${DateFormat('MMM dd, yyyy').format(_dateFrom)} - ${DateFormat('MMM dd, yyyy').format(_dateTo)}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Report Header
                pw.Text(
                  "UNIVERSAL WALLET - TRANSACTION REPORT",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  "Generated: ${DateTime.now().toString().split(' ').first}",
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 11,
                  ),
                ),
                pw.Text(
                  "Period: $dateRange",
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 11,
                  ),
                ),
                if (_currentQuery.isNotEmpty)
                  pw.Text(
                    "Search: \"$_currentQuery\"",
                    style: const pw.TextStyle(
                      color: PdfColors.blue800,
                      fontSize: 11,
                    ),
                  ),
                pw.Divider(thickness: 1.5, color: PdfColors.blue900),
                pw.SizedBox(height: 15),

                // Summary Card
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
                            "Total Given: Rs. ${_totalGiven.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.red800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "Total Taken: Rs. ${_totalTaken.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              fontSize: 11,
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
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            "${_netBalance >= 0 ? '+' : ''} Rs. ${_netBalance.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: _netBalance >= 0
                                  ? PdfColors.green800
                                  : PdfColors.red800,
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
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                      ),
                      children: [
                        _pdfHeader("Date"),
                        _pdfHeader("Name"),
                        _pdfHeader("Type"),
                        _pdfHeader("Reason"),
                        _pdfHeader("Amount"),
                      ],
                    ),
                    ..._searchResults.map((row) {
                      double amt = (row['amount'] as num).toDouble();
                      bool isTake = row['type'] == 'Take';
                      return pw.TableRow(
                        children: [
                          _pdfCell(row['date'].toString()),
                          _pdfCell(row['person_name'].toString()),
                          _pdfCell(isTake ? "Taken" : "Given"),
                          _pdfCell(row['reason'] ?? '-'),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              "${isTake ? '+' : '-'} ${amt.toStringAsFixed(0)}",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: isTake
                                    ? PdfColors.green800
                                    : PdfColors.red800,
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
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final fileName = _currentQuery.isNotEmpty
          ? "Report_${_currentQuery}_${DateFormat('yyyyMMdd').format(_dateFrom)}"
          : "Report_${DateFormat('yyyyMMdd').format(_dateFrom)}_${DateFormat('yyyyMMdd').format(_dateTo)}";
      final file = File("${output.path}/$fileName.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
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
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text(
          "Universal Reports",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.manage_search,
                        color: Colors.cyanAccent,
                      ),
                      hintText: "Search Friend Name...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _currentQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white38,
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
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _handleSearch,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.black,
                      size: 24,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.cyanAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd').format(_dateFrom),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.white24,
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
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.cyanAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd').format(_dateTo),
                            style: const TextStyle(
                              color: Colors.white,
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

            const SizedBox(height: 10),

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
                            ? Colors.cyanAccent.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? Colors.cyanAccent
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          period,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.cyanAccent
                                : Colors.white38,
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

            const SizedBox(height: 15),

            // Results Area
            _isLoading
                ? const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
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
                                  color: Colors.white.withValues(alpha: 0.08),
                                  size: 80,
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  "Search by Friend Name\nwith date filters to view reports",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white24,
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
                                      const Color(0xFF1E293B),
                                      const Color(
                                        0xFF1E293B,
                                      ).withValues(alpha: 0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.cyanAccent.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Header
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.analytics_rounded,
                                          color: Colors.cyanAccent,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _currentQuery.isNotEmpty
                                              ? "Analytics for '$_currentQuery'"
                                              : "Analytics Summary",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.cyanAccent.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            "$_totalCount records",
                                            style: const TextStyle(
                                              color: Colors.cyanAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Stats row
                                    Row(
                                      children: [
                                        // Given
                                        _buildStatItem(
                                          "Given",
                                          "Rs. ${_totalGiven.toStringAsFixed(0)}",
                                          Colors.redAccent,
                                          Icons.arrow_upward_rounded,
                                        ),
                                        const SizedBox(width: 10),
                                        // Taken
                                        _buildStatItem(
                                          "Taken",
                                          "Rs. ${_totalTaken.toStringAsFixed(0)}",
                                          Colors.greenAccent,
                                          Icons.arrow_downward_rounded,
                                        ),
                                        const SizedBox(width: 10),
                                        // Net
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

                              const SizedBox(height: 12),

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
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Icon
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
                                          const SizedBox(width: 12),

                                          // Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "${row['person_name']}",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    // Date chip
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
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
                                                        style: const TextStyle(
                                                          color: Colors.white38,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                    if (row['reason'] != null &&
                                                        row['reason']
                                                            .toString()
                                                            .isNotEmpty) ...[
                                                      const SizedBox(width: 6),
                                                      // Reason chip
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .cyanAccent
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
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .cyanAccent,
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

                                          // Amount
                                          Text(
                                            "${isTake ? '+' : '-'} Rs. ${amt.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              color: isTake
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
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

                              const SizedBox(height: 8),

                              // 📄 PDF Generate Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _generatePDFReport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyanAccent,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text(
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

  // 📊 Analytics stat item widget
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
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
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
