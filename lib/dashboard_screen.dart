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
  String _selectedTimePeriod = 'Daily';
  List<FlSpot> _chartSpots = [];
  List<String> _chartLabels = [];

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
    final List<Map<String, dynamic>> allTransactions = await db.query('transactions');
    final DateTime now = DateTime.now();

    List<String> labels = [];
    Map<int, double> periodValues = {0: 0.0, 1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0};
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 0; i < 6; i++) {
      if (_selectedTimePeriod == 'Daily') {
        DateTime d = now.subtract(Duration(days: 5 - i));
        labels.add(dayNames[d.weekday - 1]);
      } else if (_selectedTimePeriod == 'Weekly') {
        labels.add('W${6 - i}');
      } else if (_selectedTimePeriod == 'Monthly') {
        int m = now.month - (5 - i);
        while (m <= 0) {
          m += 12;
        }
        labels.add(monthNames[m - 1]);
      } else if (_selectedTimePeriod == 'Yearly') {
        labels.add('${now.year - (5 - i)}');
      }
    }

    for (var tx in allTransactions) {
      String txType = tx['type'].toString();
      String txDateStr = tx['date'].toString();
      double txAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

      if (_selectedChartType != 'Net Worth' && txType != _selectedChartType) continue;

      try {
        DateTime txDate = DateTime.parse(txDateStr);
        int spotIndex = -1;
        
        if (_selectedTimePeriod == 'Daily') {
          int diff = now.difference(DateTime(txDate.year, txDate.month, txDate.day)).inDays;
          if (diff >= 0 && diff <= 5) spotIndex = 5 - diff;
        } else if (_selectedTimePeriod == 'Weekly') {
          int diff = now.difference(txDate).inDays;
          if (diff >= 0 && diff < 42) spotIndex = 5 - (diff ~/ 7);
        } else if (_selectedTimePeriod == 'Monthly') {
          int diffMonths = (now.year - txDate.year) * 12 + now.month - txDate.month;
          if (diffMonths >= 0 && diffMonths <= 5) spotIndex = 5 - diffMonths;
        } else if (_selectedTimePeriod == 'Yearly') {
          int diffYears = now.year - txDate.year;
          if (diffYears >= 0 && diffYears <= 5) spotIndex = 5 - diffYears;
        }

        if (periodValues.containsKey(spotIndex)) {
          if (_selectedChartType == 'Net Worth') {
            if (txType == 'Income') periodValues[spotIndex] = periodValues[spotIndex]! + txAmount;
            if (txType == 'Expense') periodValues[spotIndex] = periodValues[spotIndex]! - txAmount;
          } else {
            periodValues[spotIndex] = periodValues[spotIndex]! + txAmount;
          }
        }
      } catch (e) {
        debugPrint("Date Parsing Error: $e");
      }
    }

    List<FlSpot> computedSpots = [];
    if (_selectedChartType == 'Net Worth') {
      double currentRunning = netWorth;
      for (int i = 5; i >= 0; i--) {
        currentRunning -= periodValues[i]!;
      }
      double running = currentRunning;
      for (int i = 0; i < 6; i++) {
        running += periodValues[i]!;
        computedSpots.add(FlSpot(i.toDouble(), running));
      }
    } else {
      for (int i = 0; i < 6; i++) {
        computedSpots.add(FlSpot(i.toDouble(), periodValues[i]!));
      }
    }

    setState(() {
      _accounts = accountData;
      _totalNetWorth = netWorth;
      _toCollect = collectSum;
      _toPay = paySum;
      _chartSpots = computedSpots;
      _chartLabels = labels;
    });
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
    
    // Find min and max y to create good bounds for the chart
    double minY = 0;
    double maxY = 100;
    if (_chartSpots.isNotEmpty) {
      minY = _chartSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      maxY = _chartSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      
      // Ensure there's a margin so points don't clip at the borders
      if (minY == maxY) {
        maxY += 100;
        if (minY > 0) minY -= 10;
      } else {
        double padding = (maxY - minY) * 0.2;
        maxY += padding;
        minY -= padding;
      }
    }
    
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 20, 20, 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white10, width: 1) : Border.all(color: Colors.black12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ]
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                height: 32,
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: chartColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedChartType,
                    dropdownColor: Theme.of(context).cardColor,
                    icon: Icon(Icons.arrow_drop_down, color: chartColor, size: 20),
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
                        _refreshData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Daily', 'Weekly', 'Monthly', 'Yearly'].map((period) {
                bool isSelected = _selectedTimePeriod == period;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTimePeriod = period);
                      _refreshData();
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).cardColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ] : [],
                      ),
                      child: Center(
                        child: Text(
                          period,
                          style: TextStyle(
                            color: isSelected
                                ? chartColor
                                : Theme.of(context).textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 30),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4 == 0 ? 1 : (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value == minY || value == maxY) return const SizedBox.shrink();
                        
                        String text = '';
                        if (value.abs() >= 1000000) {
                          text = '${(value / 1000000).toStringAsFixed(1)}M';
                        } else if (value.abs() >= 1000) {
                          text = '${(value / 1000).toStringAsFixed(1)}k';
                        } else {
                          text = value.toInt().toString();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: AppTheme.textMuted(context),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
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
                        if (idx >= 0 && idx < _chartLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _chartLabels[idx],
                              style: TextStyle(
                                color: AppTheme.textSecondary(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartSpots.isEmpty ? [FlSpot(0,0), FlSpot(1,0), FlSpot(2,0), FlSpot(3,0), FlSpot(4,0), FlSpot(5,0)] : _chartSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: chartColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Theme.of(context).cardColor,
                          strokeWidth: 3,
                          strokeColor: chartColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          chartColor.withValues(alpha: 0.25),
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
