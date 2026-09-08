import 'package:flutter/foundation.dart';
import '../beneficiaries/beneficiary_model.dart';
import '../money/currency.dart';
import '../money/money.dart';
import 'models/financial_entities.dart';
import 'models/financial_intent_types.dart';
import 'models/financial_plan_models.dart';
import 'models/operator_session_models.dart';
import 'services/clarification_engine.dart';
import 'services/context_resolver.dart';
import 'services/execution_provider.dart';
import 'services/financial_context_service.dart';
import 'services/financial_intent_engine.dart';
import 'services/financial_planner.dart';

/// FlowPay Financial Operator
/// Central intelligent agent coordinating the entire interpretation, entity
/// resolution, clarification, deterministic planning, and execution authorization pipeline.
class FinancialOperator extends ChangeNotifier {
  final FinancialContextService contextService;
  final FinancialExecutionProvider executionProvider;
  late final ContextResolver _contextResolver;
  late final FinancialPlanner _planner;

  OperatorSession _session;

  FinancialOperator({
    required this.contextService,
    required this.executionProvider,
  }) : _session = OperatorSession(
          sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
          status: OperatorSessionStatus.idle,
        ) {
    _contextResolver = ContextResolver(contextService: contextService);
    _planner = FinancialPlanner(contextService: contextService);
  }

  OperatorSession get session => _session;
  OperatorSessionStatus get status => _session.status;
  List<OperatorMessage> get messages => _session.messages;
  FinancialPlan? get activePlan => _session.activePlan;
  ClarificationPrompt? get pendingClarification => _session.pendingClarification;

  /// Start or reset a conversation session
  void startNewSession([String? initialPrompt]) {
    _session = OperatorSession(
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      status: OperatorSessionStatus.idle,
      messages: [],
    );
    notifyListeners();

    if (initialPrompt != null && initialPrompt.trim().isNotEmpty) {
      processInput(initialPrompt.trim());
    }
  }

  /// Process natural language input from user
  Future<void> processInput(String rawInput) async {
    final text = rawInput.trim();
    if (text.isEmpty) return;

    // 1. Record user message
    final userMsg = OperatorMessage.user(text);
    _session = _session.copyWith(
      messages: [..._session.messages, userMsg],
    );
    notifyListeners();

    try {
      // 2. Handle waiting for clarification state
      if (_session.status == OperatorSessionStatus.waitingForClarification &&
          _session.pendingClarification != null) {
        await _handleClarificationResponse(text);
        return;
      }

      // 3. Handle ready for review state
      if (_session.status == OperatorSessionStatus.readyForReview &&
          _session.activePlan != null) {
        final lower = text.toLowerCase();
        if (lower == 'approve' || lower == 'confirm' || lower == 'proceed' || lower == 'yes') {
          // Will prompt PIN in UI or execute with demo PIN
          await approveAndExecute(pin: '123456');
          return;
        } else if (lower == 'cancel' || lower == 'reject' || lower == 'no') {
          cancelSession();
          return;
        }
      }

      // 4. Initial interpretation of a new request
      _session = _session.copyWith(status: OperatorSessionStatus.interpreting);
      notifyListeners();

      // Handle quick balance / transaction queries directly
      final parsedIntent = FinancialIntentEngine.parse(text);

      if (parsedIntent.primaryIntent == FinancialIntentType.checkBalance) {
        await _handleBalanceCheck();
        return;
      }

      if (parsedIntent.primaryIntent == FinancialIntentType.viewTransactions) {
        await _handleTransactionCheck();
        return;
      }

      // Resolve entities against application state
      final resolvedIntent = await _contextResolver.resolve(parsedIntent);
      _session = _session.copyWith(activeIntent: resolvedIntent);

      // Evaluate for missing or ambiguous information
      final clarification =
          ClarificationEngine.evaluateClarification(resolvedIntent);

      if (clarification != null) {
        // Need clarification before planning
        final promptMsg = OperatorMessage.operator(
          clarification.question,
          clarification: clarification,
        );
        _session = _session.copyWith(
          status: OperatorSessionStatus.waitingForClarification,
          pendingClarification: clarification,
          messages: [..._session.messages, promptMsg],
        );
        notifyListeners();
        return;
      }

      // If all entities are known, compile the plan!
      await _compileAndPresentPlan(resolvedIntent);
    } catch (err) {
      final errorMsg = OperatorMessage.operator(
        'I encountered an issue while processing your request: $err. Please try rephrasing or specify the amount and recipient directly.',
        isError: true,
      );
      _session = _session.copyWith(
        status: OperatorSessionStatus.error,
        messages: [..._session.messages, errorMsg],
      );
      notifyListeners();
    }
  }

