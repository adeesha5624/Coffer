import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'pin_screen.dart';
import 'pin_helper.dart';
import 'sync_helper.dart';
import 'cloud_restore_decision_screen.dart';

void main() async {
  // Initialize Flutter engine and Firebase
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
  /// Controls the application-wide theme mode (defaults to Dark Mode).
  bool _isDarkMode = true;

  /// Updates the application theme mode between light and dark.
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

      // Light Theme Configuration
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00ADB5),
          brightness: Brightness.light,
          primary: const Color(0xFF00ADB5),
          surface: const Color(0xFFF1F5F9),
          onSurface: const Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Dark Theme Configuration
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        cardColor: const Color(0xFF1E293B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00ADB5),
          brightness: Brightness.dark,
          primary: const Color(0xFF00ADB5),
          surface: const Color(0xFF1E293B),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // Authentication State Stream Listener
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: _isDarkMode
                  ? const Color(0xFF020617)
                  : const Color(0xFFF8FAFC),
              body: Center(
                child: CircularProgressIndicator(
                  color: _isDarkMode ? Colors.cyanAccent : Colors.blue,
                ),
              ),
            );
          }

          // Route to AuthSessionHandler when authenticated
          if (snapshot.hasData) {
            return _AuthSessionHandler(
              user: snapshot.data!,
              onThemeChanged: _updateTheme,
              isDarkMode: _isDarkMode,
            );
          }

          // Route to LoginScreen when unauthenticated
          return LoginScreen(
            onThemeChanged: _updateTheme,
            isDarkMode: _isDarkMode,
          );
        },
      ),
    );
  }
}

/// Handles multi-device cloud synchronization decisions and PIN authentication routing.
class _AuthSessionHandler extends StatefulWidget {
  final User user;
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const _AuthSessionHandler({
    required this.user,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<_AuthSessionHandler> createState() => _AuthSessionHandlerState();
}

class _AuthSessionHandlerState extends State<_AuthSessionHandler> {
  bool _isLoading = true;
  String _loadingMessage = "Checking account status...";
  bool _showDecision = false;
  Map<String, dynamic> _cloudSummary = {};
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final uid = widget.user.uid;
    final isSynced = await SyncHelper.isSessionSynced(uid);

    if (isSynced) {
      await _checkLocalPin();
      return;
    }

    if (mounted) {
      setState(() => _loadingMessage = "Checking cloud records...");
    }

    final hasCloud = await SyncHelper.hasCloudData(uid);

    if (hasCloud) {
      final summary = await SyncHelper.getCloudSummary(uid);
      if (mounted) {
        setState(() {
          _cloudSummary = summary;
          _showDecision = true;
          _isLoading = false;
        });
      }
    } else {
      // Initial account setup: sync initial state to cloud
      await SyncHelper.markSessionSynced(uid);
      await SyncHelper.syncAllToCloud();
      await _checkLocalPin();
    }
  }

  Future<void> _checkLocalPin() async {
    final hasPin = await PinHelper.hasPin();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _isLoading = false;
        _showDecision = false;
      });
    }
  }

  Future<void> _handleKeep() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Restoring previous records from cloud...";
    });

    await SyncHelper.restoreFromCloud(widget.user.uid);
    await _checkLocalPin();
  }

  Future<void> _handleErase() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Erasing records & starting fresh...";
    });

    await SyncHelper.eraseCloudAndLocal(widget.user.uid);
    await _checkLocalPin();
  }

  void _handleForgotPin() async {
    await PinHelper.clearPin();
    await SyncHelper.clearSessionSynced();
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF020617)
            : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: widget.isDarkMode
                    ? Colors.cyanAccent
                    : const Color(0xFF00ADB5),
              ),
              const SizedBox(height: 16),
              Text(
                _loadingMessage,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_showDecision) {
      return CloudRestoreDecisionScreen(
        user: widget.user,
        cloudSummary: _cloudSummary,
        onKeep: _handleKeep,
        onErase: _handleErase,
        isDarkMode: widget.isDarkMode,
      );
    }

    if (_hasPin) {
      return PinScreen(
        mode: PinMode.login,
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
        onForgotPin: _handleForgotPin,
      );
    } else {
      return PinScreen(
        mode: PinMode.setup,
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
      );
    }
  }
}
