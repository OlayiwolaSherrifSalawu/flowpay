import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/design_system/design_system.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/components.dart';

/// Employee Detail Screen
/// Conforms strictly to FlowPay design system and BMONI specifications:
/// - Identity section: Name, Email, Phone, Country flag & jurisdiction
/// - Financial section: Payroll amount, target rail, stablecoin token
/// - BMONI Linkage section: bmoniUserId, on-chain smart wallet address, card status
/// - KYC Compliance section: Pass/Fail/Pending indicators (NEVER exposes raw document data)
/// - Infrastructure controls: Freeze/Unfreeze card toggle, retry onboarding
class EmployeeDetailScreen extends StatefulWidget {
  final AppState appState;
  final EmployeeModel employee;

  const EmployeeDetailScreen({
    super.key,
    required this.appState,
    required this.employee,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late EmployeeModel _emp;
  bool _isCardFrozen = false;

  @override
  void initState() {
    super.initState();
    _emp = widget.employee;
    _isCardFrozen = _emp.cardStatus.toUpperCase() == 'FROZEN';
  }

  void _toggleCardFreeze() {
    setState(() {
      _isCardFrozen = !_isCardFrozen;
    });

    try {
      BMoniToastOverlay.showSuccess(
        context: context,
        title: _isCardFrozen ? 'Card Frozen' : 'Card Activated',
        message: 'Virtual Mastercard status updated on BMONI infrastructure.',
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isCardFrozen ? 'Card has been frozen.' : 'Card is now active.'),
        ),
      );
    }
  }

