import os
import re

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart') and file != 'app_theme.dart':
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()

            orig = content

            # Remove const
            content = re.sub(r'\bconst\s+(Text|TextStyle|Icon|IconThemeData|BorderSide|BoxDecoration)\b', r'\1', content)
            
            # Replace colors
            content = content.replace('Color(0xFF1E293B)', 'Theme.of(context).cardColor')
            content = content.replace('Color(0xFF020617)', 'Theme.of(context).scaffoldBackgroundColor')
            
            content = content.replace('Colors.white38', 'AppTheme.textMuted(context)')
            content = content.replace('Colors.white54', 'AppTheme.textSecondary(context)')
            content = content.replace('Colors.white60', 'AppTheme.textSecondary(context)')
            content = content.replace('Colors.white70', 'AppTheme.textSecondary(context)')

            # Fix remaining issues in account details etc where AppTheme might not be imported
            if content != orig:
                if 'AppTheme' in content and 'import \'app_theme.dart\';' not in content and 'import \'package:my_wallet/app_theme.dart\';' not in content:
                    content = "import 'app_theme.dart';\n" + content
                with open(filepath, 'w') as f:
                    f.write(content)
