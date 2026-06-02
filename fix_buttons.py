import re
import os

lib_dir = "lib"

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()

            orig = content
            
            # Replace backgroundColor: Colors.cyanAccent -> backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Theme.of(context).primaryColor
            content = re.sub(r'backgroundColor:\s*Colors\.cyanAccent', r'backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Theme.of(context).primaryColor', content)

            # Same for foregroundColor or text color if it was black always
            # but wait, let's just do it manually if needed.
            
            if content != orig:
                with open(filepath, 'w') as f:
                    f.write(content)
                print(f"Updated {filepath}")
