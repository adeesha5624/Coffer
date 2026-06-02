import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'pin_screen.dart';
import 'pin_helper.dart';

void main() async {
  // 💡 Flutter Engine එක සහ Firebase මුලින්ම සක්‍රිය (Initialize) කිරීම
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // google_sign_in v7 requires explicit initialization
  await GoogleSignIn.instance.initialize(
    clientId:
        '4685339162-4mgf6f1oj2ukvanapee2o9f62fst8p1u.apps.googleusercontent.com',
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 🎯 ඇප් එක මුලින්ම Dark Mode එකෙන් ස්ටාර්ට් වෙන්න සෙට් කලා මචං
  bool _isDarkMode = true;

  // ⚡ ඩෑෂ්බෝඩ් එකෙන් බටන් එක ඔබද්දී තීම් එක මාරු කරන ෆන්ක්ෂන් එක
  void _updateTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal Wallet',
      debugShowCheckedModeBanner: false,

      // ⚪ Light Theme සැකසුම් (Beautiful Modern Light Mode)
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF2563EB), // Vibrant Blue
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)), // Slate 900
          titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF1E293B)), // Slate 800
          bodyMedium: TextStyle(color: Color(0xFF334155)), // Slate 700
          titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2563EB)),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF0891B2), // Cyan 600
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
          background: Color(0xFFF8FAFC),
          onBackground: Color(0xFF0F172A),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),

      // ⚫ Dark Theme සැකසුම් (ඔයාගේ UI එකේ තියෙන පට්ටම ලස්සන ඩාර්ක් කලර්ස් ටික)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        cardColor: const Color(0xFF1E293B),
      ),

      // දැනට ඇප් එකේ තියෙන තීම් ස්ටේට් එක (Dark/Light) තෝරාගැනීම
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // 🔐 --- සජීවී CLOUD LOGIN STATE CHECKER ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Firebase එකෙන් ලොගින් විස්තර චෙක් කරනකම් ලෝඩින් එකක් පෙන්වනවා
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: _isDarkMode ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
              body: Center(
                child: CircularProgressIndicator(color: _isDarkMode ? Colors.cyanAccent : Colors.blue),
              ),
            );
          }

          // 💡 යූසර් දැනටමත් ලොග් වෙලා ඉන්නවා නම්
          if (snapshot.hasData) {
            // PIN check කරනවා — PIN තියෙනවා නම් PIN screen, නැත්නම් PIN setup
            return _PinCheckWrapper(
              onThemeChanged: _updateTheme,
              isDarkMode: _isDarkMode,
            );
          }

          // 🆕 යූසර් ලොග් වෙලා නැත්නම් මුලින්ම පෙන්වන්නේ අපේ අලුත් Login Screen එකයි
          return LoginScreen(
            onThemeChanged: _updateTheme,
            isDarkMode: _isDarkMode,
          );
        },
      ),
    );
  }
}

/// 🔐 PIN check wrapper — logged-in user ගේ PIN status check කරලා
/// correct screen එකට navigate කරනවා
class _PinCheckWrapper extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const _PinCheckWrapper({
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<_PinCheckWrapper> createState() => _PinCheckWrapperState();
}

class _PinCheckWrapperState extends State<_PinCheckWrapper> {
  bool _isLoading = true;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _checkPin();
  }

  Future<void> _checkPin() async {
    final hasPin = await PinHelper.hasPin();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _isLoading = false;
      });
    }
  }

  void _handleForgotPin() async {
    // PIN clear කරලා Firebase sign out කරනවා — Login Screen එකට යනවා
    await PinHelper.clearPin();
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: widget.isDarkMode ? Colors.cyanAccent : Colors.blue),
        ),
      );
    }

    if (_hasPin) {
      // PIN තියෙනවා → PIN Login Screen පෙන්වනවා
      return PinScreen(
        mode: PinMode.login,
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
        onForgotPin: _handleForgotPin,
      );
    } else {
      // PIN නැ → PIN Setup Screen පෙන්වනවා
      return PinScreen(
        mode: PinMode.setup,
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
      );
    }
  }
}
