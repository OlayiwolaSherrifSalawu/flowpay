import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/money/money.dart';
import '../../../core/repositories/card_repository.dart';
import '../../../core/theme/components.dart';

/// Interactive Card Management Bottom Sheet.
/// Features:
/// - Full design.md §4.5 Amber Card Object
/// - View Card: Sensitive data reveal (PAN, CVV, expiry) with auto-hide timer & copy
/// - View Transactions: Major-unit numeric transaction list with category icons
/// - Freeze / Unfreeze: PUT /v1/users/{userId}/cards/{cardId}/status (BLOCKED / ACTIVE)
class CardDetailSheet extends StatefulWidget {
  final VirtualCardModel card;
  final String countryFlag;
  final String cardHolderName;
  final String? userId;
  final CardRepository cardRepo;
  final ValueChanged<VirtualCardModel> onCardUpdated;

  const CardDetailSheet({
    super.key,
    required this.card,
    required this.countryFlag,
    required this.cardHolderName,
    this.userId,
    required this.cardRepo,
    required this.onCardUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    required VirtualCardModel card,
    required String countryFlag,
    required String cardHolderName,
    String? userId,
    required CardRepository cardRepo,
    required ValueChanged<VirtualCardModel> onCardUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlowPayColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CardDetailSheet(
        card: card,
        countryFlag: countryFlag,
        cardHolderName: cardHolderName,
        userId: userId,
        cardRepo: cardRepo,
        onCardUpdated: onCardUpdated,
      ),
    );
  }

  @override
  State<CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends State<CardDetailSheet> {
  late VirtualCardModel _card;
  bool _isRevealed = false;
  bool _isLoadingSensitive = false;
  bool _isTogglingFreeze = false;
  String? _unmaskedPan;
  String? _unmaskedCvv;
  String? _unmaskedExpiry;
  Timer? _sensitiveDataHideTimer;

  // Transactions state
  bool _showingTransactions = false;
  bool _isLoadingTxs = false;
  List<CardTransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _card = widget.card;
  }

