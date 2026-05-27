import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔐 PIN Helper — PIN save, verify, clear සහ lockout logic
class PinHelper {
  static const String _pinKey = 'user_pin_hash';
  static const String _attemptsKey = 'pin_wrong_attempts';
  static const String _lockTimeKey = 'pin_lock_until';
  static const int maxAttempts = 5;
  static const int lockDurationSeconds = 30;

  // SHA-256 hash generate කරනවා
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ✅ PIN save කරනවා (hash කරලා)
  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, _hashPin(pin));
    // PIN set කරනකොට attempts reset කරනවා
    await prefs.setInt(_attemptsKey, 0);
    await prefs.remove(_lockTimeKey);
  }

  // ✅ PIN set කරලා තියෙනවද check කරනවා
  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  // ✅ PIN verify කරනවා
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
            .add(const Duration(seconds: lockDurationSeconds))
            .millisecondsSinceEpoch;
        await prefs.setInt(_lockTimeKey, lockUntil);
      }
      return false;
    }
  }

  // ✅ Lock වෙලාද check කරනවා
  static Future<bool> isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntil = prefs.getInt(_lockTimeKey);
    if (lockUntil == null) return false;

    if (DateTime.now().millisecondsSinceEpoch < lockUntil) {
      return true;
    } else {
      // Lock time ඉවර — reset කරනවා
      await prefs.setInt(_attemptsKey, 0);
      await prefs.remove(_lockTimeKey);
      return false;
    }
  }

  // ✅ Lock එක ඉවර වෙන්න තව කොච්චර seconds ද
  static Future<int> getRemainingLockSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntil = prefs.getInt(_lockTimeKey);
    if (lockUntil == null) return 0;

    final remaining = lockUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  // ✅ Wrong attempts ගණන ගන්නවා
  static Future<int> getWrongAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attemptsKey) ?? 0;
  }

  // ✅ PIN clear කරනවා (logout with clear PIN)
  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_attemptsKey);
    await prefs.remove(_lockTimeKey);
  }
}
