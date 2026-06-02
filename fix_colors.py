import os
import re

lib_dir = "lib"

# Patterns to replace
replacements = {
    "Colors.cyanAccent": "AppTheme.primaryAccent(context)",
    "Color(0xFF020617)": "AppTheme.background(context)",
    "Color(0xFF1E293B)": "AppTheme.cardColor(context)",
    "Colors.white70": "AppTheme.textSecondary(context)",
    "Colors.white60": "AppTheme.textSecondary(context)",
    "Colors.white54": "AppTheme.textSecondary(context)",
    "Colors.white38": "AppTheme.textMuted(context)",
    "Colors.white24": "AppTheme.textMuted(context)",
    "Colors.white10": "AppTheme.border(context)",
    "Colors.black54": "AppTheme.textSecondary(context)",
    "Colors.black87": "AppTheme.textColor(context)",
}

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart") and file != "app_theme.dart":
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()

            original_content = content
            
            # Special case for ThemeData.dark().copyWith(...) -> Theme.of(context).copyWith(...)
            content = content.replace("ThemeData.dark().copyWith", "Theme.of(context).copyWith")

            # Remove const before replaced items
            # E.g. const TextStyle(color: Colors.white70) -> TextStyle(color: AppTheme.textSecondary(context))
            # We'll iteratively remove const where there's an AppTheme usage inside its arguments.
            
            # Simple approach: just do the replacement. If it breaks const, we fix it using flutter analyze.
            
            for old, new_val in replacements.items():
                content = content.replace(old, new_val)
                
            # Replace Colors.white safely (since sometimes it's used where it shouldn't be dynamic, but mostly it's for text/icons)
            # We'll use regex to only replace Colors.white when it's assigned to `color: ` or inside a List of colors
            content = re.sub(r'color:\s*Colors\.white([^a-zA-Z0-9_]|$)', r'color: AppTheme.textColor(context)\1', content)
            
            # For icon theme color: const IconThemeData(color: Colors.white)
            content = re.sub(r'const\s+IconThemeData\(color:\s*AppTheme\.textColor\(context\)\)', r'IconThemeData(color: AppTheme.textColor(context))', content)
            
            # Remove const before AppTheme.
            content = re.sub(r'const\s+([A-Za-z0-9_]+)\([^)]*AppTheme\.[^)]*\)', r'\1( /* removed const */ ', content)
            # A more robust regex to remove const from widget instantiations that now contain AppTheme
            # Actually, doing it blindly is risky. Let's do it manually if flutter analyze complains.
            
            if content != original_content:
                # add import if not present
                if "import 'app_theme.dart';" not in content and "import 'package:my_wallet/app_theme.dart';" not in content:
                    content = "import 'app_theme.dart';\n" + content
                
                with open(filepath, 'w') as f:
                    f.write(content)
                print(f"Updated {filepath}")
