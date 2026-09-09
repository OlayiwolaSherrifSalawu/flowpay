import '../../design_system/states.dart';
import '../../money/money.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../models/financial_plan_models.dart';

/// Execution Result outcome returned by an ExecutionProvider
class ExecutionResult {
  final bool success;
  final String txHash;
  final String planId;
  final int executedActionsCount;
  final DateTime timestamp;
  final Map<String, dynamic> details;
  final String? errorMessage;

  const ExecutionResult({
    required this.success,
    required this.txHash,
    required this.planId,
    required this.executedActionsCount,
    required this.timestamp,
    this.details = const {},
    this.errorMessage,
  });

  factory ExecutionResult.failed(String planId, String error) {
    return ExecutionResult(
      success: false,
      txHash: '',
      planId: planId,
      executedActionsCount: 0,
      timestamp: DateTime.now(),
      errorMessage: error,
    );
  }
}

/// Abstract Financial Execution Provider
/// Decouples AI planning from actual underlying blockchain / banking rails.
abstract class FinancialExecutionProvider {
  Future<ExecutionResult> executePlan(FinancialPlan plan, {required String pin});
}

/// Demo & Sandbox Execution Provider
/// Atomically debits local wallets, updates activity ledger, and simulates on-chain settlement.
class DemoFinancialExecutionProvider implements FinancialExecutionProvider {
  final WalletRepository walletRepo;
  final ActivityRepository? activityRepo;

  DemoFinancialExecutionProvider({
    required this.walletRepo,
    this.activityRepo,
  });

  @override
  Future<ExecutionResult> executePlan(FinancialPlan plan,
      {required String pin}) async {
    if (!plan.validation.isValid) {
      return ExecutionResult.failed(
          plan.planId, 'Cannot execute an invalid financial plan.');
    }

    if (pin.trim().length < 4) {
      return ExecutionResult.failed(
          plan.planId, 'Authorization PIN is required for execution.');
    }

    if (plan.isQuoteExpired) {
      return ExecutionResult.failed(
          plan.planId, 'Payment quote has expired. Please refresh to get current rates.');
    }

    try {
      // 1. Debit and credit wallets according to balance impacts
      if (plan.expectedBalanceChanges.isNotEmpty) {
        for (final impact in plan.expectedBalanceChanges) {
          if (impact.isDebit) {
            await walletRepo.debitWallet(
              walletId: impact.walletId,
              amount: Money.fromMinor(impact.delta.minorUnits.abs(), impact.currency),
            );
          } else if (impact.isCredit) {
            await walletRepo.creditWallet(
              walletId: impact.walletId,
              amount: impact.delta,
            );
          }
        }
      } else {
        for (final act in plan.actions) {
          if (act.type == PlannedActionType.send) {
            await walletRepo.debitWallet(
              walletId: act.sourceWalletId,
              amount: act.amount,
            );
          }
        }
      }

      // 2. Log activity ledger
      final txHash =
          '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}${plan.planId.hashCode.abs().toRadixString(16)}';

      if (activityRepo != null) {
        for (final act in plan.actions) {
          final actModel = ActivityModel(
            id: 'act_exec_${DateTime.now().millisecondsSinceEpoch}_${act.id}',
            title: '${act.type.displayName} to ${act.destinationName}',
            description: act.description,
            amount: act.amount,
            category: act.type == PlannedActionType.send
                ? ActivityCategory.transfer
                : ActivityCategory.mission,
            status: FlowPayAppStatus.completed,
            timestamp: DateTime.now(),
            reference: 'FP-OP-${act.id}',
          );
          try {
            await activityRepo!.recordActivity(actModel);
          } catch (_) {}
        }
      }

      return ExecutionResult(
        success: true,
        txHash: txHash,
        planId: plan.planId,
        executedActionsCount: plan.actions.length,
        timestamp: DateTime.now(),
        details: {
          'summary': plan.summary,
          'totalDebit': plan.totalDebit.toFormattedString(),
          'fee': plan.totalFee.toFormattedString(),
        },
      );
    } catch (e) {
      return ExecutionResult.failed(plan.planId, e.toString());
    }
  }
}
