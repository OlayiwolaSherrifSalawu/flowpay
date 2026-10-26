import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// A non-2xx response from the FlowPay API, keeping the status and machine code
/// so callers can tell "failed" apart from "pending" or "not found".
class ApiException implements Exception {
  final int statusCode;
  final String? code;
  final String message;
  final dynamic data;

  const ApiException(this.statusCode, this.message, {this.code, this.data});

  @override
  String toString() => message;
}

class FlowPayApiClient {
  /// Generous because the hosted backend can cold-start; never infinite.
  static const Duration requestTimeout = Duration(seconds: 45);

  final String baseUrl;
  final http.Client _client;
  String? _userId;

  FlowPayApiClient({
    String? baseUrl,
    http.Client? client,
    String? userId,
  })  : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client(),
        _userId = userId ?? 'usr_flowpay_sandbox_master';

  String get userId => _userId ?? 'usr_flowpay_sandbox_master';

  void setUserId(String? userId) {
    _userId = userId ?? 'usr_flowpay_sandbox_master';
  }

  Map<String, String> _buildHeaders([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (_userId != null && _userId!.isNotEmpty) 'x-user-id': _userId!,
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final res = await _client.get(uri, headers: _buildHeaders(headers)).timeout(requestTimeout);
    return _handleResponse(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$path');
    final allHeaders = _buildHeaders({'Content-Type': 'application/json'});
    if (headers != null) allHeaders.addAll(headers);
    final res = await _client.post(
      uri,
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(requestTimeout);
    return _handleResponse(res);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$path');
    final allHeaders = _buildHeaders({'Content-Type': 'application/json'});
    if (headers != null) allHeaders.addAll(headers);
    final res = await _client.patch(
      uri,
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(requestTimeout);
    return _handleResponse(res);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$path');
    final allHeaders = _buildHeaders({'Content-Type': 'application/json'});
    if (headers != null) allHeaders.addAll(headers);
    final res = await _client.put(
      uri,
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(requestTimeout);
    return _handleResponse(res);
  }

  Future<dynamic> delete(String path, {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _client.delete(uri, headers: _buildHeaders(headers)).timeout(requestTimeout);
    return _handleResponse(res);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return data['data'];
      }
      return data;
    }

    String errorMsg = 'HTTP ${response.statusCode}';
    String? code;
    dynamic data;
    try {
      final errObj = jsonDecode(response.body);
      if (errObj['message'] != null) {
        errorMsg = errObj['message'].toString();
      }
      code = errObj['code']?.toString();
      data = errObj['data'];
    } catch (_) {}
    throw ApiException(response.statusCode, errorMsg, code: code, data: data);
  }
}
