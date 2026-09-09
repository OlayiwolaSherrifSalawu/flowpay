import '../models/financial_entities.dart';
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
      // 1. Check for Person / Recipient issues
      if (action.person != null) {
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

      // 2. Check for Destination (Wallet / Reserve) issues
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
