import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../wallet/wallet_signer.dart';
import '../stellar_api.dart';
import '../stellar_key_vault.dart';
import '../stellar_network.dart';

/// An asset a Stellar anchor lets users move between the bank and their wallet.
class AnchorAsset {
  final String label;
  final String domain;
  final String code;
  final String issuer;

  const AnchorAsset({required this.label, required this.domain, required this.code, required this.issuer});
}

/// Anchors FlowPay offers per network. Mainnet partners (bank on/off-ramps for
/// USD/CAD/MXN/GBP/NGN) are added here once agreements exist — none are faked.
class AnchorConfig {
  static const testAnchorUsdc = AnchorAsset(
    label: 'USDC via Stellar test anchor',
    domain: 'testanchor.stellar.org',
    code: 'USDC',
    issuer: 'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5',
  );

  static List<AnchorAsset> forNetwork(StellarNetwork network) => network.isTestnet ? const [testAnchorUsdc] : const [];
}

class AnchorException implements Exception {
  final String message;
  const AnchorException(this.message);
  @override
  String toString() => message;
}

/// SEP-24 transfer as reported by the anchor.
class AnchorTransfer {
  final String id;
  final String kind; // deposit | withdrawal
  final String status;
  final String? amountIn;
  final String? amountOut;
  final String? withdrawAnchorAccount;
  final String? withdrawMemo;
  final String? withdrawMemoType;
  final String? moreInfoUrl;
  final String? message;

  const AnchorTransfer({
    required this.id,
    required this.kind,
    required this.status,
    this.amountIn,
    this.amountOut,
    this.withdrawAnchorAccount,
    this.withdrawMemo,
    this.withdrawMemoType,
    this.moreInfoUrl,
    this.message,
  });

  bool get awaitingUserPayment => kind == 'withdrawal' && status == 'pending_user_transfer_start';
  bool get isFinal => const {'completed', 'refunded', 'expired', 'error', 'no_market', 'too_small', 'too_large'}.contains(status);
}

/// Client-side anchor flows. The device authenticates to the anchor itself
/// (SEP-10 challenge signed by the wallet key, PIN required); FlowPay's backend
/// never sees anchor tokens, keys or the user's bank details.
class AnchorService {
  final StellarNetwork network;
  final WalletSigner signer;
  final StellarApi api;
  final http.Client httpClient;

  AnchorService({required this.api, StellarNetwork? network, this.signer = const StellarWalletSigner(), http.Client? httpClient})
      : network = network ?? StellarNetwork.current,
        httpClient = httpClient ?? http.Client();

  Network get _sdkNetwork => Network(network.passphrase);

  Future<String> _accountId() async {
    final id = await StellarKeyVault.instance.publicKey();
    if (id == null) throw const AnchorException('Set up your wallet first.');
    return id;
  }

  /// SEP-10: proves to the anchor that this device controls the account. Returns a JWT.
  Future<String> authenticate(AnchorAsset asset, {required String pin}) async {
    final account = await _accountId();
    final webAuth = await WebAuth.fromDomain(asset.domain, _sdkNetwork, httpClient: httpClient);
    final challenge = await webAuth.getChallenge(account);
    // Throws if the challenge is unsafe; 60s grace absorbs small clock skew with the anchor.
    webAuth.validateChallenge(challenge, account, null, 60, null);
    final signed = await signer.signTransactionXdr(challenge, pin: pin);
    return webAuth.sendSignedChallengeTransaction(signed);
  }

