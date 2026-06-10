import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatelessWidget {
  final Function(bool)? onThemeChanged;
  final bool? isDarkMode;

  const OnboardingScreen({super.key, this.onThemeChanged, this.isDarkMode});

  // 🔒 ටියුටෝරියල් එක බලලා ඉවර වුණාම ආයේ නොපෙන්වන්න සේව් කරන ෆන්ක්ෂන් එක
  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTimeUser', false);

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            onThemeChanged: onThemeChanged ?? (bool isDark) {},
            isDarkMode: isDarkMode ?? true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.cyanAccent : Color(0xFF00ADB5);
    final textColor = isDark ? Colors.white : Color(0xFF0F172A);

    // 🎨 Slides වල අකුරු සහ මෝස්තර සෙටප් එක
    final pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      bodyTextStyle: TextStyle(
        fontSize: 16.0,
        color: isDark ? AppTheme.textSecondary(context) : Colors.black54,
        height: 1.5,
      ),
      imagePadding: const EdgeInsets.only(top: 40.0),
      pageColor: Theme.of(context).scaffoldBackgroundColor,
    );

    return IntroductionScreen(
      pages: [
        // 📜 පළමු ස්ලයිඩය - සාදරයෙන් පිළිගැනීම
        PageViewModel(
          title: "Welcome to Universal Wallet",
          body:
              "Your smart companion to manage all your personal debts and lendings in one secure place.",
          image: Center(
            child: Icon(Icons.wallet_rounded, size: 100, color: accentColor),
          ),
          decoration: pageDecoration,
        ),

        // 📜 දෙවන ස්ලයිඩය - ගනුදෙනු ඇතුළත් කිරීම
        PageViewModel(
          title: "Easy Tracking",
          body:
              "Quickly record whenever you give money to a friend or take from someone. Never forget a single rupee!",
          image: Center(
            child: Icon(
              Icons.swap_horizontal_circle_rounded,
              size: 100,
              color: accentColor,
            ),
          ),
          decoration: pageDecoration,
        ),

        // 📜 තෙවන ස්ලයිඩය - රිපෝට්ස් සහ PDF
        PageViewModel(
          title: "Instant PDF Reports",
          body:
              "Generate clear statement summaries filtered by date or friend name, and download them instantly as PDFs.",
          image: Center(
            child: Icon(
              Icons.picture_as_pdf_rounded,
              size: 100,
              color: accentColor,
            ),
          ),
          decoration: pageDecoration,
        ),
      ],

      // 🔘 බටන්ස් සහ ඉන්ඩිකේටර්ස් වල මෝස්තර
      onDone: () => _completeOnboarding(context),
      onSkip: () => _completeOnboarding(context),
      showSkipButton: true,
      skip: Text(
        "Skip",
        style: TextStyle(fontWeight: FontWeight.w600, color: accentColor),
      ),
      next: Icon(Icons.arrow_forward, color: accentColor),
      done: Text(
        "Get Started",
        style: TextStyle(fontWeight: FontWeight.bold, color: accentColor),
      ),

      // 📍 යටින් පෙනෙන තිත් කෑලි (Dots Indicator) සෙටප් එක
      dotsDecorator: DotsDecorator(
        size: Size(10.0, 10.0),
        color: isDark ? Colors.white24 : Colors.black12,
        activeColor: accentColor,
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }
}
