import 'package:flutter/material.dart';
import '../../core/beneficiaries/beneficiary_model.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/repositories/activity_repository.dart';
import '../../core/repositories/wallet_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/navigation/personal_tab_provider.dart';
import '../../core/transfers/transfer_funding.dart';
import '../../core/transfers/transfer_intent.dart';
import '../../core/transfers/transfer_models.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';
import 'components/ai_clarification_card.dart';
import 'components/transfer_receipt_dialog.dart';
import 'components/transfer_review_modal.dart';
import '../../core/services/bank_resolution_service.dart';

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
  String? _analysisStep;
  BalanceInspectionResult? _inspectionResult;
  TransferFundingOption? _selectedFundingOption;
  String? _errorMessage;

  // Clarification & Beneficiary Resolution
  Beneficiary? _resolvedBeneficiary;
  List<ClarificationQuestion>? _clarificationQuestions;

  final List<String> _suggestionChips = [
    'Send \$500 to my designer in Ghana',
    'Send \$150 to bunch.dillon@example.ng',
    'Send ₦50,000 to Samson Jabo',
    'Send \$1,200 to contractor in Mexico',
  ];

  // Paystack Nigerian Bank Resolution
  bool _isBankMode = false;
  final _bankResolutionService = BankResolutionService();
  final _bankAccountController = TextEditingController();
  List<BankInfo> _availableBanks = [];
  BankInfo? _selectedBank;
  ResolvedBankAccount? _resolvedBankAccount;
  bool _isResolvingAccount = false;
  String? _bankResolutionError;

  @override
  void initState() {
    super.initState();
    _loadWallets();
    _loadBanks();
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
    _bankAccountController.dispose();
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await _bankResolutionService.getBanks();
      if (!mounted) return;
      setState(() {
        _availableBanks = banks;
        if (banks.isNotEmpty && _selectedBank == null) {
          _selectedBank = banks.firstWhere(
            (b) => b.code == '058',
            orElse: () => banks.first,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _onBankAccountChanged(String value) async {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10 && _selectedBank != null) {
      await _resolveBankAccount(clean, _selectedBank!.code);
    } else {
      if (_resolvedBankAccount != null || _bankResolutionError != null) {
        setState(() {
          _resolvedBankAccount = null;
          _bankResolutionError = null;
        });
      }
    }
  }

  Future<void> _resolveBankAccount(String accountNumber, String bankCode) async {
    setState(() {
      _isResolvingAccount = true;
      _bankResolutionError = null;
    });

    try {
      final resolved = await _bankResolutionService.resolveAccount(
        accountNumber: accountNumber,
        bankCode: bankCode,
      );

      if (!mounted) return;
      setState(() {
        _resolvedBankAccount = resolved;
        _isResolvingAccount = false;
        _recipientController.text = '${resolved.accountName} (${resolved.bankName} • ${resolved.accountNumber})';
        if (_selectedCurrency != Currency.ngn) {
          _selectedCurrency = Currency.ngn;
        }
      });
      _runBalanceInspection();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingAccount = false;
        _bankResolutionError = e.toString().replaceFirst('Exception: ', '');
        _resolvedBankAccount = null;
      });
    }
  }

  void _openBankSelectorBottomSheet() {
    final searchController = TextEditingController();
    List<BankInfo> filteredBanks = List.from(_availableBanks);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: FlowPayRadii.sheet,
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: isDark ? FlowPayColors.darkSurface : Colors.white,
            borderRadius: FlowPayRadii.sheet,
            border: Border.all(
              color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
            ),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FlowPayColors.emerald600.withAlpha(isDark ? 35 : 20),
                          borderRadius: FlowPayRadii.avatar,
                        ),
                        child: const Icon(Icons.account_balance_outlined,
                            color: FlowPayColors.emerald600, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Select Nigerian Bank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : FlowPayColors.ink,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
                            size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchController,
                    style: TextStyle(
                      color: isDark ? Colors.white : FlowPayColors.ink,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search bank (e.g. GTB, OPay, Zenith, Kuda, Access)',
                      hintStyle: TextStyle(
                        color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search,
                          color: FlowPayColors.emerald600, size: 20),
                      filled: true,
                      fillColor: isDark ? FlowPayColors.darkSurfaceElevated : const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: FlowPayRadii.input,
                        borderSide: BorderSide(
                          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: FlowPayRadii.input,
                        borderSide: BorderSide(
                          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: FlowPayRadii.input,
                        borderSide: BorderSide(
                          color: FlowPayColors.emerald600,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (q) {
                      setModalState(() {
                        if (q.trim().isEmpty) {
                          filteredBanks = List.from(_availableBanks);
                        } else {
                          final term = q.trim().toLowerCase();
                          filteredBanks = _availableBanks.where((b) {
                            return b.name.toLowerCase().contains(term) ||
                                b.code.contains(term) ||
                                b.slug.toLowerCase().contains(term);
                          }).toList();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: filteredBanks.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                        height: 1,
                      ),
                      itemBuilder: (ctx, index) {
                        final bank = filteredBanks[index];
                        final isSelected = _selectedBank?.code == bank.code;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FlowPayColors.emerald600.withAlpha(isDark ? 40 : 25)
                                  : (isDark ? FlowPayColors.darkSurfaceElevated : const Color(0xFFF3F4F6)),
                              borderRadius: FlowPayRadii.avatar,
                            ),
                            child: Icon(
                              Icons.account_balance_rounded,
                              color: isSelected
                                  ? FlowPayColors.emerald600
                                  : (isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280)),
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bank.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? FlowPayColors.emerald600
                                        : (isDark ? Colors.white : FlowPayColors.ink),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (bank.isPopular)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: FlowPayColors.emerald600.withAlpha(isDark ? 30 : 20),
                                    borderRadius: FlowPayRadii.chip,
                                  ),
                                  child: const Text(
                                    'Popular',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: FlowPayColors.emerald600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            'Code: ${bank.code}',
                            style: TextStyle(
                              color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                              fontSize: 11,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: FlowPayColors.emerald600, size: 20)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedBank = bank;
                            });
                            Navigator.of(ctx).pop();
                            if (_bankAccountController.text.trim().length == 10) {
                              _resolveBankAccount(_bankAccountController.text.trim(), bank.code);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

      // Attempt beneficiary alias resolution
      final res =
          await widget.appState.beneficiaryRepo.resolveAlias(intent.recipient);
      if (res.isUnique && res.match != null) {
        _resolvedBeneficiary = res.match;
      } else if (res.isAmbiguous) {
        _clarificationQuestions = [
          ClarificationQuestion(
            id: 'recipient_clarification',
            question: 'Which ${intent.recipient} did you mean?',
            description: 'Select your registered contact to proceed safely:',
            options: res.candidates
                .map((b) => ClarificationOption(
                      id: b.id,
                      label: '${b.legalName} (${b.nickname})',
                      subtitle: '${b.accountOrAddress} • ${b.countryFlag}',
                      icon: Icons.verified_user,
                    ))
                .toList(),
          ),
        ];
      }

      if (!mounted) return;
      setState(() {
        _recipientController.text = intent.recipient;
        _amountController.text = intent.amount;
        _selectedCurrency = intent.currency;
        _purposeController.text = intent.purpose ?? '';
        _analysisStep = 'Inspecting wallet balances & routing...';
      });

      await _runBalanceInspection(intentOverride: intent);

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisStep = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String friendlyMsg = 'Could not process instruction: $e';
      if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('ClientException')) {
        friendlyMsg = 'Live backend is currently offline. Operating in on-device local parser mode.';
      }
      setState(() {
        _isAnalyzing = false;
        _analysisStep = null;
        _errorMessage = friendlyMsg;
      });
    }
  }

  /// Step 2: Deterministic Balance-Aware Multi-Currency Inspection
  Future<void> _runBalanceInspection({TransferIntent? intentOverride}) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amountMoney = Money.fromMajorString(amountText, _selectedCurrency);
    final recipient = _recipientController.text.trim();

    // Check alias on manual entry
    if (intentOverride == null) {
      if (recipient.isNotEmpty) {
        if (_resolvedBeneficiary == null ||
            !_resolvedBeneficiary!.allAliases.any(
                (a) => a.toLowerCase() == recipient.toLowerCase())) {
          final res =
              await widget.appState.beneficiaryRepo.resolveAlias(recipient);
          if (res.isUnique) {
            _resolvedBeneficiary = res.match;
          } else {
            _resolvedBeneficiary = null;
          }
        }
      } else {
        _resolvedBeneficiary = null;
      }
    }

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
          purpose: _purposeController.text.trim().isNotEmpty
              ? _purposeController.text.trim()
              : null,
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
        _errorMessage =
            'Please enter a valid transfer amount greater than zero.';
      });
      return;
    }

    if (_inspectionResult == null || _selectedFundingOption == null) {
      await _runBalanceInspection();
    }

    if (_inspectionResult == null ||
        !_inspectionResult!.isPossible ||
        _selectedFundingOption == null) {
      setState(() {
        _errorMessage = _inspectionResult?.reason ??
            TransferErrorCode.insufficientFunds.humanReadableMessage;
      });
      return;
    }

    final amountMoney = Money.fromMajorString(amountText, _selectedCurrency);
    final intent = TransferIntent(
      intentId: 'tx_intent_${DateTime.now().millisecondsSinceEpoch}',
      originalPrompt: _nlController.text.trim().isNotEmpty
          ? _nlController.text.trim()
          : 'Send ${amountMoney.toMajorString()} ${_selectedCurrency.code} to $recipient',
      recipient: recipient,
      amount: amountMoney.toMajorString(),
      amountMinor: amountMoney.amountMinor.toString(),
      currency: _selectedCurrency,
      purpose: _purposeController.text.trim().isNotEmpty
          ? _purposeController.text.trim()
          : null,
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
      _analysisStep = 'Creating transfer proposal...';
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
        _errorMessage = 'Could not generate transfer proposal: $e';
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

    // Step 6: Submit Signature to FlowPay Backend -> Execution
    setState(() {
      _isAnalyzing = true;
      _analysisStep = 'Submitting signature to network rails...';
    });

    try {
      final execution = await widget.appState.transferRepo.executeProposal(
        proposalId: proposal.proposalId,
        signature: signature,
        proposal: proposal,
      );

      // Debit funding wallet
      try {
        await widget.appState.walletRepo.debitWallet(
          walletId: fundingOption.fundingWalletId,
          amount: fundingOption.totalDebit,
        );
      } catch (_) {}

      // Record activity in ActivityRepository
      try {
        final act = ActivityModel(
          id: 'act_send_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Sent ${intent.amount} ${intent.currency.code}',
          description: 'Transfer to ${intent.recipient} (${fundingOption.conversionLabel})',
          amount: Money.fromMajorString(intent.amount, intent.currency),
          currency: intent.currency,
          type: fundingOption.requiresConversion ? ActivityType.conversion : ActivityType.transfer,
          category: fundingOption.requiresConversion ? ActivityCategory.fx : ActivityCategory.transfer,
          status: FlowPayAppStatus.completed,
          timestamp: DateTime.now(),
          reference: execution.transactionHash,
        );
        await widget.appState.activityRepo.recordActivity(act);
      } catch (_) {}

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
        final errStr = e.toString();
        if (errStr.contains('SocketException') ||
            errStr.contains('Failed host lookup') ||
            errStr.contains('ClientException') ||
            errStr.contains('errno = 7')) {
          _errorMessage =
              'Transfer failed: Unable to connect to the FlowPay network. Please check your internet connection and try again.';
        } else {
          _errorMessage = 'Transfer failed: $e';
        }
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
      _resolvedBeneficiary = null;
      _clarificationQuestions = null;
    });
    _runBalanceInspection();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget bodyContent = _isLoadingWallets
        ? const Center(
            child: CircularProgressIndicator(color: FlowPayColors.emerald600))
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // Global Security Rail Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkSurface : Colors.white,
                  borderRadius: FlowPayRadii.cardSmall,
                  border: Border.all(
                    color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  ),
                  boxShadow: isDark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x080F1712),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: FlowPayColors.emerald600.withAlpha(isDark ? 35 : 20),
                        borderRadius: FlowPayRadii.avatar,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: FlowPayColors.emerald600, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FlowPay Global Execution Rail',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            'Balance-Aware • AI Extracts • Hardware PIN Signed',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FlowPayColors.emerald600.withAlpha(isDark ? 30 : 20),
                        borderRadius: FlowPayRadii.chip,
                        border: Border.all(
                          color: FlowPayColors.emerald600.withAlpha(isDark ? 70 : 50),
                        ),
                      ),
                      child: const Text(
                        'FlowPay BMONI Rail',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: FlowPayColors.emerald600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 1. Natural Language Entry Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkSurface : Colors.white,
                  borderRadius: FlowPayRadii.cardMedium,
                  border: Border.all(
                    color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  ),
                  boxShadow: isDark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x080F1712),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: FlowPayColors.emerald600.withAlpha(isDark ? 35 : 20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              color: FlowPayColors.emerald600, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Natural Language Entry',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tell FlowPay where and how much you want to send in plain words.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      key: const Key('send_money_nl_input'),
                      controller: _nlController,
                      style: TextStyle(
                        color: isDark ? Colors.white : FlowPayColors.ink,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. "Send \$500 to my designer in Ghana."',
                        hintStyle: TextStyle(
                          color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark ? FlowPayColors.darkSurfaceElevated : const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                            color: FlowPayColors.emerald600,
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: IconButton(
                          key: const Key('send_money_analyze_button'),
                          icon: const Icon(Icons.arrow_forward_rounded,
                              color: FlowPayColors.emerald600),
                          onPressed: () =>
                              _handleAnalyzeNaturalLanguage(_nlController.text),
                          tooltip: 'Analyze',
                        ),
                      ),
                      onSubmitted: _handleAnalyzeNaturalLanguage,
                    ),

                    const SizedBox(height: 12),

                    // Suggestion Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _suggestionChips.map((chip) {
                        return InkWell(
                          key: Key(
                              'chip_${chip.replaceAll(RegExp(r'\s+'), '_')}'),
                          onTap: () {
                            _nlController.text = chip;
                            _handleAnalyzeNaturalLanguage(chip);
                          },
                          borderRadius: FlowPayRadii.chip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? FlowPayColors.darkSurfaceElevated : const Color(0xFFF3F4F6),
                              borderRadius: FlowPayRadii.chip,
                              border: Border.all(
                                color: isDark ? FlowPayColors.darkBorder : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              chip,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : const Color(0xFF374151),
                                fontWeight: FontWeight.w600,
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
                    color: FlowPayColors.emerald600.withAlpha(isDark ? 30 : 15),
                    borderRadius: FlowPayRadii.cardSmall,
                    border: Border.all(
                        color: FlowPayColors.emerald600.withAlpha(isDark ? 80 : 50)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: FlowPayColors.emerald600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _analysisStep ?? 'Processing...',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: FlowPayColors.emerald600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 2.5 Progressive Clarification Card
              if (_clarificationQuestions != null) ...[
                const SizedBox(height: 14),
                AiClarificationCard(
                  title: 'Clarification Required',
                  questions: _clarificationQuestions!,
                  onOptionSelected: (updatedQ) async {
                    if (updatedQ.selectedOptionId != null) {
                      final all = await widget.appState.beneficiaryRepo.getBeneficiaries();
                      final match = all.where((b) => b.id == updatedQ.selectedOptionId).firstOrNull;
                      if (match != null) {
                        setState(() {
                          _resolvedBeneficiary = match;
                          _recipientController.text = match.accountOrAddress;
                          _clarificationQuestions = null;
                        });
                        _runBalanceInspection();
                      } else {
                        setState(() {
                          _clarificationQuestions = null;
                        });
                      }
                    } else {
                      setState(() {
                        _clarificationQuestions = null;
                      });
                    }
                  },
                  onCancel: () =>
                      setState(() => _clarificationQuestions = null),
                ),
              ],

              // 3. Error Banner
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FlowPayColors.error.withAlpha(20),
                    borderRadius: FlowPayRadii.cardSmall,
                    border: Border.all(
                        color: FlowPayColors.error.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: FlowPayColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FlowPayColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // 4. Form Fields (Recipient, Amount, Currency, Purpose)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkSurface : Colors.white,
                  borderRadius: FlowPayRadii.cardMedium,
                  border: Border.all(
                    color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  ),
                  boxShadow: isDark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x080F1712),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Recipient / Beneficiary',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF4B5563),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isBankMode = !_isBankMode;
                              if (_isBankMode && _selectedCurrency != Currency.ngn) {
                                _selectedCurrency = Currency.ngn;
                              }
                            });
                          },
                          borderRadius: FlowPayRadii.chip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _isBankMode
                                  ? FlowPayColors.emerald600.withAlpha(isDark ? 40 : 25)
                                  : (isDark ? FlowPayColors.darkSurfaceElevated : const Color(0xFFF3F4F6)),
                              borderRadius: FlowPayRadii.chip,
                              border: Border.all(
                                color: _isBankMode
                                    ? FlowPayColors.emerald600
                                    : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isBankMode ? Icons.account_balance : Icons.account_balance_outlined,
                                  size: 13,
                                  color: _isBankMode ? FlowPayColors.emerald600 : (isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isBankMode ? 'NGN Bank Rail' : 'Switch to NGN Bank',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _isBankMode ? FontWeight.bold : FontWeight.w500,
                                    color: _isBankMode ? FlowPayColors.emerald600 : (isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isBankMode) ...[
                      InkWell(
                        onTap: _openBankSelectorBottomSheet,
                        borderRadius: FlowPayRadii.input,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? FlowPayColors.darkSurfaceElevated : Colors.white,
                            borderRadius: FlowPayRadii.input,
                            border: Border.all(
                              color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: FlowPayColors.emerald600.withAlpha(isDark ? 40 : 25),
                                  borderRadius: FlowPayRadii.avatar,
                                ),
                                child: const Icon(
                                  Icons.account_balance_rounded,
                                  color: FlowPayColors.emerald600,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedBank?.name ?? 'Select Bank (GTB, OPay, Zenith...)',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : FlowPayColors.ink,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      _selectedBank != null
                                          ? 'Bank Code: ${_selectedBank!.code} • Tap to change bank'
                                          : 'Tap to browse Nigerian banks',
                                      style: TextStyle(
                                        color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bankAccountController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        style: TextStyle(
                          color: isDark ? Colors.white : FlowPayColors.ink,
                          fontSize: 15,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          prefixIcon: const Icon(Icons.pin_outlined,
                              color: FlowPayColors.emerald600, size: 20),
                          hintText: 'Enter 10-digit NUBAN account number',
                          hintStyle: TextStyle(
                            color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
                            fontSize: 13,
                            letterSpacing: 0,
                            fontWeight: FontWeight.normal,
                          ),
                          filled: true,
                          fillColor: isDark ? FlowPayColors.darkSurfaceElevated : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: FlowPayRadii.input,
                            borderSide: BorderSide(
                              color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: FlowPayRadii.input,
                            borderSide: BorderSide(
                              color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: FlowPayRadii.input,
                            borderSide: BorderSide(
                                color: FlowPayColors.emerald600, width: 1.5),
                          ),
                          suffixIcon: _isResolvingAccount
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: FlowPayColors.emerald600,
                                    ),
                                  ),
                                )
                              : (_resolvedBankAccount != null
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: FlowPayColors.success, size: 22)
                                  : null),
                        ),
                        onChanged: _onBankAccountChanged,
                      ),
                      if (_isResolvingAccount) ...[
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'Resolving account with Paystack & NIBSS...',
                              style: TextStyle(
                                fontSize: 11,
                                color: FlowPayColors.emerald600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_resolvedBankAccount != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: FlowPayColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: FlowPayRadii.cardSmall,
                            border: Border.all(color: FlowPayColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded,
                                  color: FlowPayColors.success, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _resolvedBankAccount!.accountName,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : FlowPayColors.ink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_resolvedBankAccount!.bankName} • ${_resolvedBankAccount!.accountNumber}',
                                      style: TextStyle(
                                        color: isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_resolvedBankAccount!.testNotice != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _resolvedBankAccount!.testNotice!,
                                        style: TextStyle(
                                          color: Colors.amber.shade700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_bankResolutionError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: FlowPayColors.error.withValues(alpha: 0.12),
                            borderRadius: FlowPayRadii.cardSmall,
                            border: Border.all(color: FlowPayColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: FlowPayColors.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _bankResolutionError!,
                                  style: const TextStyle(
                                    color: FlowPayColors.error,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      key: const Key('send_money_recipient_field'),
                      controller: _recipientController,
                      style: TextStyle(
                        color: isDark ? Colors.white : FlowPayColors.ink,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_search_outlined,
                            color: FlowPayColors.emerald600, size: 20),
                        hintText:
                            _isBankMode ? 'Resolved recipient name' : 'e.g. my designer in Ghana or name@example.com',
                        hintStyle: TextStyle(
                          color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark ? FlowPayColors.darkSurfaceElevated : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                              color: FlowPayColors.emerald600, width: 1.5),
                        ),
                      ),
                      onChanged: (_) => _runBalanceInspection(),
                    ),

                    if (_resolvedBeneficiary != null) ...[
                      const SizedBox(height: 10),
                      FlowPayBeneficiaryTile(
                        beneficiary: _resolvedBeneficiary!,
                      ),
                    ],

                    const SizedBox(height: 18),
                    Text(
                      'Transfer Amount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF4B5563),
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
                          backgroundColor: isDark ? FlowPayColors.darkSurface : Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: FlowPayRadii.sheet,
                          ),
                          builder: (ctx) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SectionHeader(
                                  title: 'Select Payment Currency',
                                  showBottomDivider: true,
                                ),
                                ...[
                                  Currency.usd,
                                  Currency.ngn,
                                  Currency.mxn,
                                  Currency.cad,
                                  Currency.eur
                                ].map((c) {
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isDark
                                          ? FlowPayColors.darkSurfaceElevated
                                          : FlowPayColors.mint100,
                                      child: Text(
                                        c.symbol,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: FlowPayColors.emerald700,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      c.name,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : FlowPayColors.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${c.stablecoinToken} Rail',
                                      style: TextStyle(
                                        color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: _selectedCurrency == c
                                        ? const Icon(Icons.check_circle,
                                            color: FlowPayColors.emerald600)
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
                    Text(
                      'Purpose / Memo (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _purposeController,
                      style: TextStyle(
                        color: isDark ? Colors.white : FlowPayColors.ink,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Design services, contractor payment',
                        hintStyle: TextStyle(
                          color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark ? FlowPayColors.darkSurfaceElevated : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: FlowPayRadii.input,
                          borderSide: BorderSide(
                              color: FlowPayColors.emerald600, width: 1.5),
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
                    color: isDark ? FlowPayColors.darkSurface : Colors.white,
                    borderRadius: FlowPayRadii.cardMedium,
                    border: Border.all(
                      color: _selectedFundingOption?.requiresConversion == true
                          ? FlowPayColors.emerald600.withAlpha(120)
                          : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_outlined,
                                    color: FlowPayColors.emerald600,
                                    size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Funding Source & Routing',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : FlowPayColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_selectedFundingOption?.requiresConversion ==
                              true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: FlowPayColors.emerald600.withAlpha(isDark ? 40 : 25),
                                borderRadius: FlowPayRadii.chip,
                                border: Border.all(
                                    color: FlowPayColors.emerald600.withAlpha(80)),
                              ),
                              child: Text(
                                _selectedFundingOption!.conversionLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Conversion notice if direct balance was insufficient
                      if (!_inspectionResult!.isDirectFunded &&
                          _selectedFundingOption != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: FlowPayColors.emerald600.withAlpha(isDark ? 25 : 15),
                            borderRadius: FlowPayRadii.cardSmall,
                            border: Border.all(
                                color: FlowPayColors.emerald600.withAlpha(50)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline,
                                  size: 16,
                                  color: FlowPayColors.emerald600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Balance-Aware Auto-Funding: Insufficient ${_selectedCurrency.code}. FlowPay routes settlement via ${_selectedFundingOption!.fundingWalletName} (${_selectedFundingOption!.availableBalance.formatFormatted()} available).',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white70 : const Color(0xFF374151),
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
                        Text(
                          'Choose Funding Wallet:',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 6),
                        ..._inspectionResult!.allFundingOptions.map((opt) {
                          final isSelected =
                              _selectedFundingOption?.fundingWalletId ==
                                  opt.fundingWalletId;
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedFundingOption = opt);
                            },
                            borderRadius: FlowPayRadii.cardSmall,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.mint100.withAlpha(50))
                                    : (isDark ? FlowPayColors.darkSurface : const Color(0xFFF9FAFB)),
                                borderRadius: FlowPayRadii.cardSmall,
                                border: Border.all(
                                  color: isSelected
                                      ? FlowPayColors.emerald600
                                      : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          size: 16,
                                          color: isSelected
                                              ? FlowPayColors.emerald600
                                              : (isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF)),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            opt.fundingWalletName,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isDark ? Colors.white : FlowPayColors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    opt.availableBalance.formatFormatted(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700,
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
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : FlowPayColors.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedFundingOption!.availableBalance.formatFormatted()} available',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],

                      if (_selectedFundingOption?.exchangeRate != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Exchange Rate: 1 ${_selectedCurrency.code} = ${_selectedFundingOption!.exchangeRate!.toStringAsFixed(2)} ${_selectedFundingOption!.fundingCurrency.code}',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 6. Review & Verify Primary Action Button
              FlowPayButton(
                key: const Key('send_money_review_button'),
                text: 'Review Transfer',
                size: FlowPayButtonSize.large,
                isLoading: _isAnalyzing,
                onPressed: _openReviewConfirmation,
              ),
              const SizedBox(height: 24),
            ],
          );

    if (canPop) {
      return Scaffold(
        backgroundColor: isDark ? FlowPayColors.darkBackground : FlowPayColors.paper,
        appBar: AppBar(
          backgroundColor: isDark ? FlowPayColors.darkBackground : FlowPayColors.paper,
          elevation: 0,
          title: Text(
            'Send Money',
            style: TextStyle(
                color: isDark ? Colors.white : FlowPayColors.ink,
                fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : FlowPayColors.ink, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: bodyContent,
      );
    }

    return Material(
      color: isDark ? FlowPayColors.darkBackground : FlowPayColors.paper,
      child: bodyContent,
    );
  }
}
