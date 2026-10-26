import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';

const testWalletPin = '123456';

/// Creates a real Stellar keypair in the (in-memory) test vault, protected by
/// [pin]. Returns the account ID (G...).
Future<String> provisionTestWallet({String pin = testWalletPin}) {
  return StellarKeyVault.instance.createWallet(pin: pin);
}
