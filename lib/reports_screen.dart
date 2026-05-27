import 'dart:io';
import 'package:flutter/material.dart';
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
  double _finalBalance = 0.0;
  String _currentQuery = "";

  // 🔍 Universal Search Logic (Name, Reason, Food, Transport ඕනෑම එකක්)
  Future<void> _handleUniversalSearch() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentQuery = query;
    });

    // 💡 අපේ අලුත් Global Search Function එකට කෝල් කරනවා
    final data = await DatabaseHelper.instance.searchGlobalHistory(query);

    double balance = 0.0;
    for (var row in data) {
      double amt = (row['amount'] as num).toDouble();
      if (row['status'] != 'Paid') {
        if (row['type'] == 'Take') {
          balance += amt; // අපිට ලැබෙන්න තියෙන (+)
        } else {
          balance -= amt; // අපෙන් යන්න තියෙන (-)
        }
      }
    }

    setState(() {
      _searchResults = data;
      _finalBalance = balance;
      _isLoading = false;
    });
  }

  // 📄 PDF Report එක සාදා විවෘත කිරීම
  Future<void> _generatePDFReport() async {
    if (_searchResults.isEmpty) return;

    final pdf = pw.Document();

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
                pw.Text("UNIVERSAL WALLET - TRANSACTION REPORT",
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900)),
                pw.SizedBox(height: 5),
                pw.Text(
                    "Generated Date: ${DateTime.now().toString().split(' ').first}",
                    style: const pw.TextStyle(
                        color: PdfColors.grey700, fontSize: 11)),
                pw.Divider(thickness: 1.5, color: PdfColors.blue900),
                pw.SizedBox(height: 15),

                // Summary Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(10)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Search Keyword:",
                              style: const pw.TextStyle(
                                  fontSize: 12, color: PdfColors.grey700)),
                          pw.Text('"${_currentQuery.toUpperCase()}"',
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Net Balance for Results:",
                              style: const pw.TextStyle(
                                  fontSize: 12, color: PdfColors.grey700)),
                          pw.Text(
                            "${_finalBalance >= 0 ? '+' : ''} Rs. ${_finalBalance.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: _finalBalance >= 0
                                    ? PdfColors.green800
                                    : PdfColors.red800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 25),

                pw.Text("Matching Transaction Log History",
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),

                // Table
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.blue900),
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text("Date",
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text("Name",
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text("Type",
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text("Reason/Note",
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text("Amount",
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11))),
                      ],
                    ),
                    ..._searchResults.map((row) {
                      double amt = (row['amount'] as num).toDouble();
                      bool isTake = row['type'] == 'Take';
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(row['date'].toString(),
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(row['person_name'].toString(),
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(isTake ? "Taken" : "Given",
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(row['reason'] ?? '-',
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  "${isTake ? '+' : '-'} ${amt.toStringAsFixed(0)}",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: isTake
                                          ? PdfColors.green800
                                          : PdfColors.red800,
                                      fontSize: 10))),
                        ],
                      );
                    }),
                  ],
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Center(
                    child: pw.Text("Thank you for using Universal Wallet App",
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey500))),
              ],
            ),
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      // සර්ච් කරපු වචනය අනුව PDF නම හැදෙනවා
      final file = File("${output.path}/Report_$_currentQuery.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("PDF Generation Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text("Universal Reports",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search Input Bar (ජෙනරල් සර්ච් එකක් විදිහට වෙනස් කළා)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.manage_search,
                          color: Colors.cyanAccent),
                      hintText: "Search Name, Food, Transport...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _handleUniversalSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _handleUniversalSearch,
                  icon: const Icon(Icons.arrow_circle_right_outlined,
                      color: Colors.cyanAccent, size: 40),
                )
              ],
            ),
            const SizedBox(height: 25),

            // Results Area
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent))
                : Expanded(
                    child: _searchResults.isEmpty
                        ? const Center(
                            child: Text(
                                "Search anything (Name, Reason or Category)\nto view statements",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white24)))
                        : Column(
                            children: [
                              // Summary Card View
                              Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(15)),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Net Balance for '$_currentQuery'",
                                        style: const TextStyle(
                                            color: Colors.white70),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      "Rs. ${_finalBalance.toStringAsFixed(2)}",
                                      style: TextStyle(
                                          color: _finalBalance >= 0
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),

                              // Ledger Log List
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final row = _searchResults[index];
                                    bool isTake = row['type'] == 'Take';
                                    return Card(
                                      color: const Color(0xFF0F172A),
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isTake
                                              ? Colors.greenAccent
                                                  .withValues(alpha: 0.1)
                                              : Colors.redAccent
                                                  .withValues(alpha: 0.1),
                                          child: Icon(
                                              isTake
                                                  ? Icons.call_received
                                                  : Icons.call_made,
                                              color: isTake
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent),
                                        ),
                                        // Person name and transaction type in English
                                        title: Text(
                                            "${row['person_name']} (${isTake ? 'Borrowed' : 'Lent'})",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                        // Search reason (Food/Transport)
                                        subtitle: Text(
                                            "${row['date']} | ${row['reason'] ?? '-'}",
                                            style: const TextStyle(
                                                color: Colors.white38)),
                                        trailing: Text(
                                          "Rs. ${row['amount']}",
                                          style: TextStyle(
                                              color: isTake
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // PDF Generate Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _generatePDFReport,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyanAccent,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15))),
                                  icon: const Icon(Icons.picture_as_pdf,
                                      fontWeight: FontWeight.bold),
                                  label: const Text("Download PDF Statement",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
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
}
