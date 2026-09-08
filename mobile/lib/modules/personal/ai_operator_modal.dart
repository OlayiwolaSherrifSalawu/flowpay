import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/financial_operator/financial_operator.dart';
import '../../core/financial_operator/models/financial_plan_models.dart';
import '../../core/financial_operator/models/operator_session_models.dart';
import '../../core/financial_operator/services/execution_provider.dart';
import '../../core/financial_operator/services/financial_context_service.dart';
import '../../core/state/app_state.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';
import 'components/add_beneficiary_modal.dart';
import 'components/ai_clarification_card.dart';
import 'components/ai_financial_plan_card.dart';
import 'components/choose_beneficiary_modal.dart';

/// FlowPay AI Financial Operator Modal
/// Embedded intelligent financial operator interface supporting natural language
/// multi-action requests, entity disambiguation, multi-turn clarification,
/// structured plan review, and on-device B-Key PIN signing.
class AiOperatorModal extends StatefulWidget {
  final AppState appState;
  final String? initialPrompt;

  const AiOperatorModal({
    super.key,
    required this.appState,
    this.initialPrompt,
  });

  @override
  State<AiOperatorModal> createState() => _AiOperatorModalState();
}

class _AiOperatorModalState extends State<AiOperatorModal> {
  late final FinancialOperator _operator;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSigning = false;

