import 'package:flutter/foundation.dart';

/// Central API configuration for FlowPay mobile app.
/// Connects to the local backend during development / debug, or live Render backend.
class ApiConfig {
  /// Live production backend URL
  static const String liveBackendUrl = 'https://flowpay-k2wn.onrender.com';

  /// Local development backend URL (routed to host via adb reverse tcp:4000 tcp:4000)
  static const String localBackendUrl = 'http://localhost:4000';

  /// Resolves the base URL, allowing override via dart-define `--dart-define=FLOWPAY_API_URL=...`
  /// Defaults to the live deployed production backend (https://flowpay-k2wn.onrender.com)
  /// so physical devices, emulators, and release builds connect seamlessly to live services.
  static String get baseUrl {
    const envUrl = String.fromEnvironment('FLOWPAY_API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return liveBackendUrl;
  }
}
