import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/models/shared_transaction.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import 'components/transaction_detail_sheet.dart';

/// Corporate Audit Log Screen
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// - Theme-adaptive Paper / Obsidian canvas
/// - Cryptographic ledger telemetry pill bar (Audited Events, Active Rails, Consensus Anchor)
/// - Pillowed search bar & interactive category filter chips
/// - Elevated 24dp audit event cards with squircle category icons & copyable reference hashes
/// - Tap opens TransactionDetailSheet with full sanitized audit data
class BusinessActivityScreen extends StatefulWidget {
  final AppState appState;

  const BusinessActivityScreen({super.key, required this.appState});

  @override
  State<BusinessActivityScreen> createState() => _BusinessActivityScreenState();
}

class _BusinessActivityScreenState extends State<BusinessActivityScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _businessActivities = [
    {
      'id': 'aud_001',
      'title': 'Global Payroll Fan-Out',
      'desc': 'Disbursed \$4,000 USD to 2 employees in Nigeria & Mexico',
      'time': 'Today, 10:45 AM',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('4000.00', Currency.usd),
      'country': 'NG',
      'ref': 'ref_bmoni_payroll_0x8fa1c2',
      'rail': 'CNGN / MEXe Multi-Rail',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_002',
      'title': 'Employee Onboarding Verified',
      'desc': 'Samson Jabo completed KYC via Mexico SPEI rail',
      'time': 'Yesterday',
      'category': 'Onboarding',
      'status': FlowPayAppStatus.success,
      'amount': Money.fromMajorString('0.00', Currency.mxn),
      'country': 'MX',
      'ref': 'ref_bmoni_kyc_0x4b7e91',
      'rail': 'MEXe Rail',
      'icon': Icons.how_to_reg_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_003',
      'title': 'Virtual Card Issued',
      'desc': 'Issued virtual NGN spend card for Bunch Dillon',
      'time': '3 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('0.00', Currency.ngn),
      'country': 'NG',
      'ref': 'ref_bmoni_card_0x91d3f0',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_004',
      'title': 'Compliance Tax Filing',
      'desc': 'Submitted aggregate FX compliance ledger',
      'time': '1 week ago',
      'category': 'Compliance',
      'status': FlowPayAppStatus.pending,
      'amount': Money.fromMajorString('0.00', Currency.usd),
      'country': 'US',
      'ref': 'ref_bmoni_tax_0x33e8b2',
      'rail': 'ERC-4337 Consensus',
      'icon': Icons.verified_user_rounded,
      'iconColor': FlowPayColors.info,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredActivities {
    return _businessActivities.where((item) {
      final title = (item['title'] as String).toLowerCase();
      final desc = (item['desc'] as String).toLowerCase();
      final ref = (item['ref'] as String).toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          title.contains(q) ||
          desc.contains(q) ||
          ref.contains(q);

      if (!matchesQuery) return false;

      if (_selectedCategory == 'All') return true;
      return (item['category'] as String) == _selectedCategory;
    }).toList();
  }

  void _openDetailSheet(Map<String, dynamic> item) {
    final sharedTx = SharedTransactionModel(
      id: item['id'] as String,
      title: item['title'] as String,
      amount: item['amount'] as Money,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      status: item['status'] == FlowPayAppStatus.completed ||
              item['status'] == FlowPayAppStatus.success
          ? TransactionStatus.completed
          : TransactionStatus.processing,
      type: item['category'] == 'Cards'
          ? TransactionType.cardTransaction
          : (item['category'] == 'Payroll'
              ? TransactionType.payrollRun
              : TransactionType.walletOperation),
      country: item['country'] as String?,
      flowpayReference: item['ref'] as String?,
      bmoniReference: '0x${(item['ref'] as String).hashCode.toRadixString(16).padLeft(64, '0')}',
      description: item['desc'] as String,
    );

    TransactionDetailSheet.show(context, sharedTx);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? FlowPayColors.darkBackground : FlowPayColors.paper;
    final surfaceColor = FlowPayColors.surfaceOf(context);
    final borderColor = FlowPayColors.borderOf(context);
    final textPrimaryColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;
    final canPop = Navigator.canPop(context);

    final filtered = _filteredActivities;

    final content = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Corporate Audit Telemetry Header Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: FlowPayRadii.cardSmall,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              _AuditHeaderStatPill(
                label: 'AUDITED EVENTS',
                value: '${_businessActivities.length} Events',
                icon: Icons.history_edu_rounded,
                iconColor: FlowPayColors.primary,
                isDark: isDark,
              ),
              Container(
                height: 32,
                width: 1,
                color: borderColor,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _AuditHeaderStatPill(
                label: 'ACTIVE RAILS',
                value: '2 (NGN, MEXe)',
                icon: Icons.public_rounded,
                iconColor: FlowPayColors.accent,
                isDark: isDark,
              ),
              Container(
                height: 32,
                width: 1,
                color: borderColor,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _AuditHeaderStatPill(
                label: 'CONSENSUS',
                value: 'Immutable',
                icon: Icons.lock_outline_rounded,
                iconColor: FlowPayColors.info,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Pillowed Search Bar
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: FlowPayRadii.input,
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: FlowPayTypography.body(color: textPrimaryColor),
            decoration: InputDecoration(
              hintText: 'Search audit records, references...',
              hintStyle: FlowPayTypography.body(
                  color: textSecondaryColor.withValues(alpha: 0.6)),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: textSecondaryColor,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          size: 18, color: textSecondaryColor),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _AuditFilterChip(
                label: 'All (${_businessActivities.length})',
                isSelected: _selectedCategory == 'All',
                onTap: () => setState(() => _selectedCategory = 'All'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Payroll',
                isSelected: _selectedCategory == 'Payroll',
                onTap: () => setState(() => _selectedCategory = 'Payroll'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Onboarding',
                isSelected: _selectedCategory == 'Onboarding',
                onTap: () => setState(() => _selectedCategory = 'Onboarding'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Cards',
                isSelected: _selectedCategory == 'Cards',
                onTap: () => setState(() => _selectedCategory = 'Cards'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Compliance',
                isSelected: _selectedCategory == 'Compliance',
                onTap: () => setState(() => _selectedCategory = 'Compliance'),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Audit Event List
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.find_in_page_outlined,
                    size: 40,
                    color: textSecondaryColor.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'No matching audit records found',
                  style: FlowPayTypography.body(color: textSecondaryColor),
                ),
              ],
            ),
          )
        else
          ...filtered.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: FlowPayRadii.card,
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openDetailSheet(item),
                    borderRadius: FlowPayRadii.card,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Squircle Category Icon Container
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (item['iconColor'] as Color)
                                      .withValues(alpha: isDark ? 0.18 : 0.12),
                                  borderRadius: FlowPayRadii.avatar,
                                  border: Border.all(
                                    color: (item['iconColor'] as Color)
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: item['iconColor'] as Color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] as String,
                                      style: FlowPayTypography.body(
                                              color: textPrimaryColor)
                                          .copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['desc'] as String,
                                      style: FlowPayTypography.captionStyle(
                                          color: textSecondaryColor),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FlowPayStatusBadge(
                                    appStatus:
                                        item['status'] as FlowPayAppStatus,
                                    showDot: true,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['time'] as String,
                                    style: FlowPayTypography.captionStyle(
                                      color: textSecondaryColor,
                                    ).copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 10),

                          // Reference Hash Pill Row with Copy
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? FlowPayColors.darkSurfaceElevated
                                          .withValues(alpha: 0.5)
                                      : FlowPayColors.mint100
                                          .withValues(alpha: 0.4),
                                  borderRadius: FlowPayRadii.chip,
                                  border: Border.all(
                                    color: borderColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fingerprint_rounded,
                                        size: 12,
                                        color: FlowPayColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      item['ref'] as String,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item['rail'] as String,
                                style: FlowPayTypography.captionStyle(
                                        color: textSecondaryColor)
                                    .copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 10, color: FlowPayColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (canPop) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Corporate Audit Log',
            style: FlowPayTypography.title(color: textPrimaryColor).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        body: content,
      );
    }

    return Container(
      color: backgroundColor,
      child: content,
    );
  }
}

class _AuditHeaderStatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _AuditHeaderStatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondary =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: FlowPayTypography.captionStyle(color: textSecondary).copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: FlowPayTypography.body(color: textPrimary).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AuditFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _AuditFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg =
        isDark ? FlowPayColors.primary.withValues(alpha: 0.22) : FlowPayColors.mint100;
    final unselectedBg = FlowPayColors.surfaceOf(context);
    const selectedBorder = FlowPayColors.primary;
    final unselectedBorder = FlowPayColors.borderOf(context);
    final selectedText =
        isDark ? FlowPayColors.accent : FlowPayColors.primary;
    final unselectedText =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: FlowPayRadii.chip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: FlowPayRadii.chip,
            border: Border.all(
              color: isSelected ? selectedBorder : unselectedBorder,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? selectedText : unselectedText,
            ),
          ),
        ),
      ),
    );
  }
}