  @override
  void initState() {
    super.initState();
    final contextService = FinancialContextService(
      walletRepo: widget.appState.walletRepo,
      beneficiaryRepo: widget.appState.beneficiaryRepo,
      missionRepo: widget.appState.missionRepo,
      activityRepo: widget.appState.activityRepo,
    );
    final executionProvider = DemoFinancialExecutionProvider(
      walletRepo: widget.appState.walletRepo,
      activityRepo: widget.appState.activityRepo,
    );

    _operator = FinancialOperator(
      contextService: contextService,
      executionProvider: executionProvider,
      transferRepo: widget.appState.transferRepo,
    );

    _operator.addListener(_onOperatorStateChanged);

    if (widget.initialPrompt != null &&
        widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _operator.processInput(widget.initialPrompt!.trim());
      });
    }
  }

  @override
  void dispose() {
    _operator.removeListener(_onOperatorStateChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _operator.dispose();
    super.dispose();
  }

  void _onOperatorStateChanged() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();

    final lower = text.toLowerCase();
    if (_operator.status == OperatorSessionStatus.readyForReview &&
        _operator.activePlan != null &&
        (lower == 'approve' ||
            lower == 'confirm' ||
            lower == 'proceed' ||
            lower == 'yes')) {
      _handleApprovePlan(_operator.activePlan!);
      return;
    }

    _operator.processInput(text);
  }

  Future<void> _handleOptionSelected(
    ClarificationPrompt clarification,
    ClarificationOptionData opt,
  ) async {
    if (opt.value == 'ADD_BENEFICIARY') {
      // Extract possible nickname from question, e.g. "Who is dad?" -> "Dad"
      String? nickname;
      final q = clarification.question;
      final match =
          RegExp(r'Who is ([^?]+)\?', caseSensitive: false).firstMatch(q);
      if (match != null) {
        nickname = match.group(1)!.trim();
        nickname = nickname[0].toUpperCase() +
            (nickname.length > 1 ? nickname.substring(1) : '');
      }

      await AddBeneficiaryModal.show(
        context,
        initialNickname: nickname,
        onSave: (beneficiary) async {
          await _operator.contextService.addBeneficiary(beneficiary);
          await _operator
              .resolvePendingClarificationWithBeneficiary(beneficiary);
        },
      );
      return;
    }

    if (opt.value == 'CHOOSE_EXISTING' || opt.value == 'CHOOSE_CONTACT') {
      final beneficiaries = await _operator.contextService.getBeneficiaries();
      if (!mounted) return;
      await ChooseBeneficiaryModal.show(
        context,
        beneficiaries: beneficiaries,
        onSelect: (beneficiary) async {
          await _operator
              .resolvePendingClarificationWithBeneficiary(beneficiary);
        },
      );
      return;
    }

    await _operator.selectClarificationOption(clarification, opt);
  }

  Future<void> _handleApprovePlan(FinancialPlan plan) async {
    setState(() => _isSigning = true);

    try {
      final hashToSign = plan.hashToSign ??
          (plan.actions.any((a) => a.type == PlannedActionType.send)
              ? throw StateError('Transfer plan missing proposal hash to sign')
              : '0x${sha256.convert(utf8.encode(plan.planId)).toString()}');

      final signature = await WalletPinAuthSheet.show(
        context: context,
        title: 'Authorize Financial Plan',
        subtitle: 'Sign on-device with your 6-digit B-Key PIN',
        amountDisplay: plan.totalDebit.toFormattedString(),
        recipient: plan.summary,
        onAuthorize: (pin) async {
          // Perform authentic on-device signing via BmoniSdkService
          return await BmoniSdkService.signTransactionHash(
            hashToSign,
            pin: pin,
          );
        },
      );

      if (signature != null && signature.isNotEmpty) {
        await _operator.approveAndExecute(signature: signature);
        await widget.appState.personalProvider.refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authorization error: $e'),
            backgroundColor: FlowPayColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark
            ? FlowPayColors.darkSurfaceElevated
            : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            // Telemetry / Status indicator bar
            _buildTelemetryBar(isDark),

            // Message Stream
            Expanded(
              child: _operator.messages.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      itemCount: _operator.messages.length,
                      itemBuilder: (context, index) {
                        final msg = _operator.messages[index];
                        return _buildMessageItem(context, msg, isDark);
                      },
                    ),
            ),

            // Suggested quick actions when idle
            if (_operator.status == OperatorSessionStatus.idle ||
                _operator.messages.isEmpty)
              _buildSuggestionsRow(isDark),

            // Input Bar
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FlowPayColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology,
                color: FlowPayColors.primaryLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FlowPay Financial Operator',
                  style: FlowPayTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? FlowPayColors.darkTextPrimary
                        : FlowPayColors.lightTextPrimary,
                  ),
                ),
                Text(
                  'Understands intent • Validates policy • Never moves money without PIN',
                  style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryBar(bool isDark) {
    String statusLabel = 'READY';
    Color statusColor = FlowPayColors.primary;

    switch (_operator.status) {
      case OperatorSessionStatus.interpreting:
        statusLabel = 'INTERPRETING INTENT';
        statusColor = FlowPayColors.accent;
        break;
      case OperatorSessionStatus.waitingForClarification:
        statusLabel = 'WAITING FOR CLARIFICATION';
        statusColor = FlowPayColors.accentLight;
        break;
      case OperatorSessionStatus.readyForReview:
        statusLabel = 'PLAN READY FOR REVIEW';
        statusColor = FlowPayColors.primaryLight;
        break;
      case OperatorSessionStatus.executing:
        statusLabel = 'AUTHORIZING ON-DEVICE';
        statusColor = FlowPayColors.primary;
        break;
      case OperatorSessionStatus.completed:
        statusLabel = 'PLAN EXECUTED';
        statusColor = FlowPayColors.primary;
        break;
      case OperatorSessionStatus.error:
      case OperatorSessionStatus.rejected:
        statusLabel = 'HALTED / REJECTED';
        statusColor = FlowPayColors.error;
        break;
      case OperatorSessionStatus.idle:
      default:
        statusLabel = 'READY';
        statusColor = FlowPayColors.primary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? FlowPayColors.darkSurfaceSubtle
            : FlowPayColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: statusColor,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          const Text(
            'B-Key Guard: Active  •  Deterministic Math',
            style: TextStyle(
              fontSize: 10,
              color: FlowPayColors.darkTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlowPayColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 36, color: FlowPayColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'What would you like to achieve?',
              style: FlowPayTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? FlowPayColors.darkTextPrimary
                    : FlowPayColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask FlowPay in natural language to send money, reserve taxes, allocate incoming payments, or manage your multi-currency smart wallets.',
              textAlign: TextAlign.center,
              style: FlowPayTypography.bodyMd.copyWith(
                color: FlowPayColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(
      BuildContext context, OperatorMessage msg, bool isDark) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: FlowPayColors.primary.withAlpha(40),
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: const Radius.circular(2),
            ),
            border: Border.all(
              color: FlowPayColors.primary.withAlpha(90),
            ),
          ),
          child: Text(
            msg.text,
            style: FlowPayTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? FlowPayColors.darkTextPrimary
                  : FlowPayColors.lightTextPrimary,
            ),
          ),
        ),
      );
    }

    // Operator Message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text Message Bubble
            if (msg.text.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? FlowPayColors.darkSurfaceSubtle
                      : FlowPayColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomLeft: const Radius.circular(2),
                  ),
                  border: Border.all(
                    color: msg.isError
                        ? FlowPayColors.error.withAlpha(120)
                        : (isDark
                            ? FlowPayColors.darkBorder
                            : FlowPayColors.lightBorder),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: FlowPayTypography.bodyMd.copyWith(
                    color: msg.isError
                        ? FlowPayColors.error
                        : (isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary),
                  ),
                ),
              ),

            // Embedded Clarification Card
            if (msg.clarification != null) ...[
              const SizedBox(height: 8),
              AiClarificationCard(
                title: msg.clarification!.question,
                questions: [
                  ClarificationQuestion(
                    id: msg.clarification!.id,
                    question: msg.clarification!.question,
                    description: msg.clarification!.description,
                    options: msg.clarification!.options.map((opt) {
                      return ClarificationOption(
                        id: opt.id,
                        label: opt.label,
                        subtitle: opt.subtitle,
                        onCustomAction: () =>
                            _handleOptionSelected(msg.clarification!, opt),
                      );
                    }).toList(),
                  ),
                ],
                onCancel: () => _operator.cancelSession(),
              ),
            ],

            // Embedded Structured Financial Plan Card
            if (msg.plan != null) ...[
              const SizedBox(height: 8),
              AiFinancialPlanCard(
                plan: msg.plan!,
                isExecuting: _isSigning,
                onApprove: () => _handleApprovePlan(msg.plan!),
                onCancel: () => _operator.cancelSession(),
                onOverrideRoute: (curr) {
                  _inputController.text = 'Use $curr instead';
                  _handleSubmit();
                },
                onAskWhy: () {
                  _inputController.text = 'Why did you use my EUR?';
                  _handleSubmit();
                },
              ),
            ],

            // Embedded Execution Receipt Card
            if (msg.executionReceipt != null) ...[
              const SizedBox(height: 8),
              _buildReceiptCard(msg.executionReceipt!, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowPayColors.primary.withAlpha(25),
        borderRadius: FlowPaySpacing.borderRadiusLg,
        border: Border.all(color: FlowPayColors.primary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: FlowPayColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Financial Execution Settled',
                style: FlowPayTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? FlowPayColors.darkTextPrimary
                      : FlowPayColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Transaction Hash: ${receipt['txHash']}',
            style: FlowPayTypography.captionStyle(
              color: FlowPayColors.darkTextSecondary,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(
            'Settled Actions: ${receipt['settledActions']} item(s)',
            style: FlowPayTypography.captionStyle(
              color: FlowPayColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FlowPayButton(
              text: 'Done',
              size: FlowPayButtonSize.small,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSuggestionPill(
              'Send \$500 USD to Mom and pay my designer \$2,000 USD',
              isDark,
            ),
            const SizedBox(width: 8),
            _buildSuggestionPill(
              'Make sure I have \$2,000 in USD',
              isDark,
            ),
            const SizedBox(width: 8),
            _buildSuggestionPill(
              'Send 500 usd to mom, keep 300 usd for tax',
              isDark,
            ),
            const SizedBox(width: 8),
            _buildSuggestionPill(
              'Check my balance',
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionPill(String text, bool isDark) {
    return InkWell(
      onTap: () {
        _inputController.text = text;
        _handleSubmit();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? FlowPayColors.darkSurfaceSubtle
              : FlowPayColors.lightSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          ),
        ),
        child: Text(
          text.length > 38 ? '${text.substring(0, 38)}...' : text,
          style: FlowPayTypography.captionStyle(
            color: isDark
                ? FlowPayColors.darkTextPrimary
                : FlowPayColors.lightTextPrimary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? FlowPayColors.darkSurfaceElevated
            : FlowPayColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                hintText: 'Type instructions or respond naturally...',
                hintStyle: TextStyle(
                  color: FlowPayColors.darkTextMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          FlowPayIconButton(
            icon: Icons.arrow_upward_rounded,
            tooltip: 'Send directive',
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
