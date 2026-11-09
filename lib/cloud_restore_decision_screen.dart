import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class CloudRestoreDecisionScreen extends StatelessWidget {
  final User user;
  final Map<String, dynamic> cloudSummary;
  final VoidCallback onKeep;
  final VoidCallback onErase;
  final bool isDarkMode;

  const CloudRestoreDecisionScreen({
    super.key,
    required this.user,
    required this.cloudSummary,
    required this.onKeep,
    required this.onErase,
    required this.isDarkMode,
  });

  void _confirmErase(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              "Erase All Records?",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to permanently delete all cloud and local records for ${user.email}? This action CANNOT be undone.",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "ඔබගේ සියලුම පරණ ගනුදෙනු, ණය සහ ගිණුම් විස්තර ස්ථිරවම මකා දමා අලුතින්ම ආරම්භ කෙරේ.",
              style: TextStyle(
                color: AppTheme.textMuted(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "Cancel",
              style: TextStyle(color: AppTheme.textMuted(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onErase();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Yes, Erase Everything",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txCount = cloudSummary['transactions'] ?? 0;
    final debtCount = cloudSummary['debts'] ?? 0;
    final accCount = cloudSummary['accounts'] ?? 0;

    final primaryAccent =
        isDarkMode ? Colors.cyanAccent : const Color(0xFF00ADB5);
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_sync_rounded,
                    size: 64,
                    color: primaryAccent,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  "Previous Records Found",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  "We found previous financial records linked to your Google account in Cloud Storage.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "මෙම ගිණුමට අදාළව පරණ දත්ත හමු විය. ඔබට ඒවා තබාගැනීමට අවශ්‍යද, නැතහොත් සියල්ල මකා අලුතින්ම ආරම්භ කිරීමට අවශ්‍යද?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textMuted(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),

                // Records Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black12,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            size: 18,
                            color: primaryAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user.email ?? "Google Account",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black12,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context,
                            "$txCount",
                            "Transactions",
                            Icons.receipt_long_outlined,
                          ),
                          _buildStatItem(
                            context,
                            "$debtCount",
                            "Debts/Loans",
                            Icons.handshake_outlined,
                          ),
                          _buildStatItem(
                            context,
                            "$accCount",
                            "Accounts",
                            Icons.account_balance_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Option 1: Keep Records (Primary Action)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: onKeep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryAccent,
                      foregroundColor: isDarkMode ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: const Text(
                      "Keep Records (පරණ දත්ත තබාගන්න)",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Option 2: Erase & Start Fresh (Destructive Action)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmErase(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text(
                      "Erase & Start Fresh (මකා අලුතින් පටන්ගන්න)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String count,
    String label,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary(context)),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMuted(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
