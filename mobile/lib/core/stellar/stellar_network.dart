/// Which Stellar network the app talks to. Mirrors the backend's
/// `STELLAR_NETWORK`; selected at build time with
/// `--dart-define=STELLAR_NETWORK=public` (defaults to testnet).
class StellarNetwork {
  final String name;
  final String passphrase;
  final String horizonUrl;
  final String explorerBaseUrl;

  const StellarNetwork._(this.name, this.passphrase, this.horizonUrl, this.explorerBaseUrl);

  static const testnet = StellarNetwork._(
    'testnet',
    'Test SDF Network ; September 2015',
    'https://horizon-testnet.stellar.org',
    'https://stellar.expert/explorer/testnet',
  );

  static const public = StellarNetwork._(
    'public',
    'Public Global Stellar Network ; September 2015',
    'https://horizon.stellar.org',
    'https://stellar.expert/explorer/public',
  );

  static const String _selected = String.fromEnvironment('STELLAR_NETWORK', defaultValue: 'testnet');

  static StellarNetwork get current => _selected == 'public' ? public : testnet;

  bool get isTestnet => this == testnet;

  String txUrl(String hash) => '$explorerBaseUrl/tx/$hash';
  String accountUrl(String accountId) => '$explorerBaseUrl/account/$accountId';
}
