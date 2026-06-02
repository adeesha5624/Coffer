import 'dart:async';
import 'package:flutter/material.dart';
import 'pin_helper.dart';
import 'dashboard_screen.dart';

enum PinMode { setup, login }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  final Function(bool) onThemeChanged;
  final bool isDarkMode;
  final VoidCallback? onForgotPin;

  const PinScreen({
    super.key,
    required this.mode,
    required this.onThemeChanged,
    required this.isDarkMode,
    this.onForgotPin,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLocked = false;
  int _remainingSeconds = 0;
  Timer? _lockTimer;
  int _wrongAttempts = 0;

  // Shake animation
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Success animation
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });

    if (widget.mode == PinMode.login) {
      _checkLockStatus();
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkLockStatus() async {
    final locked = await PinHelper.isLocked();
    if (locked) {
      final remaining = await PinHelper.getRemainingLockSeconds();
      setState(() {
        _isLocked = true;
        _remainingSeconds = remaining;
      });
      _startLockTimer();
    }
    final attempts = await PinHelper.getWrongAttempts();
    setState(() => _wrongAttempts = attempts);
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _isLocked = false;
          _wrongAttempts = 0;
          timer.cancel();
        }
      });
    });
  }

  void _onKeyTap(String key) {
    if (_isLocked) return;

    if (key == 'delete') {
      if (_enteredPin.isNotEmpty) {
        setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
      }
      return;
    }

    if (_enteredPin.length >= 4) return;

    setState(() => _enteredPin += key);

    if (_enteredPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (widget.mode == PinMode.setup) {
          _handleSetupPin();
        } else {
          _handleLoginPin();
        }
      });
    }
  }

  Future<void> _handleSetupPin() async {
    if (!_isConfirming) {
      // පළවෙනි වතාවේ PIN enter කරනවා
      setState(() {
        _confirmPin = _enteredPin;
        _enteredPin = '';
        _isConfirming = true;
      });
    } else {
      // දෙවෙනි වතාවේ confirm කරනවා
      if (_enteredPin == _confirmPin) {
        await PinHelper.savePin(_enteredPin);
        setState(() => _showSuccess = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        _navigateToDashboard();
      } else {
        _shakeController.forward();
        setState(() {
          _enteredPin = '';
          _confirmPin = '';
          _isConfirming = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PINs don't match! Try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleLoginPin() async {
    final isCorrect = await PinHelper.verifyPin(_enteredPin);

    if (isCorrect) {
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _navigateToDashboard();
    } else {
      _shakeController.forward();
      final attempts = await PinHelper.getWrongAttempts();
      final locked = await PinHelper.isLocked();

      setState(() {
        _enteredPin = '';
        _wrongAttempts = attempts;
      });

      if (locked) {
        final remaining = await PinHelper.getRemainingLockSeconds();
        setState(() {
          _isLocked = true;
          _remainingSeconds = remaining;
        });
        _startLockTimer();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locked
              ? "Too many attempts! Locked for ${PinHelper.lockDurationSeconds}s"
              : "Wrong PIN! ${PinHelper.maxAttempts - attempts} attempts left"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          onThemeChanged: widget.onThemeChanged,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = widget.mode == PinMode.setup;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // 🔐 Lock icon with glow
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _showSuccess
                        ? [Colors.greenAccent, const Color(0xFF00E676)]
                        : [Colors.cyanAccent.withValues(alpha: 0.2), Colors.cyanAccent.withValues(alpha: 0.05)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _showSuccess
                          ? Colors.greenAccent.withValues(alpha: 0.3)
                          : Colors.cyanAccent.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _showSuccess ? Icons.check_rounded : Icons.lock_rounded,
                  size: 40,
                  color: _showSuccess ? Colors.white : Colors.cyanAccent,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Title
            Text(
              _isLocked
                  ? "Account Locked"
                  : isSetup
                      ? (_isConfirming ? "Confirm Your PIN" : "Create a PIN")
                      : "Enter Your PIN",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              _isLocked
                  ? "Try again in $_remainingSeconds seconds"
                  : isSetup
                      ? (_isConfirming
                          ? "Re-enter your 4-digit PIN"
                          : "Set a 4-digit PIN for quick access")
                      : "Enter your 4-digit PIN to continue",
              style: TextStyle(
                color: _isLocked ? Colors.redAccent : Colors.white38,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 40),

            // 🔴🔴🔴🔴 PIN dots
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _shakeAnimation.value *
                        ((_shakeController.value * 10).toInt() % 2 == 0 ? 1 : -1),
                    0,
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: isFilled ? 20 : 16,
                    height: isFilled ? 20 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _showSuccess
                          ? Colors.greenAccent
                          : isFilled
                              ? Colors.cyanAccent
                              : Colors.transparent,
                      border: Border.all(
                        color: _showSuccess
                            ? Colors.greenAccent
                            : isFilled
                                ? Colors.cyanAccent
                                : Colors.white24,
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: _showSuccess
                                    ? Colors.greenAccent.withValues(alpha: 0.4)
                                    : Colors.cyanAccent.withValues(alpha: 0.4),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),

            // Wrong attempts indicator
            if (_wrongAttempts > 0 && !_isLocked)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Text(
                  "${PinHelper.maxAttempts - _wrongAttempts} attempts remaining",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),

            const Spacer(flex: 1),

            // 🔢 Numeric Keypad
            _buildKeypad(),

            const SizedBox(height: 20),

            // Forgot PIN? link (only in login mode)
            if (!isSetup)
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text("Forgot PIN?",
                          style: TextStyle(color: Colors.white)),
                      content: const Text(
                        "PIN clear කරලා Google/WhatsApp වලින් අලුතෙන් login වෙන්න වෙනවා.",
                        style: TextStyle(color: Colors.white60),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel",
                              style: TextStyle(color: Colors.white38)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          child: const Text("Reset PIN"),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await PinHelper.clearPin();
                    if (widget.onForgotPin != null) {
                      widget.onForgotPin!();
                    }
                  }
                },
                child: const Text(
                  "Forgot PIN?",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'delete'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 70, height: 70);
                }
                return _buildKeyButton(key);
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeyButton(String key) {
    final isDelete = key == 'delete';
    final isDisabled = _isLocked || _showSuccess;

    return GestureDetector(
      onTap: isDisabled ? null : () => _onKeyTap(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: isDelete
              ? Icon(
                  Icons.backspace_outlined,
                  color: isDisabled ? Colors.white12 : Colors.white54,
                  size: 22,
                )
              : Text(
                  key,
                  style: TextStyle(
                    color: isDisabled ? Colors.white12 : Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                  ),
                ),
        ),
      ),
    );
  }
}
