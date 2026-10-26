import '../money/currency.dart';
import '../money/money.dart';
import '../network/api_client.dart';

/// FlowPay currencies that exist as Stellar assets.
const stellarCurrencies = [Currency.usd, Currency.cad, Currency.mxn, Currency.gbp, Currency.ngn];

/// Strict lookup: unknown asset codes return null (never silently "USD").
Currency? stellarCurrencyFor(String code) {
  for (final c in stellarCurrencies) {
    if (c.code == code.toUpperCase()) return c;
  }
  return null;
}

class StellarBalance {
  final Currency currency;
  final Money amount;
  const StellarBalance(this.currency, this.amount);
}

class StellarAccountSummary {
  final String accountId;
  final bool exists;
  final String xlmBalance;
  final List<StellarBalance> balances;
  final List<Currency> missingTrustlines;
  final String explorerUrl;

  const StellarAccountSummary({
    required this.accountId,
    required this.exists,
    required this.xlmBalance,
    required this.balances,
    required this.missingTrustlines,
    required this.explorerUrl,
  });

  bool get isActive => exists && missingTrustlines.isEmpty;

  factory StellarAccountSummary.fromJson(Map<String, dynamic> json) {
    final balances = <StellarBalance>[];
    for (final raw in (json['balances'] as List? ?? const [])) {
      final b = Map<String, dynamic>.from(raw as Map);
      final currency = stellarCurrencyFor(b['currency']?.toString() ?? '');
      if (currency == null) continue;
      balances.add(StellarBalance(currency, Money.fromMinor(BigInt.parse(b['amountMinor'].toString()), currency)));
    }
    return StellarAccountSummary(
      accountId: json['accountId'] as String,
      exists: json['exists'] == true,
      xlmBalance: json['xlmBalance']?.toString() ?? '0',
      balances: balances,
      missingTrustlines: [
        for (final c in (json['missingTrustlines'] as List? ?? const []))
          if (stellarCurrencyFor(c.toString()) != null) stellarCurrencyFor(c.toString())!,
      ],
      explorerUrl: json['explorerUrl']?.toString() ?? '',
    );
  }
}

/// One on-chain payment from Horizon, as returned by the backend.
class StellarPayment {
  final String id;
  final String type;
  final String direction; // incoming | outgoing | self
  final String counterparty;
  final String amount;
  final String currency;
  final String? counterAmount;
  final String? counterCurrency;
  final String transactionHash;
  final String explorerUrl;
  final DateTime createdAt;
  final bool successful;
  final String? memo;

  const StellarPayment({
    required this.id,
    required this.type,
    required this.direction,
    required this.counterparty,
    required this.amount,
    required this.currency,
    this.counterAmount,
    this.counterCurrency,
    required this.transactionHash,
    required this.explorerUrl,
    required this.createdAt,
    required this.successful,
    this.memo,
  });

  factory StellarPayment.fromJson(Map<String, dynamic> j) => StellarPayment(
        id: j['id'].toString(),
        type: j['type'].toString(),
        direction: j['direction'].toString(),
        counterparty: j['counterparty']?.toString() ?? '',
        amount: j['amount'].toString(),
        currency: j['currency'].toString(),
        counterAmount: j['counterAmount']?.toString(),
        counterCurrency: j['counterCurrency']?.toString(),
        transactionHash: j['transactionHash'].toString(),
        explorerUrl: j['explorerUrl']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        successful: j['successful'] != false,
        memo: j['memo']?.toString(),
      );
}

/// Result of relaying a device-signed transaction.
class StellarSubmission {
  /// COMPLETED or PENDING (submitted, awaiting confirmation). Failures throw [ApiException].
  final String status;
  final String hash;
  final String explorerUrl;
  const StellarSubmission(this.status, this.hash, this.explorerUrl);
}

/// Typed access to FlowPay's `/api/stellar` and `/api/wallets` endpoints.
class StellarApi {
  final FlowPayApiClient client;
  const StellarApi(this.client);

  Future<StellarAccountSummary> account(String accountId) async =>
      StellarAccountSummary.fromJson(Map<String, dynamic>.from(await client.get('/api/stellar/accounts/$accountId')));

  Future<void> fundWithFriendbot(String accountId) async {
    await client.post('/api/stellar/accounts/$accountId/fund');
  }

  /// Unsigned trustline transaction, or null when nothing is missing.
  Future<String?> trustlineTransaction(String accountId) async {
    final res = await client.post('/api/stellar/accounts/$accountId/trustlines', body: {});
    if (res is Map && res['xdr'] is String) return res['xdr'] as String;
    return null;
  }

  Future<StellarSubmission> submit(String signedXdr) async {
    final res = Map<String, dynamic>.from(await client.post('/api/stellar/transactions', body: {'signedXdr': signedXdr}));
    return StellarSubmission(res['status'].toString(), res['hash'].toString(), res['explorerUrl']?.toString() ?? '');
  }

  Future<String> reconcile(String hash) async {
    final res = await client.get('/api/stellar/transactions/$hash');
    return (res as Map)['status'].toString();
  }

  /// Testnet only. Returns the amount credited.
  Future<Money> claimTestFunds(String accountId, Currency currency) async {
    final res = Map<String, dynamic>.from(await client.post('/api/stellar/accounts/$accountId/faucet', body: {'currency': currency.code}));
    return Money.fromMajorString(res['amount'].toString(), currency);
  }

  Future<List<StellarPayment>> payments(String accountId, {int limit = 30}) async {
    final res = await client.get('/api/stellar/accounts/$accountId/payments', queryParams: {'limit': '$limit'});
    return [for (final p in ((res as Map)['items'] as List? ?? const [])) StellarPayment.fromJson(Map<String, dynamic>.from(p as Map))];
  }

  Future<String> ownershipChallenge(String accountId) async {
    final res = await client.post('/api/wallets/challenge', body: {'accountId': accountId, 'userId': client.userId});
    return (res as Map)['message'].toString();
  }

  Future<void> registerWallet({required String accountId, required String message, required String signature}) async {
    await client.post('/api/wallets/register', body: {
      'userId': client.userId,
      'accountId': accountId,
      'message': message,
      'signature': signature,
    });
  }
}
