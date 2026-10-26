import '../../network/api_client.dart';
import '../../wallet/wallet_signer.dart';
import '../models/financial_plan_models.dart';
import 'execution_provider.dart';

/// Live AI-operator execution on Stellar: the approved plan becomes ONE atomic
/// transaction (payments, conversions to yourself, time-locked savings), signed on
/// this device with the user's PIN. Either every action settles or none does.
class StellarFinancialExecutionProvider implements FinancialExecutionProvider {
  final FlowPayApiClient apiClient;
  final WalletSigner signer;

  /// How long `reserve` actions keep funds locked.
  static const reserveLock = Duration(days: 30);

  StellarFinancialExecutionProvider({required this.apiClient, this.signer = const StellarWalletSigner()});

  @override
  bool get settlesAtomically => true;

  /// Maps plan actions to batch legs. Throws [UnsupportedError] for actions that
  /// can't be settled on Stellar, so nothing partial is ever submitted.
  static List<Map<String, dynamic>> legsFor(FinancialPlan plan, {DateTime? now}) {
    final legs = <Map<String, dynamic>>[];
    final lockUntil = (now ?? DateTime.now()).add(reserveLock).toUtc().toIso8601String();
    for (final a in plan.actions) {
      final source = a.fundingCurrency ?? a.amount.currency;
      switch (a.type) {
        case PlannedActionType.send:
          final dest = a.destinationAmount ?? a.amount;
          legs.add({
            'label': 'Send to ${a.destinationName}',
            'to': a.destinationAddress ?? a.destinationName,
            'mode': 'exact_receive',
            'amount': {'amountMinor': dest.amountMinor.toString(), 'currency': dest.currency.code},
            'fundingCurrency': source.code,
          });
        case PlannedActionType.convert:
        case PlannedActionType.allocate:
          final target = a.destinationCurrency ?? a.amount.currency;
          if (target == a.amount.currency) continue; // keeping funds where they are moves nothing
          legs.add({
            'label': a.description.isNotEmpty ? a.description : 'Convert to ${target.code}',
            'to': 'self',
            'mode': 'exact_send',
            'amount': {'amountMinor': a.amount.amountMinor.toString(), 'currency': a.amount.currency.code},
            'destCurrency': target.code,
          });
        case PlannedActionType.reserve:
          legs.add({
            'label': a.description.isNotEmpty ? a.description : 'Locked savings',
            'to': 'self',
            'mode': 'exact_send',
            'amount': {'amountMinor': a.amount.amountMinor.toString(), 'currency': a.amount.currency.code},
            'destCurrency': (a.destinationCurrency ?? a.amount.currency).code,
            'lockUntil': lockUntil,
          });
        case PlannedActionType.createMission:
        case PlannedActionType.billPay:
          throw UnsupportedError('"${a.type.displayName}" can\'t be settled on Stellar from the AI operator yet.');
      }
    }
    return legs;
  }

  @override
  Future<ExecutionResult> executePlan(FinancialPlan plan, {required String pin}) async {
    if (!plan.validation.isValid) return ExecutionResult.failed(plan.planId, 'Cannot execute an invalid plan.');
    if (plan.isQuoteExpired) return ExecutionResult.failed(plan.planId, 'This quote expired. Please refresh the plan.');

    final legs = legsFor(plan);
    if (legs.isEmpty) return ExecutionResult.failed(plan.planId, 'This plan does not move any money.');

    final proposal = Map<String, dynamic>.from(await apiClient.post('/api/payments/batch/propose', body: {
      'userId': apiClient.userId,
      'legs': legs,
      'memo': plan.summary,
      'purpose': 'AI_PLAN',
      'reference': plan.planId,
    }) as Map);

    final signed = await signer.signTransactionXdr(proposal['signPayload'].toString(), pin: pin);
    final res = Map<String, dynamic>.from(await apiClient.post('/api/payments/batch/execute', body: {
      'userId': apiClient.userId,
      'proposalId': proposal['proposalId'],
      'signedXdr': signed,
    }) as Map);

    final status = res['status']?.toString();
    if (status != 'COMPLETED' && status != 'PENDING') {
      return ExecutionResult.failed(plan.planId, 'Unexpected settlement status: $status');
    }
    return ExecutionResult(
      success: true,
      txHash: res['transactionHash'].toString(),
      planId: plan.planId,
      executedActionsCount: plan.actions.length,
      timestamp: DateTime.now(),
      details: {'status': status, 'explorerUrl': res['explorerUrl'], 'summary': plan.summary},
    );
  }
}
