import re
import os

filepath = "lib/add_transaction_screen.dart"
border_repl = """border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        )"""

with open(filepath, 'r') as f:
    content = f.read()

orig = content

content = re.sub(
    r'border:\s*OutlineInputBorder\(\s*borderRadius:\s*BorderRadius\.circular\(16\),\s*borderSide:\s*BorderSide\.none\)', 
    border_repl, 
    content
)

if content != orig:
    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Updated borders in {filepath}")