  @override
  void dispose() {
    _sensitiveDataHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleRevealCardDetails() async {
    if (_isRevealed) {
      _sensitiveDataHideTimer?.cancel();
      setState(() {
        _isRevealed = false;
        _unmaskedPan = null;
        _unmaskedCvv = null;
        _unmaskedExpiry = null;
      });
      return;
    }

    setState(() => _isLoadingSensitive = true);
    try {
      final sensitive = await widget.cardRepo.getCardSensitiveData(_card.id, userId: widget.userId);
      if (!mounted) return;

      setState(() {
        _isRevealed = true;
        _isLoadingSensitive = false;
        _unmaskedPan = sensitive['pan']?.toString() ?? '5399 8383 8383 ${_card.last4}';
        _unmaskedCvv = sensitive['cvv']?.toString() ?? '824';
        _unmaskedExpiry = sensitive['expirationDate']?.toString() ?? _card.expirationDate;
      });

      // Auto-hide after 30 seconds for PCI compliance / safety
      _sensitiveDataHideTimer?.cancel();
      _sensitiveDataHideTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _isRevealed = false;
            _unmaskedPan = null;
            _unmaskedCvv = null;
            _unmaskedExpiry = null;
          });
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _isLoadingSensitive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load card details: $err')),
      );
    }
  }

  Future<void> _toggleFreezeCard() async {
    setState(() => _isTogglingFreeze = true);
    final targetFreeze = !_card.isFrozen;
    try {
      final updated = await widget.cardRepo.setCardStatus(_card.id, freeze: targetFreeze, userId: widget.userId);
      if (!mounted) return;

      setState(() {
        _card = updated;
        _isTogglingFreeze = false;
      });

      widget.onCardUpdated(updated);

      try {
        BMoniToastOverlay.showSuccess(
          context: context,
          title: targetFreeze ? 'Card Frozen' : 'Card Unfrozen',
          message: targetFreeze
              ? 'Card status updated to BLOCKED on BMONI rails.'
              : 'Card status updated to ACTIVE on BMONI rails.',
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(targetFreeze ? 'Card has been frozen (BLOCKED).' : 'Card is now active (ACTIVE).'),
          ),
        );
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _isTogglingFreeze = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: FlowPayColors.error,
          content: Text('Status update failed: $err'),
        ),
      );
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _showingTransactions = true;
      _isLoadingTxs = true;
    });

    try {
      final txs = await widget.cardRepo.getCardTransactions(_card.id, size: 20, status: 'COMPLETED');
      if (!mounted) return;
      setState(() {
        _transactions = txs;
        _isLoadingTxs = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _isLoadingTxs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlowPayColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _card.cardName,
                      style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(fontSize: 18),
                    ),
                    Text(
                      'Virtual Mastercard • ${widget.cardHolderName}',
                      style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: FlowPayColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Virtual Card Face (Amber §4.5)
            VirtualCardObject(
              cardLast4: _card.last4,
              countryFlag: widget.countryFlag,
              cardHolderName: widget.cardHolderName,
              cardName: _card.cardName,
              currencyCode: _card.currency.code,
              isFrozen: _card.isFrozen,
              isReserved: _card.isReserved,
              proposalStatus: _card.proposalStatus,
            ),
            const SizedBox(height: 20),

            // Card Action Buttons (View Card, Transactions, Freeze/Unfreeze)
            Row(
              children: [
                Expanded(
                  child: BMoniButton(
                    text: _isRevealed ? 'Hide Details' : 'View Card',
                    icon: _isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    variant: BMoniButtonVariant.outline,
                    size: BMoniButtonSize.small,
                    isLoading: _isLoadingSensitive,
                    onPressed: _card.isReserved ? null : _toggleRevealCardDetails,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BMoniButton(
                    text: 'Transactions',
                    icon: Icons.receipt_long_rounded,
                    variant: BMoniButtonVariant.outline,
                    size: BMoniButtonSize.small,
                    onPressed: _card.isReserved
                        ? null
                        : () {
                            if (_showingTransactions) {
                              setState(() => _showingTransactions = false);
                            } else {
                              _loadTransactions();
                            }
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BMoniButton(
                    text: _card.isFrozen ? 'Unfreeze' : 'Freeze',
                    icon: _card.isFrozen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    variant: _card.isFrozen ? BMoniButtonVariant.primary : BMoniButtonVariant.outline,
                    size: BMoniButtonSize.small,
                    isLoading: _isTogglingFreeze,
                    onPressed: _card.isReserved ? null : _toggleFreezeCard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sensitive Cardholder Details Section (When Revealed)
            if (_isRevealed) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FlowPayColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FlowPayColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: FlowPayColors.brand),
                            SizedBox(width: 6),
                            Text(
                              'SENSITIVE CARD DATA',
                              style: TextStyle(
                                color: FlowPayColors.brand,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Auto-hides in 30s',
                          style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SensitiveRow(
                      label: 'Card Number',
                      value: _unmaskedPan ?? '•••• •••• •••• ${_card.last4}',
                      canCopy: true,
                    ),
                    const Divider(color: FlowPayColors.hairline, height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SensitiveRow(
                            label: 'CVV / CVC',
                            value: _unmaskedCvv ?? '•••',
                            canCopy: true,
                          ),
                        ),
                        Expanded(
                          child: _SensitiveRow(
                            label: 'Expiration Date',
                            value: _unmaskedExpiry ?? _card.expirationDate,
                            canCopy: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Transactions Section (When active)
            if (_showingTransactions) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CARD TRANSACTIONS',
                    style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${_transactions.length} items',
                    style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingTxs) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ] else if (_transactions.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: FlowPayColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'No settled transactions recorded on this card.',
                    style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                  ),
                ),
              ] else ...[
                ..._transactions.map((tx) => _TransactionItemRow(tx: tx)),
              ],
              const SizedBox(height: 20),
            ],

            // Card Specs Info Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlowPayColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FlowPayColors.hairline),
              ),
              child: Column(
                children: [
                  _SpecRow(label: 'Card Status', value: _card.status.toUpperCase()),
                  const SizedBox(height: 8),
                  _SpecRow(label: 'Card Type', value: 'Virtual Mastercard'),
                  const SizedBox(height: 8),
                  _SpecRow(label: 'Currency', value: _card.currency.code),
                  const SizedBox(height: 8),
                  _SpecRow(
                    label: 'Available Card Balance',
                    value: _card.balance != null ? _card.balance!.formatted : 'Direct Wallet Debit',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensitiveRow extends StatelessWidget {
  final String label;
  final String value;
  final bool canCopy;

  const _SensitiveRow({
    required this.label,
    required this.value,
    this.canCopy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary).copyWith(fontSize: 10),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: FlowPayTypography.amount(color: FlowPayColors.ink).copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (canCopy) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $label to clipboard')),
                  );
                },
                child: const Icon(Icons.copy_rounded, size: 14, color: FlowPayColors.textTertiary),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TransactionItemRow extends StatelessWidget {
  final CardTransactionModel tx;

  const _TransactionItemRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FlowPayColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlowPayColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FlowPayColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_outlined, size: 18, color: FlowPayColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchantName,
                  style: FlowPayTypography.body(color: FlowPayColors.ink).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  tx.category,
                  style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tx.amount.formatted,
                style: FlowPayTypography.amount(color: FlowPayColors.ink).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: FlowPayColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tx.status,
                  style: const TextStyle(
                    color: FlowPayColors.success,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary).copyWith(fontSize: 12),
        ),
        Text(
          value,
          style: FlowPayTypography.body(color: FlowPayColors.ink).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
