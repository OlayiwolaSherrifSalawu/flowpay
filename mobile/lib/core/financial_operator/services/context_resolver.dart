import '../../money/currency.dart';
import '../../money/money.dart';
import '../models/financial_entities.dart';
import 'financial_context_service.dart';

/// FlowPay Context Resolver
/// Connects extracted entities from natural language to actual user data
/// (Beneficiaries, Wallets, Reserves, Balances) without hallucinating.
class ContextResolver {
  final FinancialContextService contextService;

  ContextResolver({required this.contextService});

  /// Resolve all entities inside a StructuredIntent against user financial context
  Future<StructuredIntent> resolve(StructuredIntent intent) async {
    final updatedActions = <ActionIntent>[];

    for (final action in intent.actions) {
      var resolvedAction = action;

      // 1. Resolve Person / Beneficiary
      if (resolvedAction.person != null &&
          resolvedAction.person!.knowledgeState != EntityKnowledgeState.known) {
        resolvedAction = await _resolvePerson(resolvedAction);
      }

      // 2. Resolve Destination (Wallet / Reserve)
      if (resolvedAction.destination != null &&
          resolvedAction.destination!.knowledgeState !=
              EntityKnowledgeState.known) {
        resolvedAction = await _resolveDestination(resolvedAction);
      }

      // 3. Resolve Relative Amounts (Percentage / Half) if base is known
      if (resolvedAction.amount.type == AmountType.percentage ||
          resolvedAction.amount.type == AmountType.half) {
        resolvedAction =
            await _resolveRelativeAmount(resolvedAction, intent.incomingAmount);
      }

      updatedActions.add(resolvedAction);
    }

    // 4. Resolve Remainder amounts after all fixed/percentage amounts are known
    final finalActions = <ActionIntent>[];
    for (final action in updatedActions) {
      if (action.amount.type == AmountType.remainder) {
        final resolvedRemainderAction =
            _resolveRemainder(action, updatedActions, intent.incomingAmount);
        finalActions.add(resolvedRemainderAction);
      } else {
        finalActions.add(action);
      }
    }

    return intent.copyWith(actions: finalActions);
  }

  /// Resolve a person entity against the beneficiary repository
  Future<ActionIntent> _resolvePerson(ActionIntent action) async {
    final person = action.person!;
    final query = person.rawInput.trim();

    if (query.isEmpty) {
      return action.copyWith(
        person: person.copyWith(knowledgeState: EntityKnowledgeState.unknown),
      );
    }

    final result = await contextService.resolveBeneficiary(query);

    if (result.isUnique) {
      final match = result.match!;
      return action.copyWith(
        person: person.copyWith(
          resolvedBeneficiary: match,
          knowledgeState: EntityKnowledgeState.known,
          aliasMatched: match.nickname,
        ),
        description:
            'Send ${action.amount.formattedDisplay} to ${match.legalName} (${match.nickname})',
      );
    } else if (result.isAmbiguous) {
      return action.copyWith(
        person: person.copyWith(
          candidates: result.candidates,
          knowledgeState: EntityKnowledgeState.ambiguous,
        ),
      );
    } else {
      // Unknown beneficiary: AI must NEVER invent a recipient
      return action.copyWith(
        person: person.copyWith(
          knowledgeState: EntityKnowledgeState.unknown,
        ),
      );
    }
  }

  /// Resolve destination wallet or reserve
  Future<ActionIntent> _resolveDestination(ActionIntent action) async {
    final dest = action.destination!;
    final query = dest.rawInput.trim().toLowerCase();

    // Check existing reserves first
    final reserve = await contextService.findReserve(query);
    if (reserve != null) {
      return action.copyWith(
        destination: dest.copyWith(
          type: DestinationType.reserve,
          resolvedWalletId: reserve.targetWalletId,
          resolvedWalletName: reserve.name,
          resolvedCurrency: reserve.currency,
          knowledgeState: EntityKnowledgeState.known,
        ),
      );
    }

    // Check existing wallets
    final wallets = await contextService.getWallets();
    for (final w in wallets) {
      final name = '${w.currency.code} Wallet'.toLowerCase();
      if (name.contains(query) || query.contains(w.currency.code.toLowerCase())) {
        return action.copyWith(
          destination: dest.copyWith(
            type: DestinationType.wallet,
            resolvedWalletId: w.id,
            resolvedWalletName: '${w.currency.code} Wallet',
            resolvedCurrency: w.currency,
            knowledgeState: EntityKnowledgeState.known,
          ),
        );
      }
    }

    // If destination is Tax or Savings and not matched explicitly, check default savings
    if (query.contains('saving')) {
      final usdWallet = await contextService.getWalletForCurrency(Currency.usd);
      return action.copyWith(
        destination: dest.copyWith(
          type: DestinationType.reserve,
          resolvedWalletId: usdWallet?.id ?? 'sw_demo_usdb_01',
          resolvedWalletName: 'USD Savings',
          resolvedCurrency: Currency.usd,
          knowledgeState: EntityKnowledgeState.known,
        ),
      );
    }

    // Destination is unknown (e.g. Tax Reserve has not been created yet)
    return action.copyWith(
      destination: dest.copyWith(
        knowledgeState: EntityKnowledgeState.unknown,
      ),
    );
  }

  /// Resolve percentage / half amounts
  Future<ActionIntent> _resolveRelativeAmount(
    ActionIntent action,
    AmountEntity? incomingAmount,
  ) async {
    Money? base;

    if (incomingAmount != null && incomingAmount.fixedAmount != null) {
      base = incomingAmount.fixedAmount!;
    } else {
      // Default to primary USD wallet balance
      final usdWallet = await contextService.getWalletForCurrency(Currency.usd);
      if (usdWallet != null) {
        base = usdWallet.balance;
      }
    }

    if (base == null) return action;

    final pct = action.amount.type == AmountType.half
        ? 50.0
        : (action.amount.percentage ?? 0.0);

    final resolvedMoney = FinancialContextService.calculatePercentage(base, pct);

    return action.copyWith(
      amount: action.amount.copyWith(
        resolvedAmount: resolvedMoney,
        knowledgeState: EntityKnowledgeState.known,
      ),
      description:
          '${action.description.split(' ').first} ${resolvedMoney.toFormattedString()} (${pct.toStringAsFixed(0)}%) for ${action.purpose ?? 'allocation'}',
    );
  }

  /// Resolve remainder: incoming - (all other allocated actions)
  ActionIntent _resolveRemainder(
    ActionIntent action,
    List<ActionIntent> allActions,
    AmountEntity? incomingAmount,
  ) {
    if (incomingAmount == null || incomingAmount.fixedAmount == null) {
      return action;
    }

    final total = incomingAmount.fixedAmount!;
    final deductions = <Money>[];

    for (final other in allActions) {
      if (other.id == action.id) continue;
      if (other.amount.resolvedAmount != null) {
        deductions.add(other.amount.resolvedAmount!);
      } else if (other.amount.fixedAmount != null) {
        deductions.add(other.amount.fixedAmount!);
      }
    }

    final remainder = FinancialContextService.calculateRemainder(total, deductions);

    return action.copyWith(
      amount: action.amount.copyWith(
        resolvedAmount: remainder,
        knowledgeState: EntityKnowledgeState.known,
      ),
      description:
          'Put remaining balance ${remainder.toFormattedString()} in ${action.destination?.displayName ?? 'USD Savings'}',
    );
  }
}
