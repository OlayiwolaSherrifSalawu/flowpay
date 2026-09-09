import '../models/financial_entities.dart';
import '../models/financial_intent_types.dart';
import '../models/operator_session_models.dart';

/// FlowPay Clarification Engine
/// Evaluates structured intents for missing, unknown, or ambiguous entities.
/// Adheres strictly to:
/// - Directive #10: Only ask questions that are actually necessary.
/// - Directive #26: Natural, conversational clarification with structured 1-tap options.
class ClarificationEngine {
  /// Check if the intent requires clarification, and if so, return the next prompt
  static ClarificationPrompt? evaluateClarification(StructuredIntent intent) {
    for (final action in intent.actions) {
      // Skip internal wallet-to-wallet transfers / conversions
      if (action.isInternalTransfer) {
        continue;
      }

      // 1. Check for Person / Recipient issues
      if (action.person != null) {
        final rawPerson = action.person!.rawInput.trim().toLowerCase();
        if (rawPerson.contains('wallet') ||
            ['usd', 'dollars', 'dollar', 'naira', 'ngn', 'cngn', 'pesos', 'peso', 'mxn', 'euros', 'euro', 'eur', 'cad', 'gbp', 'pounds']
                .contains(rawPerson)) {
          continue;
        }

        final otherResolvedNames = intent.actions
            .where((a) =>
                a.id != action.id &&
                a.person?.knowledgeState == EntityKnowledgeState.known &&
                a.person?.resolvedBeneficiary != null)
            .map((a) => a.person!.resolvedBeneficiary!.nickname.isNotEmpty
                ? a.person!.resolvedBeneficiary!.nickname
                : a.person!.resolvedBeneficiary!.legalName)
            .toList();

        if (action.person!.knowledgeState == EntityKnowledgeState.unknown) {
          final raw = action.person!.rawInput.trim();
          final prefix = otherResolvedNames.isNotEmpty
              ? 'I found ${otherResolvedNames.join(", ")}, but '
              : '';
          final title = raw.isNotEmpty
              ? '$prefix${prefix.isEmpty ? "Who" : "who"} is $raw?'
              : 'Who should receive this transfer?';
          return ClarificationPrompt(
            id: 'clarify_recipient_${action.id}',
            targetActionId: action.id,
            field: 'recipient',
            question: title,
            description: 'Choose an option or reply naturally with their name and country.',
            options: [
              const ClarificationOptionData(
                id: 'add_new',
                label: 'Add New Beneficiary',
                subtitle: 'Register new account or address',
                value: 'ADD_BENEFICIARY',
              ),
              const ClarificationOptionData(
                id: 'choose_existing',
                label: 'Choose Existing Contact',
                subtitle: 'Select from verified beneficiaries',
                value: 'CHOOSE_EXISTING',
              ),
            ],
          );
        } else if (action.person!.knowledgeState == EntityKnowledgeState.ambiguous) {
          final count = action.person!.candidates.length;
          final prefix = otherResolvedNames.isNotEmpty
              ? 'I found ${otherResolvedNames.join(", ")}, but there are '
              : 'I found ';
          final amtStr = action.amount.formattedDisplay;
          final question = otherResolvedNames.isNotEmpty
              ? '$prefix$count contacts matching ${action.person!.rawInput}. Which ${action.person!.rawInput} should receive $amtStr?'
              : 'I found $count beneficiaries matching "${action.person!.rawInput}". Which one do you mean?';

          return ClarificationPrompt(
            id: 'clarify_ambiguous_${action.id}',
            targetActionId: action.id,
            field: 'recipient',
            question: question,
            description: 'Select the intended recipient to prevent accidental transfers.',
            options: action.person!.candidates.map((c) {
              return ClarificationOptionData(
                id: c.id,
                label: '${c.legalName} (${c.nickname})',
                subtitle: '${c.accountOrAddress} • ${c.destinationCountry} ${c.countryFlag}',
                value: c.legalName,
              );
            }).toList(),
            disambiguationCandidates: action.person!.candidates
                .map((c) => PersonEntity(
                      rawInput: c.legalName,
                      resolvedBeneficiary: c,
                      knowledgeState: EntityKnowledgeState.known,
                    ))
                .toList(),
          );
        }
      }

      // 2. Check for Mission Reserve Destination
      if (action.intentType == FinancialIntentType.createMission &&
          (action.destination == null ||
              action.destination!.knowledgeState != EntityKnowledgeState.known)) {
        final amountText = action.amount.type == AmountType.percentage &&
                action.amount.percentage != null
            ? '${action.amount.percentage!.toStringAsFixed(0)}%'
            : action.amount.formattedDisplay;
        return ClarificationPrompt(
          id: 'clarify_mission_dest_${action.id}',
          targetActionId: action.id,
          field: 'mission_destination',
          question:
              'Got it. Whenever USD arrives, I\'ll reserve $amountText. Where should the $amountText go — your Tax Reserve, Emergency Reserve, or General Savings?',
          description:
              'Choose a reserve destination or reply naturally (e.g. "Save it for taxes").',
          options: [
            const ClarificationOptionData(
              id: 'tax_reserve',
              label: 'Tax Reserve',
              subtitle: 'Automated tax withholding vault',
              value: 'Tax Reserve',
            ),
            const ClarificationOptionData(
              id: 'emergency_reserve',
              label: 'Emergency Reserve',
              subtitle: 'Emergency buffer fund',
              value: 'Emergency Fund',
            ),
            const ClarificationOptionData(
              id: 'general_savings',
              label: 'General Savings',
              subtitle: 'USD Savings vault',
              value: 'USD Savings',
            ),
          ],
        );
      }

      // 3. Check for Destination (Wallet / Reserve) issues
      if (action.destination != null &&
          action.destination!.knowledgeState != EntityKnowledgeState.known) {
        final raw = action.destination!.rawInput.trim();
        final amountText = action.amount.formattedDisplay;
        final purpose = action.purpose ?? 'funds';

        return ClarificationPrompt(
          id: 'clarify_destination_${action.id}',
          targetActionId: action.id,
          field: 'destination',
          question: 'Where should I keep the $amountText $purpose reserve?',
          description:
              'You mentioned keeping $amountText for $purpose, but I don\'t have a destination set up yet.',
          options: [
            const ClarificationOptionData(
              id: 'usd_savings',
              label: 'USD Savings',
              subtitle: 'Safe multi-currency vault',
              value: 'USD Savings',
            ),
            ClarificationOptionData(
              id: 'create_reserve',
              label: 'Create $raw',
              subtitle: 'Provision a dedicated $purpose reserve',
              value: 'Create $raw',
            ),
            const ClarificationOptionData(
              id: 'usd_wallet',
              label: 'Primary USD Wallet',
              subtitle: 'Keep in active balance',
              value: 'USD Wallet',
            ),
          ],
        );
      }

      // 3. Check for Amount issues
      if (action.amount.knowledgeState != EntityKnowledgeState.known &&
          action.amount.type == AmountType.unspecified) {
        return ClarificationPrompt(
          id: 'clarify_amount_${action.id}',
          targetActionId: action.id,
          field: 'amount',
          question: 'How much would you like to ${action.intentType.displayName.toLowerCase()}?',
          description: 'Specify an amount in USD or local currency.',
          options: [
            const ClarificationOptionData(
              id: 'amt_100',
              label: '\$100.00 USD',
              value: '100 USD',
            ),
            const ClarificationOptionData(
              id: 'amt_500',
              label: '\$500.00 USD',
              value: '500 USD',
            ),
            const ClarificationOptionData(
              id: 'amt_half',
              label: 'Half of balance',
              value: 'half',
            ),
          ],
        );
      }
    }

    // No clarification needed
    return null;
  }
}
