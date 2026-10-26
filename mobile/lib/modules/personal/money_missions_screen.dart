import '../../core/stellar/stellar_key_vault.dart';
import 'package:flutter/material.dart';
import '../../core/wallet/wallet_signer.dart';
import '../../core/design_system/buttons.dart';
import '../../core/design_system/flowpay_pagination_bar.dart';
import '../../core/design_system/states.dart';
import '../../core/missions/mission_intent.dart';
import '../../core/missions/mission_validator.dart';
import '../../core/models/paginated_result.dart';
import '../../core/navigation/personal_tab_provider.dart';
import '../../core/repositories/mission_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radii.dart';
import '../../core/theme/typography.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';
import 'components/mission_card.dart';
import 'components/mission_preview_modal.dart';

class MoneyMissionsScreen extends StatefulWidget {
  final AppState appState;

  const MoneyMissionsScreen({super.key, required this.appState});

  @override
  State<MoneyMissionsScreen> createState() => _MoneyMissionsScreenState();
}

class _MoneyMissionsScreenState extends State<MoneyMissionsScreen> {
  final TextEditingController _inputController = TextEditingController(
    text:
        'Whenever I receive \$2,000, keep 30% in USD, convert 50% to Naira for expenses, and reserve 20% for tax.',
  );

  List<MoneyMissionModel> missions = [];
  bool isLoadingMissions = true;
  int _missionPage = 1;
  static const int _missionPageSize = 5;

  // AI Pipeline State
  bool isInterpreting = false;
  int processingStage = 0; // 0: Idle, 1: Understood, 2: Created, 3: Validated
  MissionIntent? currentIntent;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadMissions() async {
    setState(() => isLoadingMissions = true);
    try {
      final list = await widget.appState.missionRepo.getMissions();
      if (mounted) {
        setState(() {
          missions = List.from(list);
          isLoadingMissions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => isLoadingMissions = false);
      }
    }
  }

  void _prefillPrompt(String prompt) {
    setState(() {
      _inputController.text = prompt;
      currentIntent = null;
      errorMessage = null;
      processingStage = 0;
    });
  }

  Future<void> _handleInterpret() async {
    final prompt = _inputController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      isInterpreting = true;
      processingStage = 1; // Stage 1: AI understood request
      errorMessage = null;
      currentIntent = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => processingStage = 2); // Stage 2: Plan created

      // Call repository to interpret
      final intent = await widget.appState.missionRepo.interpretMission(prompt);

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => processingStage = 3); // Stage 3: Deterministic validation

