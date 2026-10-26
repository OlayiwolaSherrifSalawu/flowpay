import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';

/// Applied to every test file. Each test gets a fresh, empty, in-memory key
/// vault (fast KDF) — production code has no hidden "test mode" for keys.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    StellarKeyVault.instance = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
  });
  await testMain();
}
