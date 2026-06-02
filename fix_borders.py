import re
import os

lib_dir = "lib"

border_repl = """border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        )"""

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()

            orig = content
            
            # Replace border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none,)
            content = re.sub(
                r'border:\s*OutlineInputBorder\(\s*borderRadius:\s*BorderRadius\.circular\(15\),\s*borderSide:\s*BorderSide\.none,?\s*\)', 
                border_repl, 
                content
            )

            # Dropdown borders
            content = re.sub(
                r'decoration:\s*BoxDecoration\(\s*color:\s*Theme\.of\(context\)\.cardColor,\s*borderRadius:\s*BorderRadius\.circular\(15\),?\s*\)',
                r'decoration: BoxDecoration(\n        color: Theme.of(context).cardColor,\n        borderRadius: BorderRadius.circular(15),\n        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? Colors.black26 : Colors.transparent),\n      )',
                content
            )
            
            if content != orig:
                with open(filepath, 'w') as f:
                    f.write(content)
                print(f"Updated borders in {filepath}")
