import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/network/api_client.dart';
import 'package:flowpay_mobile/core/stellar/stellar_api.dart';
import 'package:flowpay_mobile/modules/personal/components/receive_sheet.dart';

const _account = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';

void main() {
  testWidgets('Receive sheet: claim a payment address; a taken name shows the server error', (tester) async {
    String? claimed;
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/handle' && req.method == 'GET') {
        return http.Response(jsonEncode({'success': true, 'data': {'handle': claimed, 'stellarAddress': claimed == null ? null : '$claimed*pay.flowpay.test', 'homeDomain': 'pay.flowpay.test'}}), 200);
      }
      if (req.url.path == '/api/auth/handle' && req.method == 'POST') {
        final handle = (jsonDecode(req.body) as Map)['handle'] as String;
        if (handle == 'taken') {
          return http.Response(jsonEncode({'success': false, 'statusCode': 400, 'code': 'INVALID_REQUEST', 'message': '"taken" is already taken.'}), 400);
        }
        claimed = handle;
        return http.Response(jsonEncode({'success': true, 'data': {'handle': handle, 'stellarAddress': '$handle*pay.flowpay.test', 'homeDomain': 'pay.flowpay.test'}}), 200);
      }
      return http.Response('{}', 404);
    });
    final api = StellarApi(FlowPayApiClient(baseUrl: 'http://api.test', client: client));

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReceiveSheet(accountId: _account, currency: Currency.usd, api: api))));
    await tester.pumpAndSettle();

    expect(find.text('Claim a payment address'), findsOneWidget);
    expect(find.text('*pay.flowpay.test'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('receive_payment_name_field')), 'taken');
    await tester.tap(find.byKey(const Key('receive_payment_name_claim')));
    await tester.pumpAndSettle();
    expect(find.text('"taken" is already taken.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('receive_payment_name_field')), 'ada');
    await tester.tap(find.byKey(const Key('receive_payment_name_claim')));
    await tester.pumpAndSettle();
    expect(find.text('ada*pay.flowpay.test'), findsOneWidget);
    expect(find.text('Anyone on Stellar can pay this address.'), findsOneWidget);
    // The raw account ID is still shown underneath.
    expect(find.text(_account), findsOneWidget);
  });
}
