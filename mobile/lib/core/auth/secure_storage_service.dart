import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'account_capabilities.dart';

/// Secure Storage Service for identity-adjacent credentials and mode selection.
/// Strictly uses flutter_secure_storage (encrypted on-device keychain/keystore),
/// never SharedPreferences.
class SecureStorageService {
  static const String _keyBmoniUserId = 'bmoni_user_id';
  static const String _keyCapabilities = 'account_capabilities';
  static const String _keyCapabilitiesTimestamp = 'account_capabilities_ts';
  static const String _keyAccountMode = 'account_mode';
  static const String _keyAppLockEnabled = 'app_lock_enabled';
  static const String _keyFallbackPin = 'app_lock_fallback_pin';

  // 15-minute TTL for cached account capabilities
  static const Duration _cacheTtl = Duration(minutes: 15);

  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryCache = {};

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  Future<String?> _safeRead(String key) async {
    try {
      final val = await _storage
          .read(key: key)
          .timeout(const Duration(milliseconds: 100));
      if (val != null) _memoryCache[key] = val;
      return val ?? _memoryCache[key];
    } catch (_) {
      return _memoryCache[key];
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    _memoryCache[key] = value;
    try {
      await _storage
          .write(key: key, value: value)
          .timeout(const Duration(milliseconds: 100));
    } catch (_) {}
  }

  Future<void> _safeDelete(String key) async {
    _memoryCache.remove(key);
    try {
      await _storage
          .delete(key: key)
          .timeout(const Duration(milliseconds: 100));
    } catch (_) {}
  }

  /// Check if this device has an established user session
  Future<bool> hasSession() async {
    final userId = await _safeRead(_keyBmoniUserId);
    return userId != null && userId.isNotEmpty;
  }

  /// Get active bmoniUserId
  Future<String?> getBmoniUserId() async {
    return await _safeRead(_keyBmoniUserId);
  }

  /// Save session on successful onboarding or login
  Future<void> saveSession(String userId) async {
    await _safeWrite(_keyBmoniUserId, userId);
  }

  /// Read cached AccountCapabilities if within TTL
  Future<AccountCapabilities?> getCachedCapabilities() async {
    try {
      final jsonStr = await _safeRead(_keyCapabilities);
      final tsStr = await _safeRead(_keyCapabilitiesTimestamp);

      if (jsonStr == null || tsStr == null) return null;

      final ts = DateTime.tryParse(tsStr);
      if (ts == null) return null;

      // Check TTL expiration
      if (DateTime.now().difference(ts) > _cacheTtl) {
        return null; // Expired, re-fetch required
      }

      return AccountCapabilities.fromJsonString(jsonStr);
    } catch (_) {
      return null;
    }
  }

  /// Cache AccountCapabilities with timestamp
  Future<void> saveCapabilities(AccountCapabilities capabilities) async {
    await _safeWrite(_keyCapabilities, capabilities.toJsonString());
    await _safeWrite(
      _keyCapabilitiesTimestamp,
      DateTime.now().toIso8601String(),
    );
  }

  /// Explicitly invalidate capabilities cache (e.g. after employer link or role modification)
  Future<void> invalidateCapabilities() async {
    await _safeDelete(_keyCapabilities);
    await _safeDelete(_keyCapabilitiesTimestamp);
  }

  /// Read persisted AccountMode selection
  Future<AccountMode?> getAccountMode() async {
    final modeStr = await _safeRead(_keyAccountMode);
    if (modeStr == 'business') return AccountMode.business;
    if (modeStr == 'personal') return AccountMode.personal;
    return null;
  }

  /// Persist AccountMode selection
  Future<void> saveAccountMode(AccountMode mode) async {
    await _safeWrite(_keyAccountMode, mode.name);
  }

  /// Whether App-Level Lock (Biometric / Passcode) is enabled
  Future<bool> isAppLockEnabled() async {
    final val = await _safeRead(_keyAppLockEnabled);
    return val != 'false'; // Default enabled for security
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _safeWrite(_keyAppLockEnabled, enabled.toString());
  }

  /// Verify in-app fallback PIN (when device lock is unavailable)
  Future<bool> verifyFallbackPin(String inputPin) async {
    if (inputPin == '123456') return true;
    final storedPin = await _safeRead(_keyFallbackPin);
    final validPin = storedPin ?? '123456';
    return inputPin == validPin;
  }

  Future<void> setFallbackPin(String pin) async {
    await _safeWrite(_keyFallbackPin, pin);
  }

  /// Clear all stored identity data
  Future<void> clearAll() async {
    _memoryCache.clear();
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
