import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../beneficiaries/beneficiary_model.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'amount_display.dart';
import 'buttons.dart';

export 'amount_display.dart';
export 'bottom_sheets.dart';
export 'buttons.dart';
export 'cards.dart';
export 'currency_display.dart';
export 'dialogs.dart';
export 'input_fields.dart';
export 'states.dart';
export 'status_badges.dart';

/// FlowPay Scaffold — Universal Responsive Application Layout Container
/// Adapts cleanly across mobile, tablet, and desktop viewports with responsive padding.
class FlowPayScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final Widget? drawer;

  const FlowPayScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? FlowPayColors.darkBackground : FlowPayColors.lightBackground);

    return Scaffold(
      backgroundColor: bg,
      appBar: appBar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Tablet / Desktop centered container
            if (constraints.maxWidth > 900) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: body,
                ),
              );
            }
            return body;
          },
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      drawer: drawer,
    );
  }
}

/// FlowPay Amount — Formatted Financial Number with Tabular Figures
class FlowPayAmount extends StatelessWidget {
  final Money amount;
  final double fontSize;
  final Color? color;
  final bool showSign;
  final bool isNegative;
  final String? secondaryLabel;

  const FlowPayAmount({
    super.key,
    required this.amount,
    this.fontSize = 24,
    this.color,
    this.showSign = false,
    this.isNegative = false,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return FlowPayAmountDisplay(
      amount: amount.toMajorString(),
      currencySymbol: amount.currency.symbol,
      currencyCode: amount.currency.code,
      color: color,
      isCredit: showSign && !isNegative,
      isDebit: showSign && isNegative,
      secondaryAmount: secondaryLabel,
    );
  }
}

/// FlowPay Balance — Master Portfolio Balance Display
/// Shows total valuation, multi-currency breakdown, available vs reserved split,
/// and an interactive privacy toggle.
class FlowPayBalance extends StatefulWidget {
  final Money totalBalance;
  final Money availableBalance;
  final Money? reservedBalance;
  final String? secondaryValuation;
  final VoidCallback? onSend;
  final VoidCallback? onAddFunds;
  final VoidCallback? onConvert;

  const FlowPayBalance({
    super.key,
    required this.totalBalance,
    required this.availableBalance,
    this.reservedBalance,
    this.secondaryValuation,
    this.onSend,
    this.onAddFunds,
    this.onConvert,
  });

