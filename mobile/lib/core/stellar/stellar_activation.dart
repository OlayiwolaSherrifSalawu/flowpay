import '../money/currency.dart';
import '../money/money.dart';
import '../wallet/wallet_signer.dart';
import 'stellar_api.dart';
import 'stellar_key_vault.dart';
import 'stellar_network.dart';

enum ActivationStep { linkToAccount, createOnNetwork, enableCurrencies, testFunds }

class ActivationStepResult {
  final ActivationStep step;
  final bool ok;
  final bool skipped;
  final String? error;
  const ActivationStepResult(this.step, {this.ok = true, this.skipped = false, this.error});
}

class ActivationReport {
  final String accountId;
  final List<ActivationStepResult> steps;
  final Money? testFunds;
  const ActivationReport(this.accountId, this.steps, {this.testFunds});

  /// Linked, on the network and able to hold every FlowPay currency.
  bool get isActive => steps.where((s) => s.step != ActivationStep.testFunds).every((s) => s.ok);
  List<ActivationStepResult> get failures => steps.where((s) => !s.ok).toList();
}

/// Turns a freshly created on-device key into a usable FlowPay wallet:
///   1. prove ownership & link it to the FlowPay user (signed challenge),
///   2. create the account on Stellar (testnet: Friendbot test XLM),
///   3. add trustlines for USD/CAD/MXN/GBP/NGN (device-signed),
///   4. testnet only: claim clearly-labelled test USD.
///
/// Each step is idempotent and reports its real outcome — a failed step is never
/// reported as done, and the flow can be re-run to finish.
class StellarActivation {
  final StellarApi api;
  final WalletSigner signer;
  final StellarNetwork network;

  StellarActivation({required this.api, this.signer = const StellarWalletSigner(), StellarNetwork? network})
      : network = network ?? StellarNetwork.current;

  Future<ActivationReport> activate({required String pin, bool claimTestFunds = true}) async {
    final accountId = await StellarKeyVault.instance.publicKey();
    if (accountId == null) {
      throw const StellarVaultException(StellarVaultErrorCode.noWallet, 'Create your wallet first.');
    }
    final steps = <ActivationStepResult>[];
    Money? funds;

    Future<bool> run(ActivationStep step, Future<void> Function() body) async {
      try {
        await body();
        steps.add(ActivationStepResult(step));
        return true;
      } catch (e) {
        steps.add(ActivationStepResult(step, ok: false, error: e.toString()));
        return false;
      }
    }

    await run(ActivationStep.linkToAccount, () async {
      final message = await api.ownershipChallenge(accountId);
      final signature = await signer.signMessage(message, pin: pin);
      await api.registerWallet(accountId: accountId, message: message, signature: signature);
    });

    var summary = await api.account(accountId);
    if (summary.exists) {
      steps.add(const ActivationStepResult(ActivationStep.createOnNetwork, skipped: true));
    } else if (!network.isTestnet) {
      steps.add(const ActivationStepResult(ActivationStep.createOnNetwork,
          ok: false, error: 'Fund this wallet with at least 2 XLM to activate it on Stellar.'));
      return ActivationReport(accountId, steps);
    } else if (!await run(ActivationStep.createOnNetwork, () => api.fundWithFriendbot(accountId))) {
      return ActivationReport(accountId, steps);
    }

    await run(ActivationStep.enableCurrencies, () async {
      final xdr = await api.trustlineTransaction(accountId);
      if (xdr == null) return;
      final signed = await signer.signTransactionXdr(xdr, pin: pin);
      final res = await api.submit(signed);
      if (res.status != 'COMPLETED') {
        throw StateError('Enabling currencies is still pending on the network (tx ${res.hash}).');
      }
    });

    if (claimTestFunds && network.isTestnet && steps.last.ok) {
      summary = await api.account(accountId);
      final hasUsd = summary.balances.any((b) => b.currency == Currency.usd && b.amount.minorUnits > 0);
      if (hasUsd) {
        steps.add(const ActivationStepResult(ActivationStep.testFunds, skipped: true));
      } else {
        await run(ActivationStep.testFunds, () async {
          funds = await api.claimTestFunds(accountId, Currency.usd);
        });
      }
    }
    return ActivationReport(accountId, steps, testFunds: funds);
  }
}
