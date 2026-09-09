import 'dart:math' as math;
import '../../money/currency.dart';
import '../../money/money.dart';
import '../models/financial_entities.dart';
import '../models/financial_intent_types.dart';

/// FlowPay Financial Intent Engine
/// Parses natural language requests into structured intents, extracts financial
/// entities (people, amounts, currencies, destinations, timing), supports
/// multi-action sentences, enforces completeness checking, and links dependencies.
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
        completeness: const CompletenessReport(score: 1.0, detectedActionCount: 1),
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
        completeness: const CompletenessReport(score: 1.0, detectedActionCount: 1),
      );
    }

    // Normalize word numbers like "twenty" -> 20, "thirty" -> 30, etc.
    final normalizedText = _normalizeWordNumbers(text);

    // Check for incoming payment context: "I just got paid $2,000. Keep 30% for tax, send $500 to Mom..."
    final incomingAmount = _extractIncomingAmount(normalizedText);

    // Extract shared wallet constraints (e.g. "from my USD wallet")
    String? sharedSourceWallet;
    final walletMatch = RegExp(r'from (?:my\s+)?([A-Za-z0-9]+)\s+wallet', caseSensitive: false)
        .firstMatch(normalizedText);
    if (walletMatch != null) {
      sharedSourceWallet = '${walletMatch.group(1)!.toUpperCase()} Wallet';
    }

    // Split text into clauses if multi-action:
    // e.g. "send 20 usd to mom and 30 usd to dad"
    // e.g. "send $20 to mom, $30 to dad, and $50 to my brother"
    // e.g. "send 20 dollars to mom and convert 100 euros to dollars"
    // e.g. "send $500 to mom, keep $300 for tax, and send $200 to my designer"
    final clauses = _splitIntoActionClauses(normalizedText);
    final actions = <ActionIntent>[];

    for (int i = 0; i < clauses.length; i++) {
      final clause = clauses[i];
      final action = _parseClause(
        clause,
        '${intentId}_${actions.length + 1}',
        sharedSourceWallet: sharedSourceWallet,
      );
      if (action != null) {
        actions.add(action);
      }
    }

    if (actions.isEmpty) {
      // Fallback: Attempt full-text parse as a single action
      final singleAction = _parseClause(
        normalizedText,
        '${intentId}_1',
        sharedSourceWallet: sharedSourceWallet,
      );
      if (singleAction != null) {
        actions.add(singleAction);
      }
    }

    // Completeness validation: compare detected monetary signals against extracted action count
    final completenessReport = _validateCompleteness(normalizedText, actions);

    // If completeness check indicates missing actions, trigger deterministic repair pass
    final finalActions = completenessReport.isReparseSuggested
        ? _repairExtractedActions(
            normalizedText,
            actions,
            intentId,
            sharedSourceWallet: sharedSourceWallet,
          )
        : actions;

    // Detect dependencies (e.g. "convert 1000 eur to usd and use it to send 500 to mom")
    if (finalActions.length >= 2) {
      final hasDependency = RegExp(r'use it to|and use it to|then use it to', caseSensitive: false)
          .hasMatch(normalizedText);
      if (hasDependency) {
        final convertIdx = finalActions.indexWhere(
            (a) => a.intentType == FinancialIntentType.convertCurrency);
        final sendIdx = finalActions.indexWhere(
            (a) => a.intentType == FinancialIntentType.sendMoney);
        if (convertIdx != -1 && sendIdx != -1 && convertIdx != sendIdx) {
          finalActions[sendIdx] = finalActions[sendIdx].copyWith(
            dependsOn: [finalActions[convertIdx].id],
          );
        }
      }
    }

    final primary =
        finalActions.isNotEmpty ? finalActions.first.intentType : FinancialIntentType.unknown;

    return StructuredIntent(
      id: intentId,
      primaryIntent: primary,
      originalPrompt: text,
      actions: finalActions,
      incomingAmount: incomingAmount,
      confidenceScore: finalActions.isNotEmpty ? 0.95 : 0.4,
      completeness: _validateCompleteness(normalizedText, finalActions),
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

  /// Split multi-action sentences into semantic clauses
  static List<String> _splitIntoActionClauses(String text) {
    // Clean leading context like "I just got paid $2,000."
    String cleaned = text.replaceFirst(
      RegExp(r'^(?:i\s+just\s+got\s+paid\s+[^\.]+\.\s*)', caseSensitive: false),
      '',
    );

    // Strip trailing shared constraint e.g. "from my USD wallet" so it doesn't break clause splits
    cleaned = cleaned.replaceFirst(
      RegExp(r',?\s*(?:from|using)\s+(?:my\s+)?[A-Za-z0-9]+\s+wallet', caseSensitive: false),
      '',
    );

    // Split on delimiters: comma, semicolon, period, and, then, also, plus, as well as, &
    final rawParts = cleaned.split(RegExp(
        r'(?<!\d),(?!\d)|;\s*|\.\s+|\s+(?:and\s+then|then|as\s+well\s+as|and|also|plus|&)\s+',
        caseSensitive: false));

    final result = <String>[];
    for (final part in rawParts) {
      final t = part.trim();
      if (t.isNotEmpty) result.add(t);
    }
    return result;
  }

  /// Parse an individual action clause
  static ActionIntent? _parseClause(
    String clause,
    String actionId, {
    String? sharedSourceWallet,
  }) {
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
      final res = _parseReserveClause(clause, actionId);
      if (res != null) return res;
    }

    // 3. Remainder / Allocate to savings (e.g. "put the rest in savings", "allocate remainder to savings")
    if (lower.contains('the rest') ||
        lower.contains('remainder') ||
        lower.contains('put in savings') ||
        lower.contains('savings')) {
      return _parseRemainderClause(clause, actionId);
    }

    // 4. Convert currency (e.g. "Convert $1,000 to Naira", "convert 100 eur to usd")
    if (lower.contains('convert') || lower.contains('swap')) {
      final conv = _parseConvertClause(clause, actionId);
      if (conv != null) return conv;
    }

    // 5. Send money / Pay beneficiary (e.g. "Send $500 to Mom", "30 usd to dad", "Mom gets $20", "Give Mom 20 dollars")
    final send = _parseSendClause(clause, actionId, sharedSourceWallet: sharedSourceWallet);
    if (send != null) return send;

    return null;
  }

  static ActionIntent? _parseSendClause(
    String clause,
    String actionId, {
    String? sharedSourceWallet,
  }) {
    final amountEntity = _extractAmount(clause);

    // Extract recipient:
    String? recipient;

    // Pattern 1: "Mom gets $20" or "Dad receives $30"
    final getsMatch = RegExp(
      r'^([A-Za-z0-9._%+-]+(?:\s+[A-Za-z0-9]+)?)\s+(?:gets|receives|takes)\s+(?:[\$₦€£GH₵]?[0-9]+|\$[0-9]+)',
      caseSensitive: false,
    ).firstMatch(clause);
    if (getsMatch != null) {
      recipient = getsMatch.group(1)!.trim();
    }

    // Pattern 2: "Give Mom 20 dollars" or "Pay Dad 30"
    if (recipient == null) {
      final giveMatch = RegExp(
        r'^(?:give|pay)\s+([A-Za-z0-9._%+-]+(?:\s+[A-Za-z0-9]+)?)\s+(?:[\$₦€£GH₵]?[0-9]+|\$[0-9]+)',
        caseSensitive: false,
      ).firstMatch(clause);
      if (giveMatch != null) {
        recipient = giveMatch.group(1)!.trim();
      }
    }

    // Pattern 3: Check for EVM address (e.g. "0x3A9a92C1897d2eB6C6a76C2Ef331908C5b38F242")
    if (recipient == null) {
      final addrMatch =
          RegExp(r'(0x[a-fA-F0-9]{40})', caseSensitive: false).firstMatch(clause);
      if (addrMatch != null) {
        recipient = addrMatch.group(1);
      }
    }

    // Pattern 4: Check for "to/for (my )?<recipient>" (e.g. "Send $500 to Mom", "30 usd to dad", "send 80 usd to my sister")
    if (recipient == null) {
      final toMatches = RegExp(
        r'(?:to|for)\s+(?:my\s+|our\s+)?(0x[a-fA-F0-9]{40}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[A-Za-z0-9]+(?:\s+[A-Za-z0-9]+)?)',
        caseSensitive: false,
      ).allMatches(clause);

      for (final match in toMatches) {
        final raw = match.group(1)!.trim();
        final rawLower = raw.toLowerCase();
        // Skip infinitive verbs like "send", "pay", "wire", "transfer", "give", "convert"
        if (RegExp(r'^(?:send|pay|wire|transfer|give|convert|keep|reserve)\b', caseSensitive: false).hasMatch(rawLower)) {
          continue;
        }
        // Avoid capturing reserved words
        if (!['tax', 'taxes', 'savings', 'emergency', 'reserve', 'wallet']
            .contains(rawLower)) {
          recipient = raw
              .replaceFirst(RegExp(r'^(?:my\s+|our\s+)', caseSensitive: false), '')
              .trim();
          break;
        }
      }
    }

    // Pattern 5: "pay/send (my )?<recipient> <amount>" (e.g. "pay my designer $2,000 USD", "send designer 2000")
    if (recipient == null) {
      final payMatch = RegExp(
        r'(?:pay|send)\s+(?:my\s+|our\s+)?(0x[a-fA-F0-9]{40}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[A-Za-z0-9]+(?:\s+[A-Za-z0-9]+)?)\s+(?:[\$₦€£GH₵]?[0-9]+|\$[0-9]+)',
        caseSensitive: false,
      ).firstMatch(clause);
      if (payMatch != null) {
        final raw = payMatch.group(1)!.trim();
        if (!['tax', 'taxes', 'savings', 'emergency', 'reserve', 'wallet']
            .contains(raw.toLowerCase())) {
          recipient = raw
              .replaceFirst(RegExp(r'^(?:my\s+|our\s+)', caseSensitive: false), '')
              .trim();
        }
      }
    }

    // If an amount is detected along with a recipient, or if explicit send/pay verb exists:
    final hasSendVerb = RegExp(r'\b(?:send|pay|wire|transfer|give)\b', caseSensitive: false).hasMatch(clause);
    final hasAmount = amountEntity.knowledgeState == EntityKnowledgeState.known &&
        amountEntity.type != AmountType.unspecified;

    if (recipient == null && !hasSendVerb) {
      return null;
    }

    if (!hasAmount && !hasSendVerb) {
      return null;
    }

    final person = recipient != null
        ? PersonEntity(
            rawInput: recipient,
            knowledgeState: EntityKnowledgeState.unknown, // Unresolved until ContextResolver
          )
        : null;

    final destName = recipient != null ? _capitalize(recipient) : 'recipient';

    return ActionIntent(
      id: 'act_$actionId',
      intentType: FinancialIntentType.sendMoney,
      person: person,
      amount: amountEntity,
      sourceWallet: sharedSourceWallet,
      description: 'Send ${amountEntity.formattedDisplay} to $destName',
    );
  }

  static ActionIntent? _parseReserveClause(String clause, String actionId) {
    final amountEntity = _extractAmount(clause);
    if (amountEntity.knowledgeState != EntityKnowledgeState.known) {
      return null;
    }

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

  static ActionIntent? _parseConvertClause(String clause, String actionId) {
    final amountEntity = _extractAmount(clause);
    if (amountEntity.knowledgeState != EntityKnowledgeState.known) {
      return null;
    }

    // Extract destination currency: e.g. "convert 100 eur to usd", "convert €1,000 to dollars"
    Currency dstCurr = Currency.usd;
    final toMatch = RegExp(r'(?:to|into)\s*(usd|ngn|eur|gbp|mxn|cad|ghs|dollars?|naira|pesos?|cedis?|euros?)',
        caseSensitive: false).firstMatch(clause);

    if (toMatch != null) {
      dstCurr = _detectCurrency(toMatch.group(1)!, null);
    }

    return ActionIntent(
      id: 'act_$actionId',
      intentType: FinancialIntentType.convertCurrency,
      amount: amountEntity,
      destinationCurrency: dstCurr,
      purpose: 'conversion',
      description: 'Convert ${amountEntity.formattedDisplay} to ${dstCurr.code}',
    );
  }

  /// Deterministic Completeness Checker:
  /// Evaluates whether the number of extracted actions accounts for all detected monetary instructions.
  static CompletenessReport _validateCompleteness(String text, List<ActionIntent> actions) {
    final amountMatches = RegExp(
      r'(?:[\$₦€£GH₵]\s*[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?\s*(?:usd|ngn|eur|gbp|mxn|cad|ghs|dollars?|bucks?|naira|pesos?|cedis?|euros?)|[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?\s+(?:to|for)\b)',
      caseSensitive: false,
    ).allMatches(text);

    final targetMatches = RegExp(
      r'(?:to|for)\s+(?:my\s+|our\s+)?([A-Za-z0-9]+)',
      caseSensitive: false,
    ).allMatches(text).where((m) {
      final w = m.group(1)!.toLowerCase();
      return !['send', 'pay', 'wire', 'transfer', 'give', 'convert', 'keep', 'reserve', 'wallet'].contains(w);
    }).toList();

    final detectedCount = math.max(1, math.max(math.max(amountMatches.length, targetMatches.length), actions.length));
    final extractedCount = actions.length;

    final isReparseSuggested = extractedCount < detectedCount;
    final score = isReparseSuggested
        ? (extractedCount / detectedCount).clamp(0.1, 0.9)
        : 1.0;

    return CompletenessReport(
      score: score,
      detectedActionCount: detectedCount,
      unresolvedActionCount: (detectedCount - extractedCount).clamp(0, 99),
      isReparseSuggested: isReparseSuggested,
    );
  }

  /// Deterministic Repair Pass:
  /// Recovers amount-recipient pairs that were skipped during initial clause parsing.
  static List<ActionIntent> _repairExtractedActions(
    String text,
    List<ActionIntent> existing,
    String intentId, {
    String? sharedSourceWallet,
  }) {
    final repaired = List<ActionIntent>.from(existing);

    final pairRegex = RegExp(
      r'(?:[\$₦€£GH₵])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|gbp|mxn|cad|ghs|dollars?|naira|pesos?|cedis?)?\s+(?:to|for)\s+(?:my\s+|our\s+)?([A-Za-z0-9._%+-]+)',
      caseSensitive: false,
    );

    final matches = pairRegex.allMatches(text);
    for (final match in matches) {
      final rawNum = match.group(1)!.replaceAll(',', '');
      final rawCurr = match.group(2);
      final rawTarget = match.group(3)!.trim();
      final curr = _detectCurrency(match.group(0)!, rawCurr);

      // Check if already captured in existing
      final exists = repaired.any((a) =>
          a.amount.fixedAmount != null &&
          a.amount.fixedAmount!.toMajorString() == Money.fromMajorString(rawNum, curr).toMajorString() &&
          ((a.person != null && a.person!.rawInput.toLowerCase() == rawTarget.toLowerCase()) ||
              (a.purpose != null && a.purpose!.toLowerCase() == rawTarget.toLowerCase())));

      if (!exists) {
        final actId = 'act_${intentId}_${repaired.length + 1}';
        final money = Money.fromMajorString(rawNum, curr);
        final amtEntity = AmountEntity(
          rawInput: match.group(0)!.trim(),
          type: AmountType.fixed,
          fixedAmount: money,
          currency: curr,
          knowledgeState: EntityKnowledgeState.known,
        );

        if (rawTarget.toLowerCase() == 'tax' || rawTarget.toLowerCase() == 'taxes') {
          repaired.add(
            ActionIntent(
              id: actId,
              intentType: FinancialIntentType.createReserve,
              destination: const DestinationEntity(
                type: DestinationType.reserve,
                rawInput: 'Tax Reserve',
                knowledgeState: EntityKnowledgeState.unknown,
              ),
              amount: amtEntity,
              purpose: 'tax',
              description: 'Reserve ${amtEntity.formattedDisplay} for tax',
            ),
          );
        } else {
          repaired.add(
            ActionIntent(
              id: actId,
              intentType: FinancialIntentType.sendMoney,
              person: PersonEntity(
                rawInput: rawTarget,
                knowledgeState: EntityKnowledgeState.unknown,
              ),
              amount: amtEntity,
              sourceWallet: sharedSourceWallet,
              description: 'Send ${amtEntity.formattedDisplay} to ${_capitalize(rawTarget)}',
            ),
          );
        }
      }
    }

    return repaired;
  }

  /// Normalizes written word numbers into digits
  static String _normalizeWordNumbers(String text) {
    const map = {
      'zero': '0',
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
      'twenty': '20',
      'thirty': '30',
      'forty': '40',
      'fifty': '50',
      'sixty': '60',
      'seventy': '70',
      'eighty': '80',
      'ninety': '90',
      'hundred': '100',
      'thousand': '1000',
    };

    var res = text;
    for (final entry in map.entries) {
      res = res.replaceAll(
          RegExp('\\b${entry.key}\\b', caseSensitive: false), entry.value);
    }
    return res;
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
    final pctMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent)', caseSensitive: false)
        .firstMatch(clause);
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
      r'(?:[\$₦€£GH₵])?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|gbp|mxn|cad|ghs|dollars?|bucks?|naira|pesos?|cedis?|euros?)?',
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
    if (combined.contains('ghs') || combined.contains('cedi') || combined.contains('gh₵')) {
      return Currency.ghs;
    }
    // Default to USD for $, dollars, or general numbers
    return Currency.usd;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