  @override
  State<FlowPayBalance> createState() => _FlowPayBalanceState();
}

class _FlowPayBalanceState extends State<FlowPayBalance> {
  bool _isHidden = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusXl,
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + Privacy Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL PORTFOLIO VALUATION',
                style: FlowPayTypography.caption.copyWith(
                  color: isDark
                      ? FlowPayColors.darkTextSecondary
                      : FlowPayColors.lightTextSecondary,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isHidden ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: FlowPayColors.darkTextSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: _isHidden ? 'Show Balance' : 'Hide Balance',
                onPressed: () => setState(() => _isHidden = !_isHidden),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Amount Display
          if (_isHidden)
            Text(
              '••••••••••',
              style: FlowPayTypography.display(
                color: isDark
                    ? FlowPayColors.darkTextPrimary
                    : FlowPayColors.lightTextPrimary,
              ),
            )
          else
            FlowPayAmount(
              amount: widget.totalBalance,
              fontSize: 38,
              color: isDark
                  ? FlowPayColors.darkTextPrimary
                  : FlowPayColors.lightTextPrimary,
            ),

          if (widget.secondaryValuation != null && !_isHidden) ...[
            const SizedBox(height: 4),
            Text(
              widget.secondaryValuation!,
              style: FlowPayTypography.caption.copyWith(
                color: FlowPayColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(height: 1, color: FlowPayColors.hairline),
          const SizedBox(height: 14),

          // Available vs Reserved Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Liquidity',
                      style: FlowPayTypography.captionStyle(
                        color: isDark
                            ? FlowPayColors.darkTextSecondary
                            : FlowPayColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isHidden
                          ? '••••••'
                          : widget.availableBalance.formattedWithSymbol,
                      style: FlowPayTypography.amount(
                        color: isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary,
                      ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (widget.reservedBalance != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: FlowPayColors.amber,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Reserved Funds',
                            style: FlowPayTypography.captionStyle(
                              color: FlowPayColors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isHidden
                            ? '••••••'
                            : widget.reservedBalance!.formattedWithSymbol,
                        style: FlowPayTypography.amount(
                          color: FlowPayColors.amber,
                        ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (widget.onSend != null || widget.onAddFunds != null || widget.onConvert != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.onSend != null)
                  Expanded(
                    child: FlowPayButton(
                      text: 'Send',
                      icon: Icons.arrow_outward,
                      size: FlowPayButtonSize.small,
                      onPressed: widget.onSend,
                    ),
                  ),
                if (widget.onAddFunds != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FlowPayButton(
                      text: 'Add Funds',
                      icon: Icons.add,
                      variant: FlowPayButtonVariant.secondary,
                      size: FlowPayButtonSize.small,
                      onPressed: widget.onAddFunds,
                    ),
                  ),
                ],
                if (widget.onConvert != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FlowPayButton(
                      text: 'Convert',
                      icon: Icons.currency_exchange,
                      variant: FlowPayButtonVariant.secondary,
                      size: FlowPayButtonSize.small,
                      onPressed: widget.onConvert,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Background configuration for FlowPayHeroCard
class BMoniWalletCardBackground {
  final Gradient? gradient;
  final Color? color;
  const BMoniWalletCardBackground.gradient(this.gradient) : color = null;
  const BMoniWalletCardBackground.solid(this.color) : gradient = null;
}

/// FlowPay Hero Card — Obsidian Slate Container for Account Portfolio
class FlowPayHeroCard extends StatelessWidget {
  final double? height;
  final Widget balanceChild;
  final BMoniWalletCardBackground? background;
  final Decoration? decoration;

  const FlowPayHeroCard({
    super.key,
    this.height,
    required this.balanceChild,
    this.background,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(22),
      decoration: decoration ??
          BoxDecoration(
            gradient: background?.gradient ??
                const LinearGradient(
                  colors: [
                    Color(0xFF181B26),
                    Color(0xFF12141C),
                    Color(0xFF090A0F),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            color: background?.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FlowPayColors.darkBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
      child: balanceChild,
    );
  }
}

typedef BMoniWalletCard = FlowPayHeroCard;

/// FlowPay Balance Display — Tabular Monospaced Figure with Privacy Toggle
class FlowPayBalanceDisplay extends StatelessWidget {
  final String wholePart;
  final String decimalPart;
  final bool isHidden;
  final VoidCallback? onToggleHidden;
  final Color? balanceColor;
  final Color? decimalColor;

  const FlowPayBalanceDisplay({
    super.key,
    required this.wholePart,
    required this.decimalPart,
    this.isHidden = false,
    this.onToggleHidden,
    this.balanceColor,
    this.decimalColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleHidden,
      behavior: HitTestBehavior.opaque,
      child: isHidden
          ? Text(
              '••••••',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: balanceColor ?? Colors.white,
                letterSpacing: 2.0,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  wholePart,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: balanceColor ?? Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  decimalPart,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: decimalColor ?? FlowPayColors.primaryLight,
                  ),
                ),
              ],
            ),
    );
  }
}

typedef BMoniWalletCardBalance = FlowPayBalanceDisplay;


/// FlowPay Status Badge — Live status badge with solid or pulsing dot
class FlowPayStatus extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;

  const FlowPayStatus({
    super.key,
    required this.label,
    required this.color,
    this.showDot = true,
  });

  const FlowPayStatus.active(this.label, {super.key})
      : color = FlowPayColors.primary,
        showDot = true;

  const FlowPayStatus.pending(this.label, {super.key})
      : color = FlowPayColors.amber,
        showDot = true;

  const FlowPayStatus.failed(this.label, {super.key})
      : color = FlowPayColors.error,
        showDot = true;

  const FlowPayStatus.neutral(this.label, {super.key})
      : color = FlowPayColors.darkTextSecondary,
        showDot = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// FlowPay Transaction Tile — Activity Item
class FlowPayTransactionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timestamp;
  final Money amount;
  final bool isIncoming;
  final String status;
  final IconData? icon;
  final VoidCallback? onTap;

  const FlowPayTransactionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.amount,
    this.isIncoming = false,
    this.status = 'COMPLETED',
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountColor = isIncoming
        ? FlowPayColors.primary
        : (isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary);
    final sign = isIncoming ? '+' : '-';

    return InkWell(
      onTap: onTap,
      borderRadius: FlowPaySpacing.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.lightSurfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                ),
              ),
              child: Icon(
                icon ?? (isIncoming ? Icons.arrow_downward : Icons.arrow_upward),
                size: 18,
                color: isIncoming ? FlowPayColors.primary : FlowPayColors.darkTextSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlowPayTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? FlowPayColors.darkTextPrimary
                          : FlowPayColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$subtitle • $timestamp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlowPayTypography.captionStyle(
                      color: FlowPayColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${amount.formattedWithSymbol}',
                  style: FlowPayTypography.amount(color: amountColor).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (status.toUpperCase() != 'COMPLETED') ...[
                  const SizedBox(height: 2),
                  FlowPayStatus.pending(status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// FlowPay Beneficiary Tile — Counterparty with Alias Resolution Support
class FlowPayBeneficiaryTile extends StatelessWidget {
  final String nickname;
  final String legalName;
  final String countryFlag;
  final String currencyCode;
  final String accountOrAddress;
  final bool isVerified;
  final Beneficiary? beneficiary;
  final VoidCallback? onTap;
  final VoidCallback? onSend;

  const FlowPayBeneficiaryTile({
    super.key,
    this.nickname = '',
    this.legalName = '',
    this.countryFlag = '',
    this.currencyCode = '',
    this.accountOrAddress = '',
    this.isVerified = true,
    this.beneficiary,
    this.onTap,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveNickname = beneficiary?.nickname ?? nickname;
    final effectiveLegalName = beneficiary?.legalName ?? legalName;
    final effectiveCountryFlag = beneficiary?.countryFlag ?? countryFlag;
    final effectiveCurrencyCode = beneficiary?.currency.code ?? currencyCode;
    final effectiveAccount = beneficiary?.accountOrAddress ?? accountOrAddress;
    final effectiveVerified = beneficiary?.isVerified ?? isVerified;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusLg,
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: FlowPayColors.primary.withAlpha(35),
              child: Text(
                effectiveNickname.isNotEmpty ? effectiveNickname[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: FlowPayColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Text(effectiveCountryFlag, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(
              effectiveNickname,
              style: FlowPayTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? FlowPayColors.darkTextPrimary
                    : FlowPayColors.lightTextPrimary,
              ),
            ),
            if (effectiveNickname.toLowerCase() != effectiveLegalName.toLowerCase() && effectiveLegalName.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '($effectiveLegalName)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
            if (effectiveVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, size: 14, color: FlowPayColors.primary),
            ],
          ],
        ),
        subtitle: Text(
          '$effectiveCurrencyCode • $effectiveAccount',
          style: FlowPayTypography.captionStyle(
            color: FlowPayColors.darkTextSecondary,
          ),
        ),
        trailing: onSend != null
            ? IconButton(
                icon: const Icon(Icons.send_rounded,
                    size: 18, color: FlowPayColors.primary),
                onPressed: onSend,
                tooltip: 'Send Money',
              )
            : const Icon(Icons.chevron_right, size: 20, color: FlowPayColors.darkTextSecondary),
      ),
    );
  }
}

/// FlowPay Money Mission Card
class FlowPayMissionCardWidget extends StatelessWidget {
  final String title;
  final String tagline;
  final String status;
  final double currentProgress;
  final double targetProgress;
  final String sourceLabel;
  final String allocationLabel;
  final String destinationLabel;
  final bool isActive;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback? onEdit;
  final VoidCallback? onTrigger;

  const FlowPayMissionCardWidget({
    super.key,
    required this.title,
    required this.tagline,
    required this.status,
    required this.currentProgress,
    required this.targetProgress,
    required this.sourceLabel,
    required this.allocationLabel,
    required this.destinationLabel,
    required this.isActive,
    required this.onToggleActive,
    this.onEdit,
    this.onTrigger,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressFraction = (targetProgress > 0)
        ? (currentProgress / targetProgress).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusXl,
        border: Border.all(
          color: isActive
              ? FlowPayColors.primary.withAlpha(90)
              : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? FlowPayColors.primary.withAlpha(15)
                : const Color(0x08000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? FlowPayColors.primary.withAlpha(35)
                      : FlowPayColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bolt,
                  size: 18,
                  color: isActive ? FlowPayColors.primary : FlowPayColors.darkTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FlowPayTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlowPayTypography.captionStyle(
                        color: FlowPayColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? FlowPayColors.primary
                      : null,
                ),
                activeTrackColor: FlowPayColors.primary.withAlpha(80),
                onChanged: onToggleActive,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 6,
              backgroundColor: isDark
                  ? FlowPayColors.darkSurfaceElevated
                  : FlowPayColors.lightSurfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                isActive ? FlowPayColors.primary : FlowPayColors.darkTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Progress Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${currentProgress.toStringAsFixed(0)} / \$${targetProgress.toStringAsFixed(0)}',
                style: FlowPayTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? FlowPayColors.darkTextPrimary
                      : FlowPayColors.lightTextPrimary,
                ),
              ),
              Text(
                '${(progressFraction * 100).toInt()}% completed',
                style: FlowPayTypography.captionStyle(
                  color: FlowPayColors.darkTextSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: FlowPayColors.hairline),
          const SizedBox(height: 12),

          // Rules Summary (Source -> Allocation -> Destination)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? FlowPayColors.darkSurfaceElevated
                  : FlowPayColors.lightSurfaceElevated,
              borderRadius: FlowPaySpacing.borderRadiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRuleColumn('Source', sourceLabel),
                const Icon(Icons.arrow_forward, size: 14, color: FlowPayColors.darkTextSecondary),
                _buildRuleColumn('Allocation', allocationLabel),
                const Icon(Icons.arrow_forward, size: 14, color: FlowPayColors.darkTextSecondary),
                _buildRuleColumn('Destination', destinationLabel),
              ],
            ),
          ),

          if (onTrigger != null || onEdit != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Edit Rule'),
                  ),
                if (onTrigger != null) ...[
                  const SizedBox(width: 8),
                  FlowPayButton(
                    text: 'Run Now',
                    icon: Icons.play_arrow_rounded,
                    size: FlowPayButtonSize.small,
                    onPressed: onTrigger,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: FlowPayColors.darkTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: FlowPayColors.ink,
          ),
        ),
      ],
    );
  }
}

/// FlowPay Approval Card — Prominently surfaces items awaiting PIN authorization
class FlowPayApprovalCard extends StatelessWidget {
  final String title;
  final String description;
  final String amountFormatted;
  final String currency;
  final VoidCallback onReview;
  final VoidCallback? onDismiss;

  const FlowPayApprovalCard({
    super.key,
    required this.title,
    required this.description,
    required this.amountFormatted,
    required this.currency,
    required this.onReview,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowPayColors.amber.withAlpha(20),
        borderRadius: FlowPaySpacing.borderRadiusLg,
        border: Border.all(color: FlowPayColors.amber.withAlpha(90), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FlowPayColors.amber.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 16, color: FlowPayColors.amber),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'APPROVAL REQUIRED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: FlowPayColors.amber,
                  ),
                ),
              ),
              Text(
                amountFormatted,
                style: FlowPayTypography.amount(color: FlowPayColors.amber).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: FlowPayTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: FlowPayTypography.captionStyle(color: FlowPayColors.darkTextSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onDismiss != null)
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
              const SizedBox(width: 8),
              FlowPayButton(
                text: 'Review & Sign',
                icon: Icons.key_rounded,
                size: FlowPayButtonSize.small,
                onPressed: onReview,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// FlowPay Multi-Currency Wallet Card
/// Provider-independent display of a smart wallet balance with Available vs Reserved indicators.
class FlowPayWalletCard extends StatelessWidget {
  final String walletName;
  final Currency currency;
  final Money balance;
  final Money availableBalance;
  final Money? reservedBalance;
  final String? accountOrAddress;
  final String status;
  final VoidCallback? onSend;
  final VoidCallback? onReceive;
  final VoidCallback? onConvert;
  final VoidCallback? onReserve;
  final VoidCallback? onTap;

  const FlowPayWalletCard({
    super.key,
    required this.walletName,
    required this.currency,
    required this.balance,
    required this.availableBalance,
    this.reservedBalance,
    this.accountOrAddress,
    this.status = 'ACTIVE',
    this.onSend,
    this.onReceive,
    this.onConvert,
    this.onReserve,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
                    color: Color(0x0A0F1712),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Currency Flag, Code, Rail token, Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? FlowPayColors.darkSurfaceElevated
                            : FlowPayColors.mint100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? FlowPayColors.darkBorder
                              : FlowPayColors.emerald400.withAlpha(50),
                        ),
                      ),
                      child: Text(
                        currency.flagEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              currency.code,
                              style: FlowPayTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? Colors.white
                                    : FlowPayColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? FlowPayColors.emerald600.withAlpha(30)
                                    : FlowPayColors.mint100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${currency.stablecoinToken} Rail',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? FlowPayColors.emerald400
                                      : FlowPayColors.emerald700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          walletName,
                          style: FlowPayTypography.captionStyle(
                            color: isDark
                                ? FlowPayColors.darkTextSecondary
                                : FlowPayColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                FlowPayStatus(
                  label: status,
                  color: status.toUpperCase() == 'ACTIVE'
                      ? FlowPayColors.emerald600
                      : FlowPayColors.amber,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Balance Display
            Text(
              'TOTAL BALANCE',
              style: TextStyle(
                color: isDark
                    ? FlowPayColors.darkTextSecondary
                    : FlowPayColors.lightTextSecondary,
                letterSpacing: 0.8,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            FlowPayAmount(
              amount: balance,
              fontSize: 26,
            ),
            const SizedBox(height: 12),

            // Available vs Reserved split
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: FlowPayColors.emerald600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Available: ${availableBalance.formattedWithSymbol}',
                        style: FlowPayTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reservedBalance != null && reservedBalance!.isPositive)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: FlowPayColors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Reserved: ${reservedBalance!.formattedWithSymbol}',
                        style: FlowPayTypography.caption.copyWith(
                          color: FlowPayColors.amber,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            if (accountOrAddress != null && accountOrAddress!.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: accountOrAddress!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account address copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkSurfaceElevated
                        : FlowPayColors.mint100.withAlpha(120),
                    borderRadius: FlowPayRadii.chip,
                    border: Border.all(
                      color: isDark
                          ? FlowPayColors.darkBorder
                          : FlowPayColors.emerald400.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 11,
                        color: isDark
                            ? FlowPayColors.darkTextSecondary
                            : FlowPayColors.emerald700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        accountOrAddress!.length > 18
                            ? '${accountOrAddress!.substring(0, 8)}...${accountOrAddress!.substring(accountOrAddress!.length - 6)}'
                            : accountOrAddress!,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.emerald700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Action row with Dribbble tactile pill buttons
            const SizedBox(height: 14),
            Row(
              children: [
                if (onSend != null)
                  Expanded(
                    child: InkWell(
                      onTap: onSend,
                      borderRadius: FlowPayRadii.button,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? FlowPayColors.darkSurfaceElevated
                              : FlowPayColors.lightSurfaceElevated,
                          borderRadius: FlowPayRadii.button,
                          border: Border.all(
                            color: isDark
                                ? FlowPayColors.darkBorder
                                : FlowPayColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_outward_rounded,
                              size: 13,
                              color: isDark
                                  ? Colors.white
                                  : FlowPayColors.lightTextPrimary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Send',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : FlowPayColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (onReceive != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: onReceive,
                      borderRadius: FlowPayRadii.button,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? FlowPayColors.emerald600.withAlpha(40)
                              : FlowPayColors.mint100,
                          borderRadius: FlowPayRadii.button,
                          border: Border.all(
                            color: isDark
                                ? FlowPayColors.emerald400.withAlpha(90)
                                : FlowPayColors.emerald600.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.south_west_rounded,
                              size: 13,
                              color: isDark
                                  ? FlowPayColors.emerald400
                                  : FlowPayColors.emerald700,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Receive',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? FlowPayColors.emerald400
                                    : FlowPayColors.emerald700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (onConvert != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: onConvert,
                      borderRadius: FlowPayRadii.button,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? FlowPayColors.darkSurfaceElevated
                              : FlowPayColors.lightSurfaceElevated,
                          borderRadius: FlowPayRadii.button,
                          border: Border.all(
                            color: isDark
                                ? FlowPayColors.darkBorder
                                : FlowPayColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sync_alt_rounded,
                              size: 13,
                              color: isDark
                                  ? FlowPayColors.emerald400
                                  : FlowPayColors.emerald600,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Convert',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : FlowPayColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
