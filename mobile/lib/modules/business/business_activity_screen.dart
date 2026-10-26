import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/models/paginated_result.dart';
import '../../core/models/shared_transaction.dart';
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
  int _currentPage = 1;
  static const int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.appState.businessProvider.addListener(_onAuditChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.appState.businessProvider.loadAuditActivities();
    });
  }

  /// Real audit trail (payroll runs, employee payments, wallet operations) from
  /// [BusinessProvider] — demo data in demo mode, Stellar-backed records live.
  List<Map<String, dynamic>> get _businessActivities {
    return widget.appState.businessProvider.auditActivities.map((tx) {
      final category = switch (tx.type) {
        TransactionType.payrollRun => 'Payroll',
        TransactionType.employeePayment => 'Payments',
        _ => 'Wallet',
      };
      final status = switch (tx.status) {
        TransactionStatus.completed => FlowPayAppStatus.completed,
        TransactionStatus.failed => FlowPayAppStatus.failed,
        TransactionStatus.pendingApproval => FlowPayAppStatus.awaitingApproval,
        TransactionStatus.draft => FlowPayAppStatus.pending,
        _ => FlowPayAppStatus.processing,
      };
      final hash = tx.networkReference;
      return <String, dynamic>{
        'id': tx.id,
        'tx': tx,
        'title': tx.title,
        'desc': tx.errorReason ?? tx.description,
        'time': tx.timeAgo,
        'category': category,
        'status': status,
        'amount': tx.amount,
        'country': tx.country,
        'ref': tx.flowpayReference ??
            (hash != null && hash.length > 12
                ? '${hash.substring(0, 6)}…${hash.substring(hash.length - 6)}'
                : (hash ?? tx.id)),
        'rail': hash != null ? 'Stellar' : 'FlowPay',
        'icon': switch (tx.type) {
          TransactionType.payrollRun => Icons.payments_rounded,
          TransactionType.employeePayment => Icons.person_rounded,
          _ => Icons.account_balance_wallet_rounded,
        },
        'iconColor': tx.status == TransactionStatus.failed
            ? FlowPayColors.error
            : FlowPayColors.primary,
      };
    }).toList();
  }

  void _onAuditChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.appState.businessProvider.removeListener(_onAuditChanged);
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
      if (_selectedCategory == 'Failed') {
        return item['status'] == FlowPayAppStatus.failed;
      }
      return (item['category'] as String) == _selectedCategory;
    }).toList();
  }

  void _openDetailSheet(Map<String, dynamic> item) {
    final sharedTx = item['tx'] as SharedTransactionModel;
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

    final provider = widget.appState.businessProvider;
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
                label: 'EVENTS',
                value: '${_businessActivities.length} items',
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
                label: 'COUNTRIES',
                value: '${_businessActivities.map((a) => a['country']).whereType<String>().toSet().length}',
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
                label: 'NETWORK',
                value: 'Stellar',
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
            onChanged: (val) => setState(() {
            _searchQuery = val.trim();
            _currentPage = 1;
          }),
            style: FlowPayTypography.body(color: textPrimaryColor),
            decoration: InputDecoration(
              hintText: 'Search activity...',
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
                        setState(() {
                        _searchQuery = '';
                        _currentPage = 1;
                      });
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
                onTap: () => setState(() {
                  _selectedCategory = 'All';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Payroll',
                isSelected: _selectedCategory == 'Payroll',
                onTap: () => setState(() {
                  _selectedCategory = 'Payroll';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Payments',
                isSelected: _selectedCategory == 'Payments',
                onTap: () => setState(() {
                  _selectedCategory = 'Payments';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Wallet',
                isSelected: _selectedCategory == 'Wallet',
                onTap: () => setState(() {
                  _selectedCategory = 'Wallet';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Failed',
                isSelected: _selectedCategory == 'Failed',
                onTap: () => setState(() {
                  _selectedCategory = 'Failed';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Audit Event List
        if (provider.isAuditLoading && provider.auditActivities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (provider.auditErrorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: FlowPayErrorState(
              title: 'Could not load activity',
              message: provider.auditErrorMessage!,
              onRetry: provider.loadAuditActivities,
            ),
          )
        else if (filtered.isEmpty)
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
                  _businessActivities.isEmpty
                      ? 'No business activity yet'
                      : 'No matching activity found',
                  style: FlowPayTypography.body(color: textSecondaryColor),
                ),
              ],
            ),
          )
        else ...[
          ...PaginatedResult.paginateList(
            filtered,
            page: _currentPage,
            limit: _pageSize,
          ).items.map(
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
          if (filtered.length > _pageSize) ...[
            const SizedBox(height: 8),
            FlowPayPaginationBar(
              currentPage: _currentPage,
              totalPages: (filtered.length / _pageSize).ceil(),
              totalItems: filtered.length,
              pageSize: _pageSize,
              itemLabel: 'events',
              onPageChanged: (newPage) {
                setState(() => _currentPage = newPage);
              },
            ),
            const SizedBox(height: 16),
          ],
        ],
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
            'Business Activity',
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