  /// Adds a trustline for the anchor's asset if the wallet doesn't have one yet.
  Future<void> ensureTrustline(AnchorAsset asset, {required String pin}) async {
    final accountId = await _accountId();
    final sdk = StellarSDK(network.horizonUrl);
    final account = await sdk.accounts.account(accountId);
    final has = account.balances.any((b) => b.assetCode == asset.code && b.assetIssuer == asset.issuer);
    if (has) return;
    final tx = TransactionBuilder(account)
        .addOperation(ChangeTrustOperationBuilder(Asset.createNonNativeAsset(asset.code, asset.issuer), ChangeTrustOperationBuilder.MAX_LIMIT).build())
        .build();
    final signed = await signer.signTransactionXdr(tx.toEnvelopeXdrBase64(), pin: pin);
    final res = await api.submit(signed);
    if (res.status != 'COMPLETED') throw AnchorException('Enabling ${asset.code} is still pending (tx ${res.hash}).');
  }

  Future<TransferServerSEP24Service> _sep24(AnchorAsset asset) =>
      TransferServerSEP24Service.fromDomain(asset.domain, httpClient: httpClient);

  /// Starts an interactive deposit (bank → wallet). Open the returned URL for the
  /// anchor's own KYC and payment instructions.
  Future<({String id, String url})> startDeposit(AnchorAsset asset, String jwt, {String? amount}) async {
    final service = await _sep24(asset);
    final req = SEP24DepositRequest()
      ..jwt = jwt
      ..assetCode = asset.code
      ..assetIssuer = asset.issuer
      ..account = await _accountId();
    if (amount != null) req.amount = amount;
    final res = await service.deposit(req);
    return (id: res.id, url: res.url);
  }

  /// Starts an interactive withdrawal (wallet → bank).
  Future<({String id, String url})> startWithdraw(AnchorAsset asset, String jwt, {String? amount}) async {
    final service = await _sep24(asset);
    final req = SEP24WithdrawRequest()
      ..jwt = jwt
      ..assetCode = asset.code
      ..assetIssuer = asset.issuer
      ..account = await _accountId();
    if (amount != null) req.amount = amount;
    final res = await service.withdraw(req);
    return (id: res.id, url: res.url);
  }

  Future<AnchorTransfer> status(AnchorAsset asset, String jwt, String id) async {
    final service = await _sep24(asset);
    final req = SEP24TransactionRequest()
      ..jwt = jwt
      ..id = id;
    final t = (await service.transaction(req)).transaction;
    return AnchorTransfer(
      id: t.id,
      kind: t.kind,
      status: t.status,
      amountIn: t.amountIn,
      amountOut: t.amountOut,
      withdrawAnchorAccount: t.withdrawAnchorAccount,
      withdrawMemo: t.withdrawMemo,
      withdrawMemoType: t.withdrawMemoType,
      moreInfoUrl: t.moreInfoUrl,
      message: t.message,
    );
  }

  static Memo memoFor(String? type, String? value) {
    if (value == null || value.isEmpty) return Memo.none();
    switch (type) {
      case 'id':
        return Memo.id(BigInt.parse(value));
      case 'hash':
        return Memo.hash(base64Decode(value));
      default:
        return Memo.text(value);
    }
  }

  /// For a withdrawal awaiting funds: sends exactly what the anchor asked for, to
  /// the account and memo it specified. Returns the Stellar transaction hash.
  Future<String> sendWithdrawalPayment(AnchorAsset asset, AnchorTransfer transfer, {required String pin}) async {
    if (!transfer.awaitingUserPayment || transfer.withdrawAnchorAccount == null || transfer.amountIn == null) {
      throw const AnchorException('The anchor is not waiting for a payment on this withdrawal.');
    }
    final accountId = await _accountId();
    final account = await StellarSDK(network.horizonUrl).accounts.account(accountId);
    final tx = TransactionBuilder(account)
        .addOperation(PaymentOperationBuilder(transfer.withdrawAnchorAccount!, Asset.createNonNativeAsset(asset.code, asset.issuer), transfer.amountIn!).build())
        .addMemo(memoFor(transfer.withdrawMemoType, transfer.withdrawMemo))
        .build();
    final signed = await signer.signTransactionXdr(tx.toEnvelopeXdrBase64(), pin: pin);
    final res = await api.submit(signed);
    return res.hash;
  }
}
