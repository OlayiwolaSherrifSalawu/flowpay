import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowpay_mobile/core/services/bank_resolution_service.dart';

void main() {
  group('BankResolutionService Tests', () {
    test('parses live bank list correctly from API response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/banks') {
          return http.Response('''
          {
            "success": true,
            "data": [
              {
                "id": 9,
                "name": "Guaranty Trust Bank",
                "code": "058",
                "slug": "guaranty-trust-bank",
                "isPopular": true
              },
              {
                "id": 295,
                "name": "OPay Digital Services Limited",
                "code": "999992",
                "slug": "opay",
                "isPopular": true
              }
            ]
          }
          ''', 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = BankResolutionService(client: mockClient);
      final banks = await service.getBanks();

      expect(banks.length, 2);
      expect(banks[0].name, 'Guaranty Trust Bank');
      expect(banks[0].code, '058');
      expect(banks[0].isPopular, true);
      expect(banks[1].name, 'OPay Digital Services Limited');
      expect(banks[1].code, '999992');
    });

    test('resolves bank account correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/banks/resolve') {
          expect(request.url.queryParameters['accountNumber'], '0001234567');
          expect(request.url.queryParameters['bankCode'], '058');
          return http.Response('''
          {
            "success": true,
            "data": {
              "accountNumber": "0001234567",
              "accountName": "ADEKUNLE CIROMA CHUKWUMA",
              "bankCode": "058",
              "bankName": "Guaranty Trust Bank",
              "isSimulated": false
            }
          }
          ''', 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = BankResolutionService(client: mockClient);
      final resolved = await service.resolveAccount(
        accountNumber: '0001234567',
        bankCode: '058',
      );

      expect(resolved.accountNumber, '0001234567');
      expect(resolved.accountName, 'ADEKUNLE CIROMA CHUKWUMA');
      expect(resolved.bankCode, '058');
      expect(resolved.bankName, 'Guaranty Trust Bank');
      expect(resolved.isSimulated, false);
    });

    test('rejects account number that is not 10 digits', () async {
      final service = BankResolutionService();
      expect(
        () => service.resolveAccount(accountNumber: '123', bankCode: '058'),
        throwsA(isA<Exception>()),
      );
    });

    test('falls back to default banks if backend request fails', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      final service = BankResolutionService(client: mockClient);
      final banks = await service.getBanks();

      expect(banks.isNotEmpty, true);
      expect(banks.any((b) => b.code == '058'), true);
      expect(banks.any((b) => b.code == '999992'), true);
    });
  });
}