  /// Handle clarification response when user types an answer
  Future<void> _handleClarificationResponse(String answer) async {
    try {
      final prompt = _session.pendingClarification!;
      final intent = _session.activeIntent;
      if (intent == null) return;

      final updatedActions = <ActionIntent>[];

      for (final act in intent.actions) {
        if (act.id == prompt.targetActionId) {
          if (prompt.field == 'recipient') {
            // Resolve beneficiary from answer
            // e.g. "Mary, my Nigerian beneficiary" -> extracts Mary or resolves
            final beneficiaryQuery = _extractBeneficiaryName(answer);
            final res = await contextService.resolveBeneficiary(beneficiaryQuery);

            Beneficiary? match = res.match;
            if (match == null && res.candidates.isNotEmpty) {
              match = res.candidates.first;
            }

            // If still null, check if any existing beneficiary matches Nigeria / Mary
            if (match == null) {
              final all = await contextService.getBeneficiaries();
              for (final b in all) {
                if (answer.toLowerCase().contains(b.legalName.toLowerCase()) ||
                    answer.toLowerCase().contains(b.nickname.toLowerCase()) ||
                    (answer.toLowerCase().contains('nigeria') &&
                        b.destinationCountry.toLowerCase().contains('nigeria'))) {
                  match = b;
                  break;
                }
              }
            }

            if (match != null) {
              updatedActions.add(
                act.copyWith(
                  person: PersonEntity(
                    rawInput: match.legalName,
                    resolvedBeneficiary: match,
                    knowledgeState: EntityKnowledgeState.known,
                    aliasMatched: match.nickname,
                  ),
                  description:
                      'Send ${act.amount.formattedDisplay} to ${match.legalName} (${match.nickname})',
                ),
              );
            } else {
              // Cannot resolve: ask again
              final retryMsg = OperatorMessage.operator(
                'I still couldn\'t find a beneficiary matching "$answer". Please choose from your existing contacts or add them first.',
                clarification: prompt,
              );
              _session = _session.copyWith(
                messages: [..._session.messages, retryMsg],
              );
              notifyListeners();
              return;
            }
          } else if (prompt.field == 'destination') {
            // Resolve destination from answer: e.g. "Put it in my USD savings"
            String destName = 'USD Savings';
            if (answer.toLowerCase().contains('create')) {
              destName = 'Tax Reserve';
            } else if (answer.toLowerCase().contains('wallet')) {
              destName = 'USD Wallet';
            }

            final usdWallet =
                await contextService.getWalletForCurrency(Currency.usd);

            updatedActions.add(
              act.copyWith(
                destination: DestinationEntity(
                  type: DestinationType.reserve,
                  rawInput: destName,
                  resolvedWalletId: usdWallet?.id ?? 'sw_demo_usdb_01',
                  resolvedWalletName: destName,
                  resolvedCurrency: Currency.usd,
                  knowledgeState: EntityKnowledgeState.known,
                ),
                description: 'Reserve ${act.amount.formattedDisplay} in $destName',
              ),
            );
          } else if (prompt.field == 'amount') {
            final amtClean = answer.replaceAll(RegExp(r'[^0-9.]'), '');
            final money = Money.fromMajorString(amtClean, Currency.usd);
            updatedActions.add(
              act.copyWith(
                amount: AmountEntity(
                  rawInput: answer,
                  type: AmountType.fixed,
                  fixedAmount: money,
                  currency: Currency.usd,
                  knowledgeState: EntityKnowledgeState.known,
                ),
              ),
            );
          } else {
            updatedActions.add(act);
          }
        } else {
          updatedActions.add(act);
        }
      }

      final newIntent = intent.copyWith(actions: updatedActions);
      _session = _session.copyWith(
        activeIntent: newIntent,
        clearPendingClarification: true,
      );

      // Re-evaluate if any other actions need clarification
      final nextClarification =
          ClarificationEngine.evaluateClarification(newIntent);

      if (nextClarification != null) {
        final promptMsg = OperatorMessage.operator(
          'Got it. ${nextClarification.question}',
          clarification: nextClarification,
        );
        _session = _session.copyWith(
          status: OperatorSessionStatus.waitingForClarification,
          pendingClarification: nextClarification,
          messages: [..._session.messages, promptMsg],
        );
        notifyListeners();
        return;
      }

      // All clear! Compile the plan
      await _compileAndPresentPlan(newIntent);
    } catch (err) {
      final errorMsg = OperatorMessage.operator(
        'I encountered an error during clarification: $err. Please try again.',
        isError: true,
      );
      _session = _session.copyWith(
        status: OperatorSessionStatus.error,
        messages: [..._session.messages, errorMsg],
      );
      notifyListeners();
    }
  }

  /// Handle 1-tap clarification option selection
  Future<void> selectClarificationOption(
    ClarificationPrompt prompt,
    ClarificationOptionData option,
  ) async {
    // Treat the option value as the answer
    await processInput(option.value);
  }

