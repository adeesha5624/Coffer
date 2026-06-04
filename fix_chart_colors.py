import re
import os

path = 'lib/dashboard_screen.dart'
with open(path, 'r') as f:
    content = f.read()

# Replace Colors.white38 and Colors.white54 in the line chart with a dynamic color.
# The line chart is built inside _buildDynamicLineChart where `isDark` is defined.

# Find the start of _buildDynamicLineChart
start_idx = content.find('Widget _buildDynamicLineChart() {')
if start_idx != -1:
    end_idx = content.find('Widget _buildFinancialGoals() {', start_idx)
    if end_idx == -1:
        end_idx = len(content)

    chart_content = content[start_idx:end_idx]

    # Remove const from const TextStyle where it will be dynamic
    chart_content = re.sub(r'const\s+(TextStyle\(\s*color:\s*Colors\.white(?:38|54))', r'\1', chart_content)

    # Replace Colors.white38 and Colors.white54
    chart_content = chart_content.replace('Colors.white38', 'isDark ? Colors.white38 : Colors.black38')
    chart_content = chart_content.replace('Colors.white54', 'isDark ? Colors.white54 : Colors.black54')

    new_content = content[:start_idx] + chart_content + content[end_idx:]
    with open(path, 'w') as f:
        f.write(new_content)
    print("Fixed dashboard_screen.dart")
else:
    print("Could not find _buildDynamicLineChart")

path2 = 'lib/reports_screen.dart'
with open(path2, 'r') as f:
    content2 = f.read()

# Let's search for "Universal Reports" in reports_screen.dart
start_idx = content2.find('Universal Reports')
print(content2[start_idx-200:start_idx+200])

