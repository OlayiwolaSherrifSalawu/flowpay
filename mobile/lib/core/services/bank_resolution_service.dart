import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Bank details returned from the bank listing API
class BankInfo {
  final int id;
  final String name;
  final String code;
  final String slug;
  final String? longcode;
  final bool isPopular;

  const BankInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.slug,
    this.longcode,
    this.isPopular = false,
  });

  factory BankInfo.fromJson(Map<String, dynamic> json) {
    return BankInfo(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      longcode: json['longcode'] as String?,
      isPopular: json['isPopular'] == true,
    );
  }
}

/// Resolved account holder information from Paystack
class ResolvedBankAccount {
  final String accountNumber;
  final String accountName;
  final String bankCode;
  final String bankName;
  final int? bankId;
  final bool isSimulated;
  final String? testNotice;

  const ResolvedBankAccount({
    required this.accountNumber,
    required this.accountName,
    required this.bankCode,
    required this.bankName,
    this.bankId,
    this.isSimulated = false,
    this.testNotice,
  });

  factory ResolvedBankAccount.fromJson(Map<String, dynamic> json) {
    return ResolvedBankAccount(
      accountNumber: json['accountNumber'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      bankCode: json['bankCode'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      bankId: json['bankId'] is int ? json['bankId'] : int.tryParse('${json['bankId']}'),
      isSimulated: json['isSimulated'] == true,
      testNotice: json['testNotice'] as String?,
    );
  }
}

/// Service to fetch supported banks and resolve account numbers via FlowPay Backend & Paystack
class BankResolutionService {
  final http.Client _client;

  BankResolutionService({http.Client? client}) : _client = client ?? http.Client();

  /// Retrieves list of supported banks with popular banks first
  Future<List<BankInfo>> getBanks({String? search, String country = 'nigeria'}) async {
    try {
      final queryParams = <String, String>{'country': country};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/banks').replace(queryParameters: queryParams);
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true && json['data'] is List) {
          return (json['data'] as List)
              .map((b) => BankInfo.fromJson(b as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Fallback to static list on network exception
    }

    return _getFallbackBanks(search);
  }

  /// Resolves an account number against a bank code using Paystack
  Future<ResolvedBankAccount> resolveAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final cleanAccount = accountNumber.trim().replaceAll(RegExp(r'\D'), '');
    final cleanBankCode = bankCode.trim();

    if (cleanAccount.length != 10) {
      throw Exception('Nigerian bank account numbers must be exactly 10 digits.');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/banks/resolve').replace(queryParameters: {
      'accountNumber': cleanAccount,
      'bankCode': cleanBankCode,
    });

    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    final json = jsonDecode(res.body);

    if (res.statusCode == 200 && json['success'] == true && json['data'] != null) {
      return ResolvedBankAccount.fromJson(json['data'] as Map<String, dynamic>);
    }

    final message = json['message'] as String? ?? 'Could not resolve account name.';
    throw Exception(message);
  }

  List<BankInfo> _getFallbackBanks(String? search) {
    final list = [
      const BankInfo(id: 9, name: 'Guaranty Trust Bank (GTB)', code: '058', slug: 'guaranty-trust-bank', isPopular: true),
      const BankInfo(id: 295, name: 'OPay Digital Services Limited', code: '999992', slug: 'opay', isPopular: true),
      const BankInfo(id: 1, name: 'Access Bank', code: '044', slug: 'access-bank', isPopular: true),
      const BankInfo(id: 21, name: 'Zenith Bank', code: '057', slug: 'zenith-bank', isPopular: true),
      const BankInfo(id: 67, name: 'Kuda Bank', code: '50211', slug: 'kuda-bank', isPopular: true),
      const BankInfo(id: 294, name: 'PalmPay', code: '999991', slug: 'palmpay', isPopular: true),
      const BankInfo(id: 7, name: 'First Bank of Nigeria', code: '011', slug: 'first-bank-of-nigeria', isPopular: true),
      const BankInfo(id: 18, name: 'United Bank For Africa (UBA)', code: '033', slug: 'united-bank-for-africa', isPopular: true),
      const BankInfo(id: 200, name: 'Moniepoint MFB', code: '50515', slug: 'moniepoint-mfb', isPopular: true),
      const BankInfo(id: 20, name: 'Wema Bank (ALAT)', code: '035', slug: 'wema-bank', isPopular: true),
      const BankInfo(id: 16, name: 'Stanbic IBTC Bank', code: '221', slug: 'stanbic-ibtc-bank', isPopular: true),
      const BankInfo(id: 24, name: 'Paystack Test Bank', code: '001', slug: 'test-bank', isPopular: true),
    ];

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      return list.where((b) => b.name.toLowerCase().contains(q) || b.code.contains(q)).toList();
    }
    return list;
  }
}

/// Global provider for BankResolutionService
final bankResolutionServiceProvider = Provider<BankResolutionService>((ref) {
  return BankResolutionService();
});
