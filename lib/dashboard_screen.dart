import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fl_chart/fl_chart.dart';
import 'database_helper.dart';
import 'add_transaction_screen.dart';
import 'debt_list_screen.dart';
import 'account_details_screen.dart';
import 'add_account_screen.dart';
import 'net_worth_details_screen.dart';
import 'reports_screen.dart';
import 'pin_helper.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const DashboardScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _accounts = [];
  double _totalNetWorth = 0.0;
  double _toCollect = 0.0;
  double _toPay = 0.0;

  String _selectedChartType = 'Expense';
  String _selectedTimePeriod = 'Weekly';
  List<FlSpot> _chartSpots =
      []; // 📊 චාර්ට් එකේ දත්ත සේව් කරන්න අලුත් ලිස්ට් එකක් හැදුවා මචං

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // 🔄 ඩේටාබේස් එකෙන් ඇත්තම දත්ත ඇදලා චාර්ට් එකයි ඩෑෂ්බෝඩ් එකයි අප්ඩේට් කිරීම
  Future<void> _refreshData() async {
    final accountData = await DatabaseHelper.instance.getAccounts();
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> collectResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM debts WHERE type = 'Give' AND status != 'Paid'",
    );
    final List<Map<String, dynamic>> payResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM debts WHERE type = 'Take' AND status != 'Paid'",
    );

    double collectSum =
        (collectResult.first['total'] as num?)?.toDouble() ?? 0.0;
    double paySum = (payResult.first['total'] as num?)?.toDouble() ?? 0.0;

    double netWorth = 0;
    for (var item in accountData) {
      netWorth += (item['balance'] as num).toDouble();
    }

    // 📊 --- Chart data preparation ---
    final List<Map<String, dynamic>> allTransactions = await db.query(
      'transactions',
    );

    final DateTime now = DateTime.now();
    // Start of current week (Monday)
    final DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));

    // Chart x-axis: 5 points (1–5)
    Map<int, double> periodValues = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0};

    for (var tx in allTransactions) {
      String txType = tx['type'].toString();
      String txDateStr = tx['date'].toString();
      double txAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

      if (_selectedChartType != 'Net Worth' && txType != _selectedChartType) {
        continue;
      }

      try {
        DateTime txDate = DateTime.parse(txDateStr);
        int spotIndex = -1;

        if (_selectedTimePeriod == 'Daily') {
          // Only include transactions from the current week (Mon–Fri)
          final bool isCurrentWeek =
              txDate.isAfter(weekStart.subtract(Duration(days: 1))) &&
              txDate.isBefore(weekStart.add(Duration(days: 7)));
          if (!isCurrentWeek) continue;
          spotIndex = txDate.weekday; // 1=Mon … 5=Fri (6,7 filtered below)
          if (spotIndex > 5) continue; // skip Sat(6) and Sun(7)
        } else if (_selectedTimePeriod == 'Monthly') {
          spotIndex = txDate.month; // 1 = Jan, 5 = May
        } else if (_selectedTimePeriod == 'Yearly') {
          spotIndex = txDate.year - 2021; // 2022 -> 1, 2026 -> 5
        } else {
          // Weekly (W1 - W5)
          spotIndex = ((txDate.day - 1) / 7).toInt() + 1;
        }

        // දත්ත එකතු කිරීම සිදු කරනවා
        if (periodValues.containsKey(spotIndex)) {
          if (_selectedChartType == 'Net Worth') {
            // Net worth එකට නම් Income එකතු කරලා Expense අඩු කරනවා
            if (txType == 'Income') {
              periodValues[spotIndex] = periodValues[spotIndex]! + txAmount;
            }
            if (txType == 'Expense') {
              periodValues[spotIndex] = periodValues[spotIndex]! - txAmount;
            }
          } else {
            periodValues[spotIndex] = periodValues[spotIndex]! + txAmount;
          }
        }
      } catch (e) {
        debugPrint("Date Parsing Error: $e");
      }
    }

    // FlSpot ලිස්ට් එකක් බවට පරිවර්තනය කිරීම
    List<FlSpot> computedSpots = [];
    if (_selectedChartType == 'Net Worth') {
      // Net worth ප්‍රස්ථාරය ඉස්සරහට ලස්සනට වැඩිවෙවී යන ප්‍රවණතාවයක් (Trend line) පෙන්වනවා
      double currentRunning =
          netWorth -
          (periodValues[1]! +
              periodValues[2]! +
              periodValues[3]! +
              periodValues[4]! +
              periodValues[5]!);
      for (int i = 1; i <= 5; i++) {
        currentRunning += periodValues[i]!;
        computedSpots.add(FlSpot(i.toDouble(), currentRunning));
      }
    } else {
      for (int i = 1; i <= 5; i++) {
        computedSpots.add(FlSpot(i.toDouble(), periodValues[i]!));
      }
    }

    setState(() {
      _accounts = accountData;
      _totalNetWorth = netWorth;
      _toCollect = collectSum;
      _toPay = paySum;
      _chartSpots =
          computedSpots; // 🎯 ඔන්න සජීවී දත්ත ටික ස්ටේට් එකට දැම්මා මචං
    });
  }

  // 🎯 චාර්ට් එකට Spots දත්ත ලබාදෙන ෆන්ක්ෂන් එක
  List<FlSpot> _getChartSpots() {
    if (_chartSpots.isEmpty) {
      return [
        FlSpot(1, 0.0),
        FlSpot(2, 0.0),
        FlSpot(3, 0.0),
        FlSpot(4, 0.0),
        FlSpot(5, 0.0),
      ];
    }
    return _chartSpots;
  }

  Color _getChartColor() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_selectedChartType == 'Income') {
      return isDark ? Colors.greenAccent : Colors.green;
    }
    if (_selectedChartType == 'Net Worth') {
      return isDark ? Colors.blueAccent : Colors.blue;
    }
    return isDark ? Colors.cyanAccent : Colors.indigoAccent;
  }

  // 🔓 Logout Confirmation Dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text(
              "Logout",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        content: Text(
          "ඔයා logout වෙන්න කැමතිද?\n\nPIN keep කරොත් next time PIN එකෙන් ඉක්මනට login වෙන්න පුළුවන්.",
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
              ),
            ),
          ),
          // Logout & Clear PIN
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performLogout(clearPin: true);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Clear PIN & Logout",
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
          // Logout (keep PIN)
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performLogout(clearPin: false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🔓 Logout Logic
  Future<void> _performLogout({required bool clearPin}) async {
    try {
      // PIN clear කරන්න ඕනේ නම්
      if (clearPin) {
        await PinHelper.clearPin();
      }

      // Firebase Sign Out
      await FirebaseAuth.instance.signOut();

      // Close local database to reset for next user
      await DatabaseHelper.instance.closeDatabase();

      // Google Sign Out (if signed in via Google)
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Google sign-in නොකළ නම් ignore කරනවා
      }

      if (!mounted) return;

      // Login Screen එකට navigate කරනවා
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            onThemeChanged: widget.onThemeChanged,
            isDarkMode: widget.isDarkMode,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Logout Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Universal Wallet",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.analytics_outlined,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.cyanAccent
                  : Colors.indigoAccent,
            ),
            tooltip: "Generate Reports",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReportsScreen()),
              );
              _refreshData();
            },
          ),
          IconButton(
            onPressed: () {
              bool isDark = Theme.of(context).brightness == Brightness.dark;
              widget.onThemeChanged(!isDark);
            },
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.orangeAccent
                  : Colors.blueGrey,
            ),
          ),
          // 🔓 Logout Button
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: "Logout",
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interactive Net Worth Card
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NetWorthDetailsScreen(totalNetWorth: _totalNetWorth),
                    ),
                  );
                  _refreshData();
                },
                child: _buildNetWorthCard(),
              ),
              SizedBox(height: 20),

              Row(
                children: [
                  _buildDebtCard(
                    "To Collect",
                    _toCollect,
                    Colors.greenAccent,
                    () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DebtListScreen(initialType: 'Give'),
                        ),
                      );
                      _refreshData();
                    },
                  ),
                  SizedBox(width: 15),
                  _buildDebtCard("To Pay", _toPay, Colors.redAccent, () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DebtListScreen(initialType: 'Take'),
                      ),
                    );
                    _refreshData();
                  }),
                ],
              ),
              SizedBox(height: 30),

              _buildAccountHeader(textColor),
              _buildAccountGrid(),
              SizedBox(height: 30),

              _buildDynamicLineChart(),
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTransactionScreen(),
            ),
          );
          _refreshData();
        },
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.cyanAccent
            : Colors.indigoAccent,
        child: Icon(
          Icons.add,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildNetWorthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF0891B2)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Net Worth",
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
              ),
              Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary(context), size: 14),
            ],
          ),
          SizedBox(height: 5),
          Text(
            "Rs. ${_totalNetWorth.toStringAsFixed(2)}",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicLineChart() {
    Color chartColor = _getChartColor();
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 25, 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? null : Border.all(color: Colors.black26, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 10),
                child: Text(
                  "Overview",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedChartType,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(
                    color: chartColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  items: ['Expense', 'Income', 'Net Worth']
                      .map(
                        (String type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedChartType = newValue);
                      _refreshData(); // 👈 ටයිප් එක මාරු කරපු ගමන් ඩේටාබේස් එකෙන් අලුත් දත්ත ගන්නවා මචං
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['Daily', 'Weekly', 'Monthly', 'Yearly'].map((period) {
              bool isSelected = _selectedTimePeriod == period;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedTimePeriod = period);
                  _refreshData(); // 👈 කාල සීමාව (Daily/Weekly) මාරු කරපු ගමන් චාර්ට් එක අප්ඩේට් කරනවා මචං
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? chartColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? chartColor : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    period,
                    style: TextStyle(
                      color: isSelected
                          ? chartColor
                          : Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 25),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return Text(
                            '0',
                            style: TextStyle(
                              color: AppTheme.textMuted(context),
                              fontSize: 10,
                            ),
                          );
                        }
                        if (value >= 1000) {
                          return Text(
                            '${(value / 1000).toStringAsFixed(0)}k',
                            style: TextStyle(
                              color: AppTheme.textMuted(context),
                              fontSize: 10,
                            ),
                          );
                        }
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: AppTheme.textMuted(context),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (_selectedTimePeriod == 'Daily') {
                          switch (idx) {
                            case 1:
                              return Text(
                                'Mon',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 2:
                              return Text(
                                'Tue',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 3:
                              return Text(
                                'Wed',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 4:
                              return Text(
                                'Thu',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 5:
                              return Text(
                                'Fri',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                          }
                        } else if (_selectedTimePeriod == 'Monthly') {
                          switch (idx) {
                            case 1:
                              return Text(
                                'Jan',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 2:
                              return Text(
                                'Feb',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 3:
                              return Text(
                                'Mar',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 4:
                              return Text(
                                'Apr',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 5:
                              return Text(
                                'May',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                          }
                        } else if (_selectedTimePeriod == 'Yearly') {
                          switch (idx) {
                            case 1:
                              return Text(
                                '2022',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 2:
                              return Text(
                                '2023',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 3:
                              return Text(
                                '2024',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 4:
                              return Text(
                                '2025',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 5:
                              return Text(
                                '2026',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                          }
                        } else {
                          switch (idx) {
                            case 1:
                              return Text(
                                'W1',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 2:
                              return Text(
                                'W2',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 3:
                              return Text(
                                'W3',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 4:
                              return Text(
                                'W4',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                            case 5:
                              return Text(
                                'W5',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 10,
                                ),
                              );
                          }
                        }
                        return Text('');
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getChartSpots(),
                    isCurved: true,
                    color: chartColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          chartColor.withValues(alpha: 0.2),
                          chartColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(
    String title,
    double amount,
    Color amountColor,
    VoidCallback onTap,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: isDark ? null : Border.all(color: Colors.black26, width: 1),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? AppTheme.textSecondary(context) : Colors.black54,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "Rs. ${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  color: amountColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountHeader(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "My Accounts",
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddAccountScreen()),
            );
            _refreshData();
          },
          icon: Icon(
            Icons.add_circle_outline,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.cyanAccent
                : Colors.indigoAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _accounts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) {
        final acc = _accounts[index];
        return InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AccountDetailsScreen(
                  accountId: acc['id'],
                  accountName: acc['name'],
                ),
              ),
            );
            _refreshData();
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Theme.of(context).brightness == Brightness.dark
                  ? null
                  : Border.all(color: Colors.black26, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  acc['type'] == 'Cash' ? Icons.wallet : Icons.account_balance,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.cyanAccent
                      : Colors.indigoAccent,
                ),
                SizedBox(height: 8),
                Text(
                  acc['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "Rs. ${(acc['balance'] as num).toDouble().toStringAsFixed(2)}",
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.textSecondary(context)
                        : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