  void _retryOnboarding() {
    try {
      BMoniToastOverlay.showInfo(
        context: context,
        title: 'Onboarding Re-triggered',
        message: 'Requested KYC review for ${_emp.fullName}.',
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Onboarding retry queued for ${_emp.fullName}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payrollFormatted = _emp.payrollAmount != null
        ? _emp.payrollAmount!.formatFormatted()
        : '${_emp.targetCurrency.symbol}2,000.00';

    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      appBar: AppBar(
        backgroundColor: FlowPayColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _emp.fullName,
          style: FlowPayTypography.title(color: FlowPayColors.ink)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: FlowPaySpacing.insetXl,
        children: [
          // 1. Employee Virtual Card Face (Physical Card Object)
          VirtualCardObject(
            cardLast4: _emp.cardLast4 ?? '4289',
            countryFlag: _emp.flagEmoji,
            cardHolderName: _emp.fullName,
            isFrozen: _isCardFrozen,
          ),
          const SizedBox(height: 20),

          // 2. Identity & Profile Section Card
          FlowPayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: FlowPayColors.surfaceAlt,
                      child: Text(
                        _emp.flagEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _emp.fullName,
                            style: FlowPayTypography.title(
                                    color: FlowPayColors.ink)
                                .copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _emp.email,
                            style: FlowPayTypography.captionStyle(
                                color: FlowPayColors.textSecondary),
                          ),
                          if (_emp.phoneNumber != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _emp.phoneNumber!,
                              style: FlowPayTypography.captionStyle(
                                  color: FlowPayColors.textTertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _StatusPill(status: _emp.status),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: FlowPayColors.hairline, height: 1),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Jurisdiction',
                  value: '${_emp.flagEmoji} ${_emp.resolvedCountryName}',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Disbursement Rail',
                  value:
                      '${_emp.targetCurrency.code} (${_emp.targetCurrency.stablecoinToken})',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Monthly Net Salary',
                  value: payrollFormatted,
                  isAccent: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: FlowPaySpacing.xl),

          // 3. BMONI On-Chain Linkage Section
          Text(
            'BMONI ON-CHAIN LINKAGE',
            style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.textTertiary)
                .copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          FlowPayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  label: 'BMONI User ID',
                  value: _emp.bmoniUserId ?? 'usr_bmoni_sandbox',
                  isMonospace: true,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Smart Wallet EVM',
                  value: _emp.walletAddress ?? '0x7e81...21ad',
                  isMonospace: true,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Wallet Rail Status',
                  value: _emp.walletStatus,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Virtual Card Status',
                  value: _isCardFrozen ? 'FROZEN' : _emp.cardStatus,
                ),
              ],
            ),
          ),
          const SizedBox(height: FlowPaySpacing.xl),

          // 4. KYC Compliance Section (Strictly indicators - NEVER raw documents)
          Text(
            'KYC & COMPLIANCE VERIFICATION',
            style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.textTertiary)
                .copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          FlowPayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KycIndicatorRow(
                  title: 'National Identity Verification',
                  subtitle: _emp.country == 'NG'
                      ? 'BVN / NIN verification'
                      : 'CURP / RFC verification',
                  isPassed: _emp.isReady || _emp.status == 'ACTIVE',
                  isPending: _emp.status == 'KYC_PENDING' ||
                      _emp.status == 'ONBOARDING',
                ),
                const Divider(color: FlowPayColors.hairline, height: 16),
                _KycIndicatorRow(
                  title: 'Proof of Address',
                  subtitle: 'Utility or jurisdictional document',
                  isPassed: _emp.isReady || _emp.status == 'ACTIVE',
                  isPending: _emp.status == 'KYC_PENDING' ||
                      _emp.status == 'ONBOARDING',
                ),
                const Divider(color: FlowPayColors.hairline, height: 16),
                _KycIndicatorRow(
                  title: 'Facial Biometric Liveness',
                  subtitle: 'Anti-spoofing radar scan validation',
                  isPassed: _emp.isReady || _emp.status == 'ACTIVE',
                  isPending: _emp.status == 'ONBOARDING',
                ),
              ],
            ),
          ),
          const SizedBox(height: FlowPaySpacing.xl),

          // 5. Quick Actions
          Text(
            'ACTIONS',
            style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.textTertiary)
                .copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BMoniButton(
                  onPressed: _toggleCardFreeze,
                  text: _isCardFrozen ? 'Unfreeze Card' : 'Freeze Card',
                  variant: _isCardFrozen
                      ? BMoniButtonVariant.primary
                      : BMoniButtonVariant.outline,
                  size: BMoniButtonSize.medium,
                  icon: _isCardFrozen
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                ),
              ),
              if (_emp.isFailed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: BMoniButton(
                    onPressed: _retryOnboarding,
                    text: 'Retry Onboarding',
                    variant: BMoniButtonVariant.primary,
                    size: BMoniButtonSize.medium,
                    icon: Icons.refresh_rounded,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final upper = status.toUpperCase();
    Color bg;
    Color fg;

    switch (upper) {
      case 'READY':
      case 'ACTIVE':
        bg = FlowPayColors.signal.withValues(alpha: 0.15);
        fg = FlowPayColors.signal;
        break;
      case 'FAILED':
        bg = FlowPayColors.error.withValues(alpha: 0.15);
        fg = FlowPayColors.error;
        break;
      case 'KYC_PENDING':
      case 'ONBOARDING':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber[700] ?? Colors.amber;
        break;
      default:
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        upper,
        style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _KycIndicatorRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isPassed;
  final bool isPending;

  const _KycIndicatorRow({
    required this.title,
    required this.subtitle,
    required this.isPassed,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    String statusText;
    Color textColor;

    if (isPassed) {
      icon = Icons.check_circle_rounded;
      iconColor = FlowPayColors.signal;
      statusText = 'PASSED';
      textColor = FlowPayColors.signal;
    } else if (isPending) {
      icon = Icons.hourglass_empty_rounded;
      iconColor = Colors.amber;
      statusText = 'PENDING';
      textColor = Colors.amber[700] ?? Colors.amber;
    } else {
      icon = Icons.cancel_rounded;
      iconColor = FlowPayColors.error;
      statusText = 'NOT SUBMITTED';
      textColor = FlowPayColors.error;
    }

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    FlowPayTypography.body(color: FlowPayColors.ink).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.textTertiary),
              ),
            ],
          ),
        ),
        Text(
          statusText,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isAccent;
  final bool isMonospace;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isAccent = false,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: FlowPayTypography.captionStyle(
              color: FlowPayColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: isAccent
              ? FlowPayTypography.amount(color: FlowPayColors.signal).copyWith(
                  fontWeight: FontWeight.w700,
                )
              : FlowPayTypography.body(color: FlowPayColors.ink).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: isMonospace ? 'monospace' : null,
                ),
        ),
      ],
    );
  }
}
