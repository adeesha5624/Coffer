import 'package:flutter/material.dart';

class AppTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryAccent(BuildContext context) =>
      isDark(context) ? Colors.cyanAccent : Colors.blueAccent;

  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF020617) : const Color(0xFFF8FAFC);

  static Color cardColor(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E293B) : Colors.white;

  static Color textColor(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black87;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? Colors.white70 : Colors.black54;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? Colors.white38 : Colors.black38;

  static Color border(BuildContext context) =>
      isDark(context) ? Colors.white10 : Colors.black12;

  static Color success(BuildContext context) =>
      isDark(context) ? Colors.greenAccent : Colors.green;

  static Color error(BuildContext context) =>
      isDark(context) ? Colors.redAccent : Colors.red;

  static Color inputFill(BuildContext context) =>
      isDark(context) ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);

  static Color chartGrid(BuildContext context) =>
      isDark(context) ? Colors.white10 : Colors.black12;
}
