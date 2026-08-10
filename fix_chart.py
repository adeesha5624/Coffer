import re

def main():
    with open('lib/dashboard_screen.dart', 'r') as f:
        content = f.read()

    # 1. Add _chartLabels to state
    old_state_def = """  String _selectedChartType = 'Expense';
  String _selectedTimePeriod = 'Weekly';
  List<FlSpot> _chartSpots =
      []; // 📊 චාර්ට් එකේ දත්ත සේව් කරන්න අලුත් ලිස්ට් එකක් හැදුවා මචං"""
    new_state_def = """  String _selectedChartType = 'Expense';
  String _selectedTimePeriod = 'Daily';
  List<FlSpot> _chartSpots = [];
  List<String> _chartLabels = [];"""
    if old_state_def in content:
        content = content.replace(old_state_def, new_state_def)
    else:
        print("Error: Could not find state definition")

    # 2. Replace _refreshData chart preparation
    # Find the start of the comment and the end of the if block
    start_str = "    // 📊 --- Chart data preparation ---"
    end_str = """    } else {
      for (int i = 1; i <= 5; i++) {
        computedSpots.add(FlSpot(i.toDouble(), periodValues[i]!));
      }
    }"""
    
    start_idx = content.find(start_str)
    end_idx = content.find(end_str) + len(end_str)
    
    if start_idx != -1 and end_idx != -1 + len(end_str):
        chart_prep_new = """    // 📊 --- Chart data preparation ---
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
        int y = now.year;
        while (m <= 0) {
          m += 12;
          y -= 1;
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
    }"""
        content = content[:start_idx] + chart_prep_new + content[end_idx:]
    else:
        print("Error: Could not find chart preparation section")

    # 3. Update setState
    old_state = """    setState(() {
      _accounts = accountData;
      _totalNetWorth = netWorth;
      _toCollect = collectSum;
      _toPay = paySum;
      _chartSpots =
          computedSpots; // 🎯 ඔන්න සජීවී දත්ත ටික ස්ටේට් එකට දැම්මා මචං
    });"""
    new_state = """    setState(() {
      _accounts = accountData;
      _totalNetWorth = netWorth;
      _toCollect = collectSum;
      _toPay = paySum;
      _chartSpots = computedSpots;
      _chartLabels = labels;
    });"""
    if old_state in content:
        content = content.replace(old_state, new_state)
    else:
        print("Error: Could not find setState block")

    # 4. Replace _buildDynamicLineChart entirely
    start_chart = "  Widget _buildDynamicLineChart() {"
    end_chart = """            ),
          ),
        ],
      ),
    );
  }"""
    
    start_c_idx = content.find(start_chart)
    end_c_idx = content.find(end_chart, start_c_idx) + len(end_chart)
    
    if start_c_idx != -1 and end_c_idx != -1 + len(end_chart):
        new_chart = """  Widget _buildDynamicLineChart() {
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
  }"""
        content = content[:start_c_idx] + new_chart + content[end_c_idx:]
    else:
        print("Error: Could not find chart builder")

    with open('lib/dashboard_screen.dart', 'w') as f:
        f.write(content)
        
    print("Chart logic updated successfully!")

if __name__ == '__main__':
    main()