  /// Compile structured intent into a validated FinancialPlan and present for review
  Future<void> _compileAndPresentPlan(StructuredIntent intent) async {
    final plan = await _planner.createPlan(intent);

    if (!plan.validation.isValid) {
      // Deterministic validation failed
      final errorBuffer = StringBuffer();
      errorBuffer.writeln('I cannot proceed with this plan because:');
      for (final err in plan.validation.errors) {
        errorBuffer.writeln('• $err');
      }
      final errorMsg = OperatorMessage.operator(
        errorBuffer.toString(),
        isError: true,
      );
      _session = _session.copyWith(
        status: OperatorSessionStatus.error,
        activePlan: plan,
        messages: [..._session.messages, errorMsg],
      );
      notifyListeners();
      return;
    }

    // Plan is valid! Present structured plan review
    final explanation = StringBuffer();
    explanation.writeln('Here\'s what I\'ll do:\n');
    for (int i = 0; i < plan.actions.length; i++) {
      final act = plan.actions[i];
      explanation.writeln('${i + 1}. ${act.type.displayName} ${act.amount.toFormattedString()} to ${act.destinationName}.');
    }
    explanation.writeln('\nReview and approve?');

    final planMsg = OperatorMessage.operator(
      explanation.toString().trim(),
      plan: plan,
    );

    _session = _session.copyWith(
      status: OperatorSessionStatus.readyForReview,
      activePlan: plan,
      messages: [..._session.messages, planMsg],
    );
    notifyListeners();
  }

  /// Approve plan and trigger on-device PIN execution
  Future<void> approveAndExecute({required String pin}) async {
    if (_session.activePlan == null || !_session.activePlan!.validation.isValid) {
      return;
    }

    _session = _session.copyWith(status: OperatorSessionStatus.executing);
    notifyListeners();

    final plan = _session.activePlan!;
    final result = await executionProvider.executePlan(plan, pin: pin);

    if (result.success) {
      final completedPlan = plan.copyWith(
        isApproved: true,
        executionState: 'COMPLETED',
        txHash: result.txHash,
      );

      final successMsg = OperatorMessage.operator(
        'Execution completed successfully!\nTx: ${result.txHash.substring(0, 10)}...',
        plan: completedPlan,
        executionReceipt: {
          'txHash': result.txHash,
          'timestamp': result.timestamp.toIso8601String(),
          'totalDebit': plan.totalDebit.toFormattedString(),
          'actionsCount': result.executedActionsCount,
        },
      );

      _session = _session.copyWith(
        status: OperatorSessionStatus.completed,
        activePlan: completedPlan,
        messages: [..._session.messages, successMsg],
      );
    } else {
      final errorMsg = OperatorMessage.operator(
        'Execution failed: ${result.errorMessage}',
        isError: true,
      );
      _session = _session.copyWith(
        status: OperatorSessionStatus.error,
        messages: [..._session.messages, errorMsg],
      );
    }
    notifyListeners();
  }

  /// Cancel current active session
  void cancelSession() {
    final cancelMsg = OperatorMessage.operator('Operation cancelled.');
    _session = _session.copyWith(
      status: OperatorSessionStatus.rejected,
      messages: [..._session.messages, cancelMsg],
      clearPendingClarification: true,
    );
    notifyListeners();
  }

  Future<void> _handleBalanceCheck() async {
    final wallets = await contextService.getWallets();
    final buffer = StringBuffer();
    buffer.writeln('Here are your current verified balances:');
    for (final w in wallets) {
      buffer.writeln('• ${w.currency.code}: ${w.balance.toFormattedString()} (${w.stablecoinToken})');
    }
    final msg = OperatorMessage.operator(buffer.toString().trim());
    _session = _session.copyWith(
      status: OperatorSessionStatus.idle,
      messages: [..._session.messages, msg],
    );
    notifyListeners();
  }

  Future<void> _handleTransactionCheck() async {
    final txs = await contextService.getTransactions();
    final buffer = StringBuffer();
    if (txs.isEmpty) {
      buffer.writeln('No recent transactions found in your activity ledger.');
    } else {
      buffer.writeln('Here is your recent activity:');
      for (final tx in txs.take(4)) {
        buffer.writeln(
            '• ${tx.title} — ${tx.amount?.toFormattedString() ?? ''}');
      }
    }
    final msg = OperatorMessage.operator(buffer.toString().trim());
    _session = _session.copyWith(
      status: OperatorSessionStatus.idle,
      messages: [..._session.messages, msg],
    );
    notifyListeners();
  }

  static String _extractBeneficiaryName(String answer) {
    // Clean strings like "She's Mary from Nigeria" or "Mary, my Nigerian beneficiary"
    String text = answer;
    text = text.replaceFirst(RegExp(r'^(?:she(?: is|\x27s)|he(?: is|\x27s)|it(?: is|\x27s)|that(?: is|\x27s))\s+', caseSensitive: false), '');
    final commaSplit = text.split(RegExp(r'[,;]|\s+from\s+|\s+my\s+'));
    return commaSplit.first.trim();
  }
}
