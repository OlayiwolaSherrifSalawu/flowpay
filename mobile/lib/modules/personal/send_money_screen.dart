import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/repositories/wallet_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/navigation/personal_tab_provider.dart';
import '../../core/transfers/transfer_funding.dart';
import '../../core/transfers/transfer_intent.dart';
import '../../core/transfers/transfer_models.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';
import 'components/transfer_receipt_dialog.dart';
import 'components/transfer_review_modal.dart';

class SendMoneyScreen extends StatefulWidget {
  final AppState appState;
  final String? initialPrompt;

  const SendMoneyScreen({
    super.key,
    required this.appState,
    this.initialPrompt,
  });

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _nlController = TextEditingController();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController(text: '500.00');
  final _purposeController = TextEditingController();

  Currency _selectedCurrency = Currency.usd;
  List<WalletAccount> _userWallets = [];
  bool _isLoadingWallets = true;

  // Pipeline execution state
  bool _isAnalyzing = false;
  String? _analysisStep; // 'Interpreting intent...', 'Inspecting balances...', etc.
  BalanceInspectionResult? _inspectionResult;
  TransferFundingOption? _selectedFundingOption;
  String? _errorMessage;

  final List<String> _suggestionChips = [
    'Send \$500 to my designer in Ghana',
    'Send \$150 to bunch.dillon@example.ng',
    'Send ₦50,000 to Samson Jabo',
    'Send \$1,200 to contractor in Mexico',
  ];

  @override
  void initState() {
    super.initState();
    _loadWallets();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _nlController.text = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAnalyzeNaturalLanguage(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _nlController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    try {
      final wallets = await widget.appState.walletRepo.getWallets();
      if (!mounted) return;
      setState(() {
        _userWallets = wallets;
        _isLoadingWallets = false;
      });
      // Initial inspection with default values
      _runBalanceInspection();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingWallets = false);
    }
  }

  /// Step 1: Natural Language Processing -> Structured TransferIntent
  Future<void> _handleAnalyzeNaturalLanguage(String prompt) async {
    if (prompt.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _analysisStep = 'Interpreting financial intent...';
      _errorMessage = null;
    });

