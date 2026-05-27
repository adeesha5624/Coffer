import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

void main() async {
  // 💡 Flutter Engine එක සහ Firebase මුලින්ම සක්‍රිය (Initialize) කිරීම
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // google_sign_in v7 requires explicit initialization
  await GoogleSignIn.instance.initialize();
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

      // ⚪ Light Theme සැකසුම්
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
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
            return const Scaffold(
              backgroundColor: Color(0xFF020617),
              body: Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            );
          }

          // 💡 යූසර් දැනටමත් ලොග් වෙලා ඉන්නවා නම් කෙළින්ම Dashboard එකට යනවා
          if (snapshot.hasData) {
            return DashboardScreen(
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
