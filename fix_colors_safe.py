import os
import re

lib_dir = "lib"

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()

            orig = content
            
            content = re.sub(r'dropdownColor:\s*const\s+Color\(0xFF1E293B\)', r'dropdownColor: Theme.of(context).cardColor', content)
            content = re.sub(r'fillColor:\s*const\s+Color\(0xFF1E293B\)', r'fillColor: Theme.of(context).cardColor', content)
            content = re.sub(r'backgroundColor:\s*const\s+Color\(0xFF1E293B\)', r'backgroundColor: Theme.of(context).cardColor', content)
            content = re.sub(r'backgroundColor:\s*const\s+Color\(0xFF020617\)', r'backgroundColor: Theme.of(context).scaffoldBackgroundColor', content)

            if content != orig:
                with open(filepath, 'w') as f:
                    f.write(content)
                print(f"Updated {filepath}")
