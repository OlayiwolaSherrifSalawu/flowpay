import 'dart:convert';
import 'package:http/http.dart' as http;

/// Central API configuration for FlowPay mobile app.
/// Connects to the local backend during development / debug, or live Render backend.
class ApiConfig {
  /// Live production backend URL
  static const String liveBackendUrl = 'https://flowpay-k2wn.onrender.com';

  /// Local development backend URL (routed to host via adb reverse tcp:4000 tcp:4000)
  static const String localBackendUrl = 'http://localhost:4000';

  /// Runtime URL override (can be set from UI or settings)
  static String? _runtimeOverrideUrl;

  /// Set a runtime override URL
  static void setOverrideUrl(String? url) {
    _runtimeOverrideUrl = (url != null && url.trim().isNotEmpty) ? url.trim() : null;
  }

  /// Resolves the base URL, allowing override via dart-define `--dart-define=FLOWPAY_API_URL=...`
  /// or runtime configuration.
  static String get baseUrl {
    if (_runtimeOverrideUrl != null && _runtimeOverrideUrl!.isNotEmpty) {
      return _runtimeOverrideUrl!;
    }
    const envUrl = String.fromEnvironment('FLOWPAY_API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return liveBackendUrl;
  }

  /// Quickly verifies if the backend at [targetUrl] (defaults to [baseUrl]) is reachable
  static Future<bool> checkHealth([String? targetUrl]) async {
    final url = targetUrl ?? baseUrl;
    try {
      final uri = Uri.parse('$url/api/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

