import re

file_path = "lib/add_debt_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

orig = content

# 1. AppBar
content = re.sub(r'title:\s*const\s*Text\(\s*"Add Debt/Loan",\s*style:\s*TextStyle\(color:\s*Colors\.white\),\s*\)', r'title: const Text("Add Debt/Loan")', content)
content = re.sub(r'iconTheme:\s*const\s*IconThemeData\(color:\s*Colors\.white\),', r'', content)

# 2. Hardcoded white text colors
content = re.sub(r'color:\s*Colors\.white70', r'color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)', content)
content = re.sub(r'color:\s*Colors\.white60', r'color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6)', content)
content = re.sub(r'color:\s*Colors\.white54', r'color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)', content)
content = re.sub(r'color:\s*Colors\.white38', r'color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.38)', content)
content = re.sub(r'color:\s*Colors\.white24', r'color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.24)', content)
content = re.sub(r'color:\s*Colors\.white10', r'color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.1)', content)

# 3. Colors.white when it's just regular text
content = re.sub(r'color:\s*Colors\.white([,)])', r'color: Theme.of(context).textTheme.bodyLarge?.color\1', content)

# 4. Remove 'const' before Text/Icon/TextStyle/BorderSide if they use Theme.of
content = re.sub(r'const\s+(Text\([^)]*Theme\.of)', r'\1', content)
content = re.sub(r'const\s+(TextStyle\([^)]*Theme\.of)', r'\1', content)
content = re.sub(r'const\s+(Icon\([^)]*Theme\.of)', r'\1', content)
content = re.sub(r'const\s+(BorderSide\([^)]*Theme\.of)', r'\1', content)


if content != orig:
    with open(file_path, "w") as f:
        f.write(content)
    print("Updated add_debt_screen.dart")