      // Client-side deterministic validation guard
      final validation = ClientMissionValidator.validate(intent);
      if (!validation.isValid) {
        setState(() {
          isInterpreting = false;
          processingStage = 0;
          errorMessage = validation.errors.join('; ');
        });
        return;
      }

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() {
        isInterpreting = false;
        currentIntent = intent;
      });

      _showMissionPreviewModal(intent);
    } catch (err) {
      if (mounted) {
        setState(() {
          isInterpreting = false;
          processingStage = 0;
          errorMessage = 'Failed to interpret instruction: $err';
        });
      }
    }
  }

  void _showMissionPreviewModal(MissionIntent intent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MissionPreviewModal(
        intent: intent,
        onEdit: () {
          Navigator.pop(ctx);
        },
        onApprove: () {
          Navigator.pop(ctx);
          _startSigningAndExecutionFlow(intent);
        },
      ),
    );
  }

  /// Shows the PIN sheet for a mission run and returns what to submit:
  /// the signed Stellar transaction (live), a signed demo hash, or 'approved'
  /// for runs that move no money. Null when the user cancels.
  Future<String?> _approveRun(MissionRun run, {required String title, required String subtitle, String? amountDisplay}) {
    return WalletPinAuthSheet.show(
      context: context,
      title: title,
      subtitle: run.movesMoney ? subtitle : '$subtitle\nThis activates the rule; no money moves now.',
      amountDisplay: amountDisplay,
      recipient: '',
      onAuthorize: (pin) async {
        const signer = StellarWalletSigner();
        if (run.signPayload != null) return signer.signTransactionXdr(run.signPayload!, pin: pin);
        if (run.hashToSign != null) return signer.signTransactionHash(run.hashToSign!, pin: pin);
        if (!await StellarKeyVault.instance.verifyPin(pin)) {
          throw const StellarVaultException(StellarVaultErrorCode.pinMismatch, 'Incorrect PIN.');
        }
        return 'approved';
      },
    );
  }

  Future<void> _startSigningAndExecutionFlow(MissionIntent intent) async {
    try {
      // 1. Save the rule and build its first run (one atomic transaction).
      final run = await widget.appState.missionRepo.proposeMission(intent);
      if (!mounted) return;

      // 2. User reviews and signs on this device.
      final approval = await _approveRun(
        run,
        title: 'Approve this rule',
        subtitle: 'You\'re setting up: "${intent.ruleTitle}"',
        amountDisplay: '${intent.triggerCondition.sourceCurrency.symbol}${intent.triggerCondition.sourceAmount}',
      );
      if (approval == null || !mounted) return;

      // 3. Activate + submit. Errors propagate to the catch below.
      final result = await widget.appState.missionRepo.executeMission(
        missionId: run.missionId,
        proposalId: run.proposalId,
        signedPayload: run.movesMoney ? approval : null,
      );

      await _loadMissions();
      widget.appState.notifyStateChanged();
      if (!mounted) return;
      setState(() {
        currentIntent = null;
        processingStage = 0;
      });
      final created = missions.firstWhere(
        (m) => m.id == run.missionId,
        orElse: () => MoneyMissionModel(
          id: run.missionId,
          title: intent.ruleTitle,
          tagline: intent.explanation,
          ruleType: MissionRuleType.splitIncoming,
          isActive: true,
          stats: '',
          conditionSummary: intent.triggerCondition.description,
          actionSummary: intent.explanation,
        ),
      );
      _showExecutionCelebrationDialog(created, result);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('The rule was not activated: $err'),
            backgroundColor: FlowPayColors.error,
          ),
        );
      }
    }
  }

  void _showExecutionCelebrationDialog(
      MoneyMissionModel mission, Map<String, dynamic> result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txRef = result['transactionHash']?.toString() ?? 'No money moved (rule activated)';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? FlowPayColors.darkSurface : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.card),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FlowPayColors.primary.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: FlowPayColors.primary.withAlpha(60),
                ),
              ),
              child: const Icon(Icons.check,
                  color: FlowPayColors.primary, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              'Rule saved!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : FlowPayColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'FlowPay will automatically run this rule whenever the conditions are met.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? FlowPayColors.darkTextSecondary
                    : FlowPayColors.lightTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.lightSurfaceElevated,
                borderRadius: FlowPayRadii.cardSmall,
                border: Border.all(
                  color: isDark
                      ? FlowPayColors.darkBorder
                      : FlowPayColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reference',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? FlowPayColors.darkTextSecondary
                                  : FlowPayColors.lightTextSecondary)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          txRef.length > 18
                              ? '${txRef.substring(0, 16)}...'
                              : txRef,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: FlowPayColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? FlowPayColors.darkTextSecondary
                                  : FlowPayColors.lightTextSecondary)),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Active',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: FlowPayColors.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FlowPayButton(
                    text: 'View Active Missions',
                    size: FlowPayButtonSize.large,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FlowPayButton(
                    text: 'View in Activity',
                    variant: FlowPayButtonVariant.secondary,
                    size: FlowPayButtonSize.medium,
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      widget.appState.setPersonalTabIndex(PersonalTab.activity);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMission(String id) async {
    final updated = await widget.appState.missionRepo.toggleMission(id);
    if (mounted) {
      setState(() {
        final idx = missions.indexWhere((m) => m.id == id);
        if (idx != -1) {
          missions[idx] = updated;
        }
      });
    }
  }

  Future<void> _confirmDeleteMission(MoneyMissionModel mission) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? FlowPayColors.darkSurfaceElevated
            : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.cardSmall),
        title: Text(
          'Delete Rule?',
          style: FlowPayTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${mission.title}"? This rule will be deleted.',
          style: FlowPayTypography.bodySmall.copyWith(
            color: isDark
                ? FlowPayColors.darkTextSecondary
                : FlowPayColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FlowPayButton(
            text: 'Delete',
            size: FlowPayButtonSize.small,
            variant: FlowPayButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.appState.missionRepo.deleteMission(mission.id);
      await widget.appState.personalProvider.deleteMission(mission.id);
      if (mounted) {
        setState(() {
          missions.removeWhere((m) => m.id == mission.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rule "${mission.title}" deleted.'),
            backgroundColor: FlowPayColors.darkSurfaceElevated,
          ),
        );
      }
    }
  }

  static String _shortHash(dynamic hash) {
    final h = hash?.toString() ?? '';
    return h.length >= 8 ? ' (${h.substring(0, 8)}…)' : '';
  }

  Future<void> _handleManualTrigger(String id) async {
    final idx = missions.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final mission = missions[idx];

    try {
      final run = await widget.appState.missionRepo.prepareRun(id);
      if (!mounted) return;
      if (!run.movesMoney) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This rule only holds funds — there is nothing to send.')),
        );
        return;
      }
      final signed = await _approveRun(
        run,
        title: 'Run this rule now',
        subtitle: 'Run "${mission.title}" as one Stellar transaction',
        amountDisplay: mission.thresholdAmount?.formatFormatted(),
      );
      if (signed == null || !mounted) return;

      final result = await widget.appState.missionRepo.executeMission(
        missionId: id,
        proposalId: run.proposalId,
        signedPayload: signed,
      );
      await _loadMissions();
      widget.appState.notifyStateChanged();
      if (!mounted) return;

      final pending = result['status'] == 'PENDING';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pending
              ? 'Submitted — waiting for the Stellar network to confirm.'
              : widget.appState.isDemo
                  ? '✓ Rule ran (demo simulation — no real money moved)'
                  : '✓ Rule ran on Stellar${_shortHash(result['transactionHash'])}'),
          backgroundColor: FlowPayColors.primary,
          action: SnackBarAction(
            label: 'View Activity',
            textColor: Colors.white,
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              widget.appState.setPersonalTabIndex(PersonalTab.activity);
            },
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The rule did not run: $err'), backgroundColor: FlowPayColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    Widget content = isLoadingMissions
        ? const FlowPayLoadingState(message: 'Loading Money Missions...')
        : RefreshIndicator(
            onRefresh: _loadMissions,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Financial Command Center Header & Telemetry
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What should your money do?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tell your money what to do.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FlowPayColors.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Describe a rule in plain English. FlowPay will run it automatically — always with your PIN approval.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Command Center Live Telemetry Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? FlowPayColors.darkSurface : Colors.white,
                    borderRadius: FlowPayRadii.chip,
                    border: Border.all(
                      color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 16 : 4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: FlowPayColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : FlowPayColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                size: 14, color: FlowPayColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Secured',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Row(
                          children: [
                            const Icon(Icons.bolt,
                                size: 14, color: FlowPayColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Financial Command Center Console (Command Directive Input)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? FlowPayColors.darkSurface : Colors.white,
                    borderRadius: FlowPayRadii.card,
                    border: Border.all(
                      color: isInterpreting
                          ? FlowPayColors.primary
                          : (isDark
                              ? FlowPayColors.darkBorder
                              : FlowPayColors.lightBorder),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isInterpreting
                            ? FlowPayColors.primary.withAlpha(25)
                            : Colors.black.withAlpha(isDark ? 24 : 6),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: FlowPayColors.primary.withAlpha(24),
                              borderRadius: FlowPayRadii.chip,
                              border: Border.all(
                                color: FlowPayColors.primary.withAlpha(50),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.terminal_rounded,
                                    size: 13, color: FlowPayColors.primary),
                                SizedBox(width: 5),
                                Text(
                                  'YOUR RULE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: FlowPayColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your money. Your rules. AI executes.',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? FlowPayColors.darkTextSecondary
                                    : FlowPayColors.lightTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _inputController,
                        maxLines: 3,
                        minLines: 2,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. "Whenever I receive \$2,000, keep 30% in USD, convert 50% to Naira for expenses, and reserve 20% for tax."',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? FlowPayColors.darkTextSecondary
                                : FlowPayColors.lightTextSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit Directive Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Requires your PIN to activate',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FlowPayButton(
                            text: isInterpreting
                                ? 'Setting up...'
                                : 'Set up rule',
                            icon: Icons.auto_awesome,
                            size: FlowPayButtonSize.medium,
                            isLoading: isInterpreting,
                            onPressed: isInterpreting ? null : _handleInterpret,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Error Banner if validation failed
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: FlowPayColors.error.withAlpha(16),
                      borderRadius: FlowPayRadii.cardSmall,
                      border:
                          Border.all(color: FlowPayColors.error.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: FlowPayColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                                fontSize: 12, color: FlowPayColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 3. Visible AI Pipeline Progress Indicator (Stages: Understood -> Created -> Validated)
                if (isInterpreting || processingStage > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FlowPayColors.darkSurfaceElevated
                          : FlowPayColors.lightSurfaceElevated,
                      borderRadius: FlowPayRadii.cardSmall,
                      border:
                          Border.all(color: FlowPayColors.primary.withAlpha(70)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology,
                                size: 16, color: FlowPayColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Checking your plan...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                color: FlowPayColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStageRow('Got it', processingStage >= 1),
                        const SizedBox(height: 8),
                        _buildStageRow('Plan created', processingStage >= 2),
                        const SizedBox(height: 8),
                        _buildStageRow(
                            'Everything checks out', processingStage >= 3),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // 4. Suggested Actions Row (5 Suggestion Chips)
                Text(
                  'SUGGESTED RULES',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.bold,
                    color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSuggestionChip(
                        icon: Icons.pie_chart_outline,
                        label: 'Split incoming payment',
                        color: FlowPayColors.primary,
                        prompt:
                            'Whenever I receive \$2,000, keep 30% in USD, convert 50% to Naira for expenses, and reserve 20% for tax.',
                      ),
                      const SizedBox(width: 8),
                      _buildSuggestionChip(
                        icon: Icons.savings_outlined,
                        label: 'Save for a goal',
                        color: FlowPayColors.primaryDark,
                        prompt:
                            'Whenever I receive \$1,500, save 25% into high-yield USD emergency vault.',
                      ),
                      const SizedBox(width: 8),
                      _buildSuggestionChip(
                        icon: Icons.currency_exchange,
                        label: 'Convert currency',
                        color: FlowPayColors.primary,
                        prompt:
                            'Convert \$1,000 to Naira whenever received for monthly payroll expenses.',
                      ),
                      const SizedBox(width: 8),
                      _buildSuggestionChip(
                        icon: Icons.send_outlined,
                        label: 'Send money',
                        color: const Color(0xFF38BDF8),
                        prompt:
                            'Send \$500 to Samson Jabo whenever contractor disbursement arrives.',
                      ),
                      const SizedBox(width: 8),
                      _buildSuggestionChip(
                        icon: Icons.account_balance_outlined,
                        label: 'Reserve for taxes',
                        color: const Color(0xFFFBBF24),
                        prompt:
                            'Reserve 20% for tax into escrow sub-account on every incoming payment.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 5. Active Missions Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Missions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: FlowPayColors.primary.withAlpha(20),
                        borderRadius: FlowPayRadii.chip,
                        border: Border.all(
                            color: FlowPayColors.primary.withAlpha(60)),
                      ),
                      child: Text(
                        '${missions.where((m) => m.isActive).length} Active',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: FlowPayColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Active Mission Cards List
                if (missions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? FlowPayColors.darkSurface : Colors.white,
                      borderRadius: FlowPayRadii.card,
                      border: Border.all(
                        color: isDark
                            ? FlowPayColors.darkBorder
                            : FlowPayColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 16 : 4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark
                                ? FlowPayColors.darkSurfaceElevated
                                : FlowPayColors.lightSurfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bolt,
                            size: 28,
                            color: isDark
                                ? FlowPayColors.darkTextSecondary
                                : FlowPayColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Rules Yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : FlowPayColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Describe a rule above to get started.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? FlowPayColors.darkTextSecondary
                                : FlowPayColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else ...[
                  ...PaginatedResult.paginateList(
                    missions,
                    page: _missionPage,
                    limit: _missionPageSize,
                  ).items.map((m) {
                    return MissionCard(
                      mission: m,
                      onToggleActive: (_) => _toggleMission(m.id),
                      onTriggerManual: () => _handleManualTrigger(m.id),
                      onDelete: () => _confirmDeleteMission(m),
                    );
                  }),
                  if (missions.length > _missionPageSize) ...[
                    const SizedBox(height: 12),
                    FlowPayPaginationBar(
                      currentPage: _missionPage,
                      totalPages: (missions.length / _missionPageSize).ceil(),
                      totalItems: missions.length,
                      pageSize: _missionPageSize,
                      onPageChanged: (newPage) {
                        setState(() {
                          _missionPage = newPage;
                        });
                      },
                    ),
                  ],
                ],
              ],
            ),
          );

    if (canPop) {
      return Scaffold(
        backgroundColor: isDark ? FlowPayColors.darkBackground : FlowPayColors.paper,
        appBar: AppBar(
          title: const Text('Money Missions'),
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildStageRow(String label, bool isCompleted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.circle_outlined,
          size: 15,
          color: isCompleted ? FlowPayColors.primary : (isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
              color: isCompleted
                  ? (isDark ? Colors.white : FlowPayColors.lightTextPrimary)
                  : (isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip({
    required IconData icon,
    required String label,
    required Color color,
    required String prompt,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _prefillPrompt(prompt),
      borderRadius: FlowPayRadii.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 22 : 18),
          borderRadius: FlowPayRadii.chip,
          border: Border.all(color: color.withAlpha(isDark ? 70 : 60), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : FlowPayColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
