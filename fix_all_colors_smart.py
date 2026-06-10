import os
import re

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart') and file not in ['app_theme.dart', 'main.dart']:
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()

            orig = content

            # Replace explicit const colors FIRST
            content = content.replace('const Color(0xFF1E293B)', 'Theme.of(context).cardColor')
            content = content.replace('const Color(0xFF020617)', 'Theme.of(context).scaffoldBackgroundColor')
            
            # Remove const before class constructors to prevent const_eval_method_invocation
            # Matches "const Word("
            content = re.sub(r'\bconst\s+([A-Z]\w*)\(', r'\1(', content)
            # Matches "const ["
            content = re.sub(r'\bconst\s+\[', r'[', content)
            
            # Replace white colors
            content = content.replace('Colors.white38', 'AppTheme.textMuted(context)')
            content = content.replace('Colors.white54', 'AppTheme.textSecondary(context)')
            content = content.replace('Colors.white60', 'AppTheme.textSecondary(context)')
            content = content.replace('Colors.white70', 'AppTheme.textSecondary(context)')

            if content != orig:
                if 'AppTheme' in content and 'import \'app_theme.dart\';' not in content and 'import \'package:my_wallet/app_theme.dart\';' not in content:
                    content = "import 'app_theme.dart';\n" + content
                with open(filepath, 'w') as f:
                    f.write(content)