    try {
      final intent = await widget.appState.transferRepo.interpretPrompt(prompt);

      if (!mounted) return;
      setState(() {
        _recipientController.text = intent.recipient;
        _amountController.text = intent.amount;
        _selectedCurrency = intent.currency;
        _purposeController.text = intent.purpose ?? '';
        _analysisStep = 'Inspecting wallet balances & routing...';
      });

      await Future.delayed(const Duration(milliseconds: 150));
      await _runBalanceInspection(intentOverride: intent);

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisStep = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisStep = null;
        _errorMessage = 'Could not parse request: $e';
      });
    }
  }

  /// Step 2: Deterministic Balance-Aware Multi-Currency Inspection
  Future<void> _runBalanceInspection({TransferIntent? intentOverride}) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amountMoney = Money.fromMajorString(amountText, _selectedCurrency);
    final recipient = _recipientController.text.trim();

    final intent = intentOverride ??
        TransferIntent(
          intentId: 'tx_intent_${DateTime.now().millisecondsSinceEpoch}',
          originalPrompt: _nlController.text.trim().isNotEmpty
              ? _nlController.text.trim()
              : 'Send ${_amountController.text} ${_selectedCurrency.code} to $recipient',
          recipient: recipient.isNotEmpty ? recipient : 'Beneficiary',
          amount: amountMoney.toMajorString(),
          amountMinor: amountMoney.amountMinor.toString(),
          currency: _selectedCurrency,
          purpose: _purposeController.text.trim().isNotEmpty ? _purposeController.text.trim() : null,
          confidenceScore: 0.95,
          requiresExplicitApproval: true,
        );

    try {
      final inspection = await widget.appState.transferRepo.inspectBalances(
        intent: intent,
        wallets: _userWallets,
      );

      if (!mounted) return;
      setState(() {
        _inspectionResult = inspection;
        _selectedFundingOption = inspection.recommendedFundingOption;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Balance inspection failed: $e';
      });
    }
  }

  /// Step 3: Open Premium Confirmation Screen ("Nothing moves until you approve.")
  Future<void> _openReviewConfirmation() async {
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      setState(() {
        _errorMessage = TransferErrorCode.invalidRecipient.humanReadableMessage;
      });
      return;
    }

    final amountText = _amountController.text.trim();
    final amountVal = double.tryParse(amountText);
    if (amountVal == null || amountVal <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid transfer amount greater than zero.';
      });
      return;
    }

    if (_inspectionResult == null || _selectedFundingOption == null) {
      await _runBalanceInspection();
    }

    if (_inspectionResult == null || !_inspectionResult!.isPossible || _selectedFundingOption == null) {
      setState(() {
        _errorMessage = _inspectionResult?.reason ??
            TransferErrorCode.insufficientFunds.humanReadableMessage;
      });
      return;
    }

    final amountMoney = Money.fromMajorString(amountText, _selectedCurrency);
    final intent = TransferIntent(
      intentId: 'tx_intent_${DateTime.now().millisecondsSinceEpoch}',
      originalPrompt: _nlController.text.trim(),
      recipient: recipient,
      amount: amountMoney.toMajorString(),
      amountMinor: amountMoney.amountMinor.toString(),
      currency: _selectedCurrency,
      purpose: _purposeController.text.trim().isNotEmpty ? _purposeController.text.trim() : null,
      confidenceScore: 0.95,
      requiresExplicitApproval: true,
    );

    if (!mounted) return;

    TransferReviewModal.show(
      context: context,
      intent: intent,
      fundingOption: _selectedFundingOption!,
      onEdit: () {
        Navigator.of(context).pop();
      },
      onApproveAndSend: () {
        Navigator.of(context).pop();
        _startOnDeviceSigningFlow(intent, _selectedFundingOption!);
      },
    );
  }

  /// Step 4 & 5: BMONI Proposal Creation -> On-Device B-Key Signing -> Submission
  Future<void> _startOnDeviceSigningFlow(
    TransferIntent intent,
    TransferFundingOption fundingOption,
  ) async {
    setState(() {
      _isAnalyzing = true;
      _analysisStep = 'Creating BMONI transfer proposal...';
      _errorMessage = null;
    });

    TransferProposal? proposal;
    try {
      proposal = await widget.appState.transferRepo.createProposal(
        intent: intent,
        fundingOption: fundingOption,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisStep = null;
        _errorMessage = 'Could not generate proposal on BMONI: $e';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _analysisStep = null;
    });

    // Step 5: On-device B-Key PIN Entry & Hardware Enclave Signing via WalletPinAuthSheet
    final signature = await WalletPinAuthSheet.show(
      context: context,
      title: 'Authorize Transfer',
      subtitle: 'Sign on-device with your 6-digit B-Key PIN',
      amountDisplay: '${intent.amount} ${intent.currency.code}',
      recipient: intent.recipient,
      onAuthorize: (pin) async {
        // Enforce authentic on-device signing via BmoniSdkService
        return await BmoniSdkService.signTransactionHash(
          proposal!.hashToSign,
          pin: pin,
        );
      },
    );

    if (signature == null || signature.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = TransferErrorCode.signatureFailure.humanReadableMessage;
      });
      return;
    }

    // Step 6: Submit Signature to FlowPay Backend -> BMONI Execution
    setState(() {
      _isAnalyzing = true;
      _analysisStep = 'Submitting signature to BMONI rails...';
    });

    try {
      final execution = await widget.appState.transferRepo.executeProposal(
        proposalId: proposal.proposalId,
        signature: signature,
        proposal: proposal,
      );

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisStep = null;
      });

      // Refresh local wallets and personal provider balances
      _loadWallets();
      widget.appState.personalProvider.refresh();

      // Show Celebration Receipt
      TransferReceiptDialog.show(
        context: context,
        intent: intent,
        fundingOption: fundingOption,
        result: execution,
        onDone: () {
          _resetForm();
        },
        onViewActivity: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          widget.appState.setPersonalTabIndex(PersonalTab.activity);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisStep = null;
        _errorMessage = 'Transfer failed: $e';
      });
    }
  }

  void _resetForm() {
    setState(() {
      _nlController.clear();
      _recipientController.clear();
      _amountController.text = '500.00';
      _purposeController.clear();
      _errorMessage = null;
    });
    _runBalanceInspection();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    Widget bodyContent = _isLoadingWallets
        ? const Center(child: CircularProgressIndicator(color: BMoniColors.brand500))
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // BMONI Security Rail Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38103A), Color(0xFF1E0720)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BMoniColors.brand500.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: BMoniColors.brand400, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FlowPay BMONI Rail',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: BMoniColors.grey50,
                            ),
                          ),
                          Text(
                            'Balance-Aware • AI Extracts • Hardware PIN Signed',
                            style: TextStyle(fontSize: 11, color: BMoniColors.grey400),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: BMoniColors.brand500.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'EVM Live',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: BMoniColors.brand300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. Natural Language Entry Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BMoniColors.offbrand900,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BMoniColors.offbrand700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: BMoniColors.brand400, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Natural Language Entry',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: BMoniColors.grey50,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tell FlowPay where and how much you want to send in plain words.',
                      style: TextStyle(fontSize: 12, color: BMoniColors.grey400),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      key: const Key('send_money_nl_input'),
                      controller: _nlController,
                      style: const TextStyle(color: BMoniColors.grey50, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. "Send \$500 to my designer in Ghana."',
                        hintStyle: const TextStyle(color: BMoniColors.grey600, fontSize: 13),
                        filled: true,
                        fillColor: BMoniColors.offbrand800,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.offbrand700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.offbrand700),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.brand500, width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          key: const Key('send_money_analyze_button'),
                          icon: const Icon(Icons.arrow_forward_rounded, color: BMoniColors.brand300),
                          onPressed: () => _handleAnalyzeNaturalLanguage(_nlController.text),
                          tooltip: 'Analyze',
                        ),
                      ),
                      onSubmitted: _handleAnalyzeNaturalLanguage,
                    ),

                    const SizedBox(height: 10),

                    // Suggestion Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _suggestionChips.map((chip) {
                        return InkWell(
                          key: Key('chip_${chip.replaceAll(RegExp(r'\s+'), '_')}'),
                          onTap: () {
                            _nlController.text = chip;
                            _handleAnalyzeNaturalLanguage(chip);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: BMoniColors.offbrand800,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: BMoniColors.offbrand700),
                            ),
                            child: Text(
                              chip,
                              style: const TextStyle(
                                fontSize: 11,
                                color: BMoniColors.grey300,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // 2. Progressive Analysis Pipeline Indicator
              if (_isAnalyzing) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BMoniColors.brand500.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BMoniColors.brand500.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: BMoniColors.brand400),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _analysisStep ?? 'Processing...',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: BMoniColors.brand300,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 3. Error Banner
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BMoniColors.error400.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BMoniColors.error400.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: BMoniColors.error400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BMoniColors.error400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 4. Form Fields (Recipient, Amount, Currency, Purpose)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: BMoniColors.offbrand900,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BMoniColors.offbrand700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recipient / Beneficiary',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BMoniColors.grey400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('send_money_recipient_field'),
                      controller: _recipientController,
                      style: const TextStyle(color: BMoniColors.grey50, fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_search_outlined, color: BMoniColors.brand400, size: 20),
                        hintText: 'e.g. my designer in Ghana or name@example.com',
                        hintStyle: const TextStyle(color: BMoniColors.grey600, fontSize: 13),
                        filled: true,
                        fillColor: BMoniColors.offbrand800,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.offbrand700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.offbrand700),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.brand500, width: 1.5),
                        ),
                      ),
                      onChanged: (_) => _runBalanceInspection(),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Transfer Amount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BMoniColors.grey400,
                      ),
                    ),
                    const SizedBox(height: 8),

                    FlowPayAmountField(
                      key: const Key('send_money_amount_field'),
                      controller: _amountController,
                      currencyCode: _selectedCurrency.code,
                      currencySymbol: _selectedCurrency.symbol,
                      onChanged: (_) => _runBalanceInspection(),
                      onCurrencyTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: BMoniColors.offbrand900,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SectionHeader(
                                  title: 'Select Payment Currency',
                                  backgroundColor: Colors.transparent,
                                  showBottomDivider: true,
                                  titleStyle: TextStyle(
                                    color: BMoniColors.grey50,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ...[Currency.usd, Currency.ngn, Currency.mxn, Currency.cad, Currency.eur].map((c) {
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: BMoniColors.offbrand800,
                                      child: Text(
                                        c.symbol,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: BMoniColors.brand300,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      c.name,
                                      style: const TextStyle(
                                        color: BMoniColors.grey50,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'BMONI ${c.stablecoinToken}',
                                      style: const TextStyle(color: BMoniColors.grey400, fontSize: 12),
                                    ),
                                    trailing: _selectedCurrency == c
                                        ? const Icon(Icons.check_circle, color: BMoniColors.brand400)
                                        : null,
                                    onTap: () {
                                      setState(() => _selectedCurrency = c);
                                      Navigator.pop(ctx);
                                      _runBalanceInspection();
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Purpose / Memo (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BMoniColors.grey400,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _purposeController,
                      style: const TextStyle(color: BMoniColors.grey50, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Design services, contractor payment',
                        hintStyle: const TextStyle(color: BMoniColors.grey600, fontSize: 13),
                        filled: true,
                        fillColor: BMoniColors.offbrand800,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.offbrand700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.offbrand700),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: BMoniColors.brand500, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. Balance-Aware Auto-Funding Analysis Card
              if (_inspectionResult != null) ...[
                Container(
                  key: const Key('balance_aware_funding_card'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BMoniColors.offbrand900,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _selectedFundingOption?.requiresConversion == true
                          ? BMoniColors.brand500.withAlpha(120)
                          : BMoniColors.offbrand700,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_wallet_outlined, color: BMoniColors.brand400, size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Funding Source & Routing',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: BMoniColors.grey50,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_selectedFundingOption?.requiresConversion == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: BMoniColors.brand500.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: BMoniColors.brand500.withAlpha(80)),
                              ),
                              child: Text(
                                _selectedFundingOption!.conversionLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: BMoniColors.brand300,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Conversion notice if direct balance was insufficient
                      if (!_inspectionResult!.isDirectFunded && _selectedFundingOption != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: BMoniColors.brand500.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BMoniColors.brand500.withAlpha(50)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 16, color: BMoniColors.brand300),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Balance-Aware Auto-Funding: Insufficient ${_selectedCurrency.code}. FlowPay routes settlement via ${_selectedFundingOption!.fundingWalletName} (${_selectedFundingOption!.availableBalance.formatFormatted()} available).',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: BMoniColors.grey300,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Funding source selector / row
                      if (_inspectionResult!.allFundingOptions.length > 1) ...[
                        const Text(
                          'Choose Funding Wallet:',
                          style: TextStyle(fontSize: 12, color: BMoniColors.grey400),
                        ),
                        const SizedBox(height: 6),
                        ..._inspectionResult!.allFundingOptions.map((opt) {
                          final isSelected = _selectedFundingOption?.fundingWalletId == opt.fundingWalletId;
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedFundingOption = opt);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? BMoniColors.offbrand800 : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? BMoniColors.brand500 : BMoniColors.offbrand700,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                          size: 16,
                                          color: isSelected ? BMoniColors.brand400 : BMoniColors.grey500,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            opt.fundingWalletName,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: BMoniColors.grey50,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    opt.availableBalance.formatFormatted(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: BMoniColors.brand300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ] else if (_selectedFundingOption != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedFundingOption!.fundingWalletName,
                                style: const TextStyle(fontSize: 13, color: BMoniColors.grey300),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedFundingOption!.availableBalance.formatFormatted()} available',
                              style: const TextStyle(fontSize: 13, color: BMoniColors.brand300, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],

                      if (_selectedFundingOption?.exchangeRate != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Exchange Rate: 1 ${_selectedCurrency.code} = ${_selectedFundingOption!.exchangeRate!.toStringAsFixed(2)} ${_selectedFundingOption!.fundingCurrency.code}',
                          style: const TextStyle(fontSize: 11, color: BMoniColors.grey400),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 6. Review & Verify Primary Action Button
              BMoniButton(
                key: const Key('send_money_review_button'),
                text: 'Review Transfer',
                variant: BMoniButtonVariant.primary,
                size: BMoniButtonSize.large,
                isLoading: _isAnalyzing,
                onPressed: _openReviewConfirmation,
              ),
              const SizedBox(height: 24),
            ],
          );

    if (canPop) {
      return Scaffold(
        backgroundColor: BMoniColors.offbrand950,
        appBar: AppBar(
          backgroundColor: BMoniColors.offbrand950,
          elevation: 0,
          title: const Text(
            'Send Money',
            style: TextStyle(color: BMoniColors.grey50, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: BMoniColors.grey50, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: bodyContent,
      );
    }

    return Material(
      color: BMoniColors.offbrand950,
      child: bodyContent,
    );
  }
}
