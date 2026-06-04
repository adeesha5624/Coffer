import re

# Fix dashboard_screen.dart
path = 'lib/dashboard_screen.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace(
    'title: const Text(\n          "My Universal Wallet",\n          style: TextStyle(fontWeight: FontWeight.bold),\n        ),',
    'title: Text(\n          "My Universal Wallet",\n          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),\n        ),'
)

with open(path, 'w') as f:
    f.write(content)


# Fix reports_screen.dart
path2 = 'lib/reports_screen.dart'
with open(path2, 'r') as f:
    content2 = f.read()

content2 = content2.replace(
    'backgroundColor: Colors.transparent,\n        elevation: 0,\n        // 🎯 2. Back Arrow එකත් ලයිට් මෝඩ් එකේදී කළු පාට වෙනවා\n        iconTheme: IconThemeData(color: primaryTextColor),',
    'backgroundColor: Colors.transparent,\n        elevation: 0,\n        foregroundColor: primaryTextColor,\n        // 🎯 2. Back Arrow එකත් ලයිට් මෝඩ් එකේදී කළු පාට වෙනවා\n        iconTheme: IconThemeData(color: primaryTextColor),'
)

# Also ensure "Universal Reports" title uses it properly, which it already does via TextStyle, but foregroundColor handles the back button more robustly.

with open(path2, 'w') as f:
    f.write(content2)

print("AppBars updated")
