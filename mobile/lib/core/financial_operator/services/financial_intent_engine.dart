import '../../money/currency.dart';
import '../../money/money.dart';
import '../models/financial_entities.dart';
import '../models/financial_intent_types.dart';

/// FlowPay Financial Intent Engine
/// Parses natural language requests into structured intents, extracts financial
/// entities (people, amounts, currencies, destinations, timing), and supports
/// multi-action sentences.
class FinancialIntentEngine {
  /// Parse natural language input into a StructuredIntent
  static StructuredIntent parse(String prompt) {
    final text = prompt.trim();
    final intentId =
        'intent_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode.abs().toString().substring(0, 4)}';

    // Check for conversational / informational queries
    if (_isBalanceCheck(text)) {
      return StructuredIntent(
        id: intentId,
        primaryIntent: FinancialIntentType.checkBalance,
        originalPrompt: text,
        actions: [
          ActionIntent(
            id: 'act_${intentId}_1',
            intentType: FinancialIntentType.checkBalance,
            amount: const AmountEntity(
                rawInput: '0',
                type: AmountType.unspecified,
                knowledgeState: EntityKnowledgeState.known),
            description: 'Check available balances across all currency rails',
          ),
        ],
        confidenceScore: 0.98,
      );
    }

    if (_isTransactionCheck(text)) {
      return StructuredIntent(
        id: intentId,
        primaryIntent: FinancialIntentType.viewTransactions,
        originalPrompt: text,
        actions: [
          ActionIntent(
            id: 'act_${intentId}_1',
            intentType: FinancialIntentType.viewTransactions,
            amount: const AmountEntity(
                rawInput: '0',
                type: AmountType.unspecified,
                knowledgeState: EntityKnowledgeState.known),
            description: 'View recent financial activity ledger',
          ),
        ],
        confidenceScore: 0.95,
      );
    }

    // Check for incoming payment context: "I just got paid $2,000. Keep 30% for tax, send $500 to Mom..."
    final incomingAmount = _extractIncomingAmount(text);

    // Split text into clauses if multi-action:
    // e.g. "Send 500 usd to mom, keep 300 usd for tax"
    // e.g. "keep 30% for tax, send $500 to Mom and put the rest in savings"
    final clauses = _splitIntoActionClauses(text);
    final actions = <ActionIntent>[];

    for (int i = 0; i < clauses.length; i++) {
      final clause = clauses[i];
      final action = _parseClause(clause, '${intentId}_${i + 1}');
      if (action != null) {
        actions.add(action);
      }
    }

    if (actions.isEmpty) {
      // Fallback: Attempt full-text parse as a single action
      final singleAction = _parseClause(text, '${intentId}_1');
      if (singleAction != null) {
        actions.add(singleAction);
      }
    }

    final primary =
        actions.isNotEmpty ? actions.first.intentType : FinancialIntentType.unknown;

    return StructuredIntent(
      id: intentId,
      primaryIntent: primary,
      originalPrompt: text,
      actions: actions,
      incomingAmount: incomingAmount,
      confidenceScore: actions.isNotEmpty ? 0.92 : 0.4,
    );
  }

  static bool _isBalanceCheck(String text) {
    final lower = text.toLowerCase();
    return lower.contains('balance') ||
        lower.contains('how much do i have') ||
        lower.contains('my funds');
  }

  static bool _isTransactionCheck(String text) {
    final lower = text.toLowerCase();
    return lower.contains('transaction') ||
        lower.contains('activity') ||
        lower.contains('history') ||
        lower.contains('recent spend');
  }

  static AmountEntity? _extractIncomingAmount(String text) {
    final match = RegExp(
      r'(?:got\s+paid|received|incoming|deposited)\s+(?:(?:an?\s+amount\s+of\s+)?)([\$₦€£]?[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|gbp|mxn|cad|dollars?|naira|pesos?)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      final rawNum = match.group(1)!;
      final rawCurr = match.group(2);
      final currency = _detectCurrency(rawNum, rawCurr);
      final cleanNum = rawNum.replaceAll(RegExp(r'[\$₦€£,]'), '');
      try {
        final money = Money.fromMajorString(cleanNum, currency);
        return AmountEntity(
          rawInput: match.group(0)!,
          type: AmountType.fixed,
          fixedAmount: money,
          currency: currency,
          knowledgeState: EntityKnowledgeState.known,
        );
      } catch (_) {}
    }
    return null;
  }

