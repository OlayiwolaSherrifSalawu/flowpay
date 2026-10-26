// Opt-in: SEP-10 + SEP-24 against the SDF test anchor (testanchor.stellar.org).
//
//   cd backend && DATABASE_URL=postgresql://none:none@127.0.0.1:1/none PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live/stellar_anchor_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/network/api_client.dart';
import 'package:flowpay_mobile/core/stellar/anchors/anchor_service.dart';
import 'package:flowpay_mobile/core/stellar/stellar_activation.dart';
import 'package:flowpay_mobile/core/stellar/stellar_api.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'live_helpers.dart';

void main() {
  final enabled = Platform.environment['LIVE_STELLAR'] == '1';
  final api = Platform.environment['FLOWPAY_API'] ?? 'http://localhost:4099';
  final stamp = DateTime.now().millisecondsSinceEpoch;

  test('device authenticates to the anchor (SEP-10) and opens deposit + withdraw (SEP-24)', () async {
    final userId = (await liveSignup(api, 'Anchor $stamp', 'anchor.$stamp@flowpay.test')).userId;
    StellarKeyVault.instance = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
    await StellarKeyVault.instance.createWallet(pin: '123456');
    final stellarApi = StellarApi(FlowPayApiClient(baseUrl: api, userId: userId));
    expect((await StellarActivation(api: stellarApi).activate(pin: '123456', claimTestFunds: false)).isActive, isTrue);

    final anchors = AnchorService(api: stellarApi);
    const asset = AnchorConfig.testAnchorUsdc;

    await expectLater(anchors.authenticate(asset, pin: '000000'), throwsA(isA<StellarVaultException>()), reason: 'wrong PIN never reaches the anchor');
    final jwt = await anchors.authenticate(asset, pin: '123456');
    expect(jwt.split('.'), hasLength(3), reason: 'a JWT');

    await anchors.ensureTrustline(asset, pin: '123456');
    await anchors.ensureTrustline(asset, pin: '123456'); // idempotent

    final deposit = await anchors.startDeposit(asset, jwt, amount: '5');
    expect(Uri.parse(deposit.url).host, endsWith('testanchor.stellar.org'));
    final withdraw = await anchors.startWithdraw(asset, jwt, amount: '5');
    expect(Uri.parse(withdraw.url).host, endsWith('testanchor.stellar.org'));

    final status = await anchors.status(asset, jwt, deposit.id);
    expect(status.kind, 'deposit');
    expect(status.status, 'incomplete', reason: 'waits for the user in the anchor page');
    // ignore: avoid_print
    print('LIVE anchor deposit ${deposit.id} → ${deposit.url.substring(0, 60)}…');
  }, skip: enabled ? false : 'set LIVE_STELLAR=1 to run against testnet', timeout: const Timeout(Duration(minutes: 2)));
}
