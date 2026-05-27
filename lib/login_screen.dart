import 'package:flutter/material.dart';
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
  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isOtpSent = false;
  String _verificationId = "";

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

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

  // ✅ Google Sign-In — updated for google_sign_in v7
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // v7: Use singleton instance + authenticate()
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // v7: Get idToken from authentication
      final String? idToken = googleUser.authentication.idToken;

      // v7: Request scopes to get accessToken via authorizationClient
      final GoogleSignInClientAuthorization authorization =
          await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      await _onLoginSuccess();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Firebase Error: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ WhatsApp (Phone) OTP Send — Firebase Phone Auth use කරනවා
  Future<void> _verifyPhoneNumber() async {
    String phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty || !phoneNumber.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Enter phone number with country code\nExample: +94771234567",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,

      // Auto verification
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);

        await _onLoginSuccess();
      },

      // Verification failed
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;

        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification Failed:\n${e.message}")),
        );
      },

      // OTP sent
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;

        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP Code Sent Successfully!")),
        );
      },

      // Timeout
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ✅ Verify OTP
  Future<void> _signInWithOTP() async {
    String smsCode = _otpController.text.trim();

    if (smsCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter OTP code")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      await _onLoginSuccess();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid OTP Code")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),

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

                // ================= WHATSAPP LOGIN =================
                if (!_isOtpSent) ...[
                  // WhatsApp branded phone input
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF25D366).withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,

                      style: const TextStyle(color: Colors.white),

                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(
                            Icons.chat_rounded,
                            color: Color(0xFF25D366),
                            size: 24,
                          ),
                        ),

                        hintText: "WhatsApp Number (+94771234567)",

                        hintStyle: const TextStyle(color: Colors.white38),

                        filled: true,
                        fillColor: const Color(0xFF1E293B),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),

                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // WhatsApp Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _verifyPhoneNumber,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),

                        foregroundColor: Colors.white,

                        elevation: 4,
                        shadowColor: const Color(0xFF25D366).withValues(alpha: 0.4),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),

                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),

                      label: Text(
                        _isLoading ? "Sending..." : "Send OTP via WhatsApp",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // OTP Verification UI
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF25D366).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF25D366),
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Enter Verification Code",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Code sent to ${_phoneController.text}",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _otpController,

                          keyboardType: TextInputType.number,

                          maxLength: 6,

                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            letterSpacing: 12,
                            fontWeight: FontWeight.bold,
                          ),

                          decoration: InputDecoration(
                            hintText: "• • • • • •",

                            hintStyle: const TextStyle(
                              color: Colors.white24,
                              letterSpacing: 8,
                            ),

                            counterText: "",

                            filled: true,

                            fillColor: const Color(0xFF0F172A),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),

                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithOTP,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),

                        foregroundColor: Colors.white,

                        elevation: 4,
                        shadowColor: const Color(0xFF25D366).withValues(alpha: 0.4),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),

                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded, size: 20),

                      label: Text(
                        _isLoading ? "Verifying..." : "Verify & Login",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isOtpSent = false;
                        _otpController.clear();
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white38, size: 16),
                    label: const Text(
                      "Change Number",
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white12)),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),

                      child: Text(
                        "OR",
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),

                    Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),

                const SizedBox(height: 30),

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