  /// Split multi-action sentences into manageable semantic clauses
  static List<String> _splitIntoActionClauses(String text) {
    // Clean leading context like "I just got paid $2,000."
    String cleaned = text.replaceFirst(
      RegExp(r'^(?:i\s+just\s+got\s+paid\s+[^\.]+\.\s*)', caseSensitive: false),
      '',
    );

    // Split on delimiters: comma (not inside a number), semicolon, "and", "then"
    final rawParts = cleaned.split(
        RegExp(r'(?<!\d),(?!\d)|;\s*|\s+and\s+|\s+then\s+', caseSensitive: false));
    final result = <String>[];
    for (final part in rawParts) {
      final t = part.trim();
      if (t.isNotEmpty) result.add(t);
    }
    return result;
  }

  /// Parse an individual action clause
  static ActionIntent? _parseClause(String clause, String actionId) {
    final lower = clause.toLowerCase();

    // 1. Mission creation rule (e.g. "Whenever I get paid...", "every time...")
    if (lower.startsWith('whenever') ||
        lower.startsWith('every time') ||
        lower.contains('auto-sweep') ||
        lower.contains('rule')) {
      return _parseMissionClause(clause, actionId);
    }

    // 2. Reserve action (e.g. "keep $300 for tax", "reserve $300 for tax", "save $200 for emergency")
    if (lower.contains('keep') ||
        lower.contains('reserve') ||
        lower.contains('tax') ||
        lower.contains('aside')) {
      return _parseReserveClause(clause, actionId);
    }

    // 3. Remainder / Allocate to savings (e.g. "put the rest in savings", "allocate remainder to savings")
    if (lower.contains('the rest') ||
        lower.contains('remainder') ||
        lower.contains('put in savings') ||
        lower.contains('savings')) {
      return _parseRemainderClause(clause, actionId);
    }

    // 4. Send money / Pay beneficiary (e.g. "Send $500 to Mom", "Pay 500 dollars to Mary")
    if (lower.contains('send') ||
        lower.contains('pay') ||
        lower.contains('transfer') ||
        lower.contains('wire')) {
      return _parseSendClause(clause, actionId);
    }

    // 5. Convert currency (e.g. "Convert $1,000 to Naira")
    if (lower.contains('convert') || lower.contains('swap')) {
      return _parseConvertClause(clause, actionId);
    }

    return null;
  }

  static ActionIntent _parseSendClause(String clause, String actionId) {
    final amountEntity = _extractAmount(clause);

    // Extract recipient: e.g. "to Mom", "to Mary Fashola", "to my designer"
    String? recipient;
    final toMatch = RegExp(r'(?:to|for)\s+([A-Za-z0-9._%+-]+(?:@[A-Za-z0-9.-]+\.[A-Za-z]{2,})?|[A-Za-z]+(?:\s+[A-Za-z]+)?)', caseSensitive: false)
        .firstMatch(clause);

    if (toMatch != null) {
      final raw = toMatch.group(1)!.trim();
      // Avoid capturing words like "tax" or "savings" as recipient
      if (!['tax', 'savings', 'emergency', 'reserve', 'wallet'].contains(raw.toLowerCase())) {
        recipient = raw.replaceFirst(RegExp(r'^(?:my\s+)', caseSensitive: false), '');
      }
    }

    final person = recipient != null
        ? PersonEntity(
            rawInput: recipient,
            knowledgeState: EntityKnowledgeState.unknown, // Unresolved until ContextResolver
          )
        : null;

    return ActionIntent(
      id: 'act_$actionId',
      intentType: FinancialIntentType.sendMoney,
      person: person,
      amount: amountEntity,
      description: 'Send ${amountEntity.formattedDisplay} to ${recipient ?? 'recipient'}',
    );
  }

  static ActionIntent _parseReserveClause(String clause, String actionId) {
    final amountEntity = _extractAmount(clause);

    // Purpose detection: tax, emergency, savings
    String purpose = 'reserve';
    final lower = clause.toLowerCase();
    if (lower.contains('tax')) {
      purpose = 'tax';
    } else if (lower.contains('emergency')) {
      purpose = 'emergency';
    } else if (lower.contains('savings')) {
      purpose = 'savings';
    }

    return ActionIntent(
      id: 'act_$actionId',
      intentType: FinancialIntentType.createReserve,
      destination: DestinationEntity(
        type: DestinationType.reserve,
        rawInput: purpose == 'tax' ? 'Tax Reserve' : purpose,
        knowledgeState: EntityKnowledgeState.unknown, // Resolved against reserves catalogue
      ),
      amount: amountEntity,
      purpose: purpose,
      description: 'Reserve ${amountEntity.formattedDisplay} for $purpose',
    );
  }

