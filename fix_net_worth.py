import re

file_path = "lib/net_worth_details_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

orig = content

# 1. AppBar
content = re.sub(r'title:\s*const\s*Text\("Net Worth Analytics",\s*style:\s*TextStyle\(color:\s*Colors\.white,\s*fontWeight:\s*FontWeight\.bold\)\)', r'title: const Text("Net Worth Analytics", style: TextStyle(fontWeight: FontWeight.bold))', content)
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

# 5. Fix gradient colors that use dark hex values blindly
# colors: [Color(0xFF1E293B), Color(0xFF0F172A)] -> use cardColor and scaffoldBackgroundColor
# But let's leave the gradient alone if we don't need to change it, or just make it adapting
content = re.sub(r'colors:\s*\[const\s*Color\(0xFF1E293B\),\s*const\s*Color\(0xFF0F172A\)\]', r'colors: [Theme.of(context).cardColor, Theme.of(context).scaffoldBackgroundColor]', content)
content = re.sub(r'colors:\s*\[Color\(0xFF1E293B\),\s*Color\(0xFF0F172A\)\]', r'colors: [Theme.of(context).cardColor, Theme.of(context).scaffoldBackgroundColor]', content)

# 6. Colors.cyanAccent for primary
content = re.sub(r'color:\s*Colors\.cyanAccent', r'color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigoAccent', content)
# cyanAccent.withValues(alpha: 0.2)
content = re.sub(r'Colors\.cyanAccent\.withValues\(alpha:\s*0\.2\)', r'(Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.indigoAccent.withValues(alpha: 0.2))', content)

# Check and remove const from ActionChip/ChoiceChip labels/avatars where needed
# This might be tricky, let's write to file and check with flutter analyze
if content != orig:
    with open(file_path, "w") as f:
        f.write(content)
    print("Updated net_worth_details_screen.dart")

