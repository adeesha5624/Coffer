import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'pin_screen.dart';
import 'pin_helper.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const LoginScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  // ✅ Login success වුණාට පස්සේ PIN check කරලා navigate කරනවා
  Future<void> _onLoginSuccess() async {
    if (!mounted) return;

    final hasPin = await PinHelper.hasPin();

    if (!mounted) return;

    if (hasPin) {
      // PIN දැනටමත් set කරලා තියෙනවා → Dashboard එකට යනවා
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            onThemeChanged: widget.onThemeChanged,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    } else {
      // PIN නැ → PIN Setup Screen එකට යනවා
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PinScreen(
            mode: PinMode.setup,
            onThemeChanged: widget.onThemeChanged,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    }
  }

  // ✅ Google Sign-In — platform aware
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        // Web: Use Firebase Auth popup directly (bypasses GIS renderButton requirement)
        final provider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(provider);
        await _onLoginSuccess();
      } else {
        // Mobile: Use Google Sign In plugin v7 API
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance
            .authenticate();

        final String? idToken = googleUser.authentication.idToken;

        final GoogleSignInClientAuthorization authorization = await googleUser
            .authorizationClient
            .authorizeScopes(['email', 'profile']);

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authorization.accessToken,
          idToken: idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
        await _onLoginSuccess();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Firebase Error: ${e.message}")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google Sign-In Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: Padding(
        padding: const EdgeInsets.all(25),

        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 80,
                  color: Colors.cyanAccent,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Universal Wallet",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Choose your secure login option",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),

                const SizedBox(height: 40),

                // ================= GOOGLE LOGIN =================
                SizedBox(
                  width: double.infinity,
                  height: 52,

                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,

                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),

                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 30,
                      color: Colors.white,
                    ),

                    label: const Text(
                      "Continue with Google",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Security note
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white12, size: 14),
                    SizedBox(width: 6),
                    Text(
                      "Secured with end-to-end encryption",
                      style: TextStyle(color: Colors.white12, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