  static ActionIntent _parseRemainderClause(String clause, String actionId) {
    // Destination: savings, spending wallet, emergency fund
    String destinationName = 'USD Savings';
    final lower = clause.toLowerCase();
    if (lower.contains('spending')) {
      destinationName = 'Spending Wallet';
    } else if (lower.contains('emergency')) {
      destinationName = 'Emergency Fund';
    } else if (lower.contains('savings')) {
      destinationName = 'USD Savings';
    }

    const amountEntity = AmountEntity(
      rawInput: 'the rest',
      type: AmountType.remainder,
      knowledgeState: EntityKnowledgeState.known,
    );

    return ActionIntent(
      id: 'act_$actionId',
      intentType: FinancialIntentType.allocateMoney,
      destination: DestinationEntity(
        type: DestinationType.wallet,
        rawInput: destinationName,
        knowledgeState: EntityKnowledgeState.unknown,
      ),
      amount: amountEntity,
      purpose: 'savings',
      description: 'Put remaining balance in $destinationName',
    );
  }

  static ActionIntent _parseMissionClause(String clause, String actionId) {
    final amountEntity = _extractAmount(clause);
    return ActionIntent(
      id: 'act_$actionId',
      intentType: FinancialIntentType.createMission,
      amount: amountEntity,
      purpose: 'mission',
      description: 'Automated Money Mission: $clause',
    );
  }

  static ActionIntent _parseConvertClause(String clause, String actionId) {
    final amountEntity = _extractAmount(clause);
    return ActionIntent(
      id: 'act_$actionId',
      intentType: FinancialIntentType.convertCurrency,
      amount: amountEntity,
      purpose: 'conversion',
      description: 'Convert ${amountEntity.formattedDisplay}',
    );
  }

  /// Extract amount entity from clause
  static AmountEntity _extractAmount(String clause) {
    final lower = clause.toLowerCase();

    // Check for "half"
    if (lower.contains('half')) {
      final curr = _detectCurrency(clause, null);
      return AmountEntity(
        rawInput: 'half',
        type: AmountType.half,
        percentage: 50.0,
        currency: curr,
        knowledgeState: EntityKnowledgeState.known,
      );
    }

    // Check for percentage (e.g. "30%", "30 percent")
    final pctMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent)', caseSensitive: false).firstMatch(clause);
    if (pctMatch != null) {
      final pct = double.tryParse(pctMatch.group(1)!) ?? 0.0;
      final curr = _detectCurrency(clause, null);
      return AmountEntity(
        rawInput: '${pct.toStringAsFixed(0)}%',
        type: AmountType.percentage,
        percentage: pct,
        currency: curr,
        knowledgeState: EntityKnowledgeState.known,
      );
    }

    // Check for numeric amount: $500, 500 usd, ₦300,000, 500 dollars
    final numMatch = RegExp(
      r'(?:[\$₦€£])?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|gbp|mxn|cad|ghs|dollars?|bucks?|naira|pesos?|cedis?)?',
      caseSensitive: false,
    ).firstMatch(clause);

    if (numMatch != null) {
      final rawNum = numMatch.group(1)!;
      final rawCurr = numMatch.group(2);
      final currency = _detectCurrency(numMatch.group(0)!, rawCurr);
      final cleanNum = rawNum.replaceAll(',', '');
      try {
        final money = Money.fromMajorString(cleanNum, currency);
        return AmountEntity(
          rawInput: numMatch.group(0)!.trim(),
          type: AmountType.fixed,
          fixedAmount: money,
          currency: currency,
          knowledgeState: EntityKnowledgeState.known,
        );
      } catch (_) {}
    }

    return const AmountEntity(
      rawInput: '',
      type: AmountType.unspecified,
      knowledgeState: EntityKnowledgeState.unknown,
    );
  }

  static Currency _detectCurrency(String text, String? currencyHint) {
    final combined = '${text.toLowerCase()} ${currencyHint?.toLowerCase() ?? ''}';
    if (combined.contains('₦') || combined.contains('ngn') || combined.contains('naira')) {
      return Currency.ngn;
    }
    if (combined.contains('€') || combined.contains('eur') || combined.contains('euro')) {
      return Currency.eur;
    }
    if (combined.contains('£') || combined.contains('gbp') || combined.contains('pound')) {
      return Currency.gbp;
    }
    if (combined.contains('mxn') || combined.contains('peso')) {
      return Currency.mxn;
    }
    if (combined.contains('cad')) {
      return Currency.cad;
    }
    // Default to USD for $, dollars, or general numbers
    return Currency.usd;
  }
}
