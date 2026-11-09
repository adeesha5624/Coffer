import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔐 PIN Helper — PIN save, verify, clear and lockout logic
class PinHelper {
  static const String _pinKey = 'user_pin_hash';
  static const String _attemptsKey = 'pin_wrong_attempts';
  static const String _lockTimeKey = 'pin_lock_until';
  static const int maxAttempts = 5;
  static const int lockDurationSeconds = 30;

  // Generate SHA-256 hash
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Save hashed PIN
  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, _hashPin(pin));
    // Reset attempts when saving PIN
    await prefs.setInt(_attemptsKey, 0);
    await prefs.remove(_lockTimeKey);
  }

  // Check if PIN has been set
  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  // Verify entered PIN against stored hash
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_pinKey);
    if (savedHash == null) return false;

    final inputHash = _hashPin(pin);
    if (inputHash == savedHash) {
      // Correct! Reset attempts
      await prefs.setInt(_attemptsKey, 0);
      await prefs.remove(_lockTimeKey);
      return true;
    } else {
      // Wrong! Increment attempts
      int attempts = (prefs.getInt(_attemptsKey) ?? 0) + 1;
      await prefs.setInt(_attemptsKey, attempts);

      // 5 wrong attempts → lock for 30 seconds
      if (attempts >= maxAttempts) {
        final lockUntil = DateTime.now()
            .add(Duration(seconds: lockDurationSeconds))
            .millisecondsSinceEpoch;
        await prefs.setInt(_lockTimeKey, lockUntil);
      }
      return false;
    }
  }

  // Check if PIN entry is locked
  static Future<bool> isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntil = prefs.getInt(_lockTimeKey);
    if (lockUntil == null) return false;

    if (DateTime.now().millisecondsSinceEpoch < lockUntil) {
      return true;
    } else {
      // Lock duration expired — reset attempts
      await prefs.setInt(_attemptsKey, 0);
      await prefs.remove(_lockTimeKey);
      return false;
    }
  }

  // Get remaining lock time in seconds
  static Future<int> getRemainingLockSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntil = prefs.getInt(_lockTimeKey);
    if (lockUntil == null) return 0;

    final remaining = lockUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  // Get count of wrong attempts
  static Future<int> getWrongAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attemptsKey) ?? 0;
  }

  // Clear stored PIN (used during logout)
  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_attemptsKey);
    await prefs.remove(_lockTimeKey);
  }
}
