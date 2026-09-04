import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/repositories/activity_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';
import 'components/activity_detail_modal.dart';

enum ActivityFilter {
  all,
  transfers,
  conversions,
  missions,
  walletOps,
  cards,
  pendingApprovals,
  failures,
}

extension ActivityFilterX on ActivityFilter {
  String get label {
    switch (this) {
      case ActivityFilter.all:
        return 'All';
      case ActivityFilter.transfers:
        return 'Transfers';
      case ActivityFilter.conversions:
        return 'Conversions';
      case ActivityFilter.missions:
        return 'Missions';
      case ActivityFilter.walletOps:
        return 'Wallet Ops';
      case ActivityFilter.cards:
        return 'Cards';
      case ActivityFilter.pendingApprovals:
        return 'Pending Approvals';
      case ActivityFilter.failures:
        return 'Failures';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityFilter.all:
        return Icons.grid_view;
      case ActivityFilter.transfers:
        return Icons.arrow_outward;
      case ActivityFilter.conversions:
        return Icons.currency_exchange;
      case ActivityFilter.missions:
        return Icons.bolt;
      case ActivityFilter.walletOps:
        return Icons.account_balance_wallet_outlined;
      case ActivityFilter.cards:
        return Icons.credit_card;
      case ActivityFilter.pendingApprovals:
        return Icons.pending_actions;
      case ActivityFilter.failures:
        return Icons.error_outline;
    }
  }
}

class PersonalActivityScreen extends StatefulWidget {
  final AppState appState;

  const PersonalActivityScreen({super.key, required this.appState});

  @override
  State<PersonalActivityScreen> createState() => _PersonalActivityScreenState();
}

class _PersonalActivityScreenState extends State<PersonalActivityScreen> {
  List<ActivityModel> _activities = [];
  bool _isLoading = true;
  ActivityFilter _selectedFilter = ActivityFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppStateChanged);
    _loadActivities();
  }

  void _onAppStateChanged() {
    if (mounted) {
      _loadActivities();
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    final acts = await widget.appState.activityRepo.getRecentActivities(limit: 50);
    if (mounted) {
      setState(() {
        _activities = acts;
        _isLoading = false;
      });
    }
  }

  void _onActivityApproved(ActivityModel updated) {
    widget.appState.activityRepo.recordActivity(updated);
    setState(() {
      final idx = _activities.indexWhere((a) => a.id == updated.id);
      if (idx != -1) {
        _activities[idx] = updated;
      }
    });
  }

  List<ActivityModel> get _filteredActivities {
    return _activities.where((a) {
      // 1. Category / Filter match
      bool matchesFilter = true;
      switch (_selectedFilter) {
        case ActivityFilter.all:
          matchesFilter = true;
          break;
        case ActivityFilter.transfers:
          matchesFilter = a.type == ActivityType.transfer;
          break;
        case ActivityFilter.conversions:
          matchesFilter = a.type == ActivityType.conversion;
          break;
        case ActivityFilter.missions:
          matchesFilter = a.type == ActivityType.mission;
          break;
        case ActivityFilter.walletOps:
          matchesFilter = a.type == ActivityType.wallet;
          break;
        case ActivityFilter.cards:
          matchesFilter = a.type == ActivityType.card;
          break;
        case ActivityFilter.pendingApprovals:
          matchesFilter = a.status == FlowPayAppStatus.awaitingApproval ||
              a.status == FlowPayAppStatus.pending;
          break;
        case ActivityFilter.failures:
          matchesFilter = a.status == FlowPayAppStatus.failed;
          break;
      }

      if (!matchesFilter) return false;

      // 2. Search query match
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesRecipient = a.counterparty.toLowerCase().contains(q);
        final matchesTitle = a.title.toLowerCase().contains(q);
        final matchesRef = a.reference.toLowerCase().contains(q);
        final matchesCurrency = a.currency.code.toLowerCase().contains(q);
        return matchesRecipient || matchesTitle || matchesRef || matchesCurrency;
      }

      return true;
    }).toList();
  }

  int get _awaitingCount => _activities
      .where((a) => a.status == FlowPayAppStatus.awaitingApproval)
      .length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);
    final filtered = _filteredActivities;

    Widget body = _isLoading
        ? const FlowPayLoadingState(message: 'Loading financial audit trail...')
        : RefreshIndicator(
            onRefresh: _loadActivities,
            child: ListView(
              padding: FlowPaySpacing.insetXl,
              children: [
                // Top Search & Filter Card
                _buildSearchAndFilters(isDark),

                const SizedBox(height: FlowPaySpacing.lg),

                // Metrics / Status Summary Bar
                _buildSummaryBar(isDark),

                const SizedBox(height: FlowPaySpacing.md),

                // Transaction Items List
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: FlowPayEmptyState(
                      icon: Icons.history_toggle_off,
                      title: 'No Transactions Found',
                      description: _searchQuery.isNotEmpty
                          ? 'No activity matches "$_searchQuery" in ${_selectedFilter.label}.'
                          : 'No activity found under ${_selectedFilter.label}.',
                      actionText: _selectedFilter != ActivityFilter.all || _searchQuery.isNotEmpty
                          ? 'Reset Filters'
                          : null,
                      onAction: () {
                        setState(() {
                          _selectedFilter = ActivityFilter.all;
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    ),
                  )
                else
                  ...filtered.map((activity) => _buildActivityCard(context, activity, isDark)),
              ],
            ),
          );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Personal Activity'),
          scrolledUnderElevation: 0,
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated,
            borderRadius: FlowPaySpacing.borderRadiusMd,
            border: Border.all(
              color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: FlowPayTypography.bodyMd.copyWith(
                    color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by recipient, merchant, or reference...',
                    hintStyle: FlowPayTypography.bodySm.copyWith(
                      color: isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: FlowPaySpacing.md),

        // Horizontal Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ActivityFilter.values.map((filter) {
              final isSelected = _selectedFilter == filter;
              int? count;
              if (filter == ActivityFilter.pendingApprovals && _awaitingCount > 0) {
                count = _awaitingCount;
              }

              return Padding(
                padding: const EdgeInsets.only(right: FlowPaySpacing.sm),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter.icon,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary),
                      ),
                      const SizedBox(width: 6),
                      Text(filter.label),
                      if (count != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: FlowPayColors.warning,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: FlowPayColors.primary,
                  backgroundColor: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? FlowPayColors.primary
                        : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFilter = filter);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_filteredActivities.length} Activity Items',
          style: FlowPayTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary,
          ),
        ),
        if (_awaitingCount > 0 && _selectedFilter != ActivityFilter.pendingApprovals)
          InkWell(
            onTap: () => setState(() => _selectedFilter = ActivityFilter.pendingApprovals),
            borderRadius: FlowPaySpacing.borderRadiusSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: FlowPayColors.warning.withAlpha(30),
                borderRadius: FlowPaySpacing.borderRadiusSm,
                border: Border.all(color: FlowPayColors.warning.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: FlowPayColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    '$_awaitingCount Awaiting Approval',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: FlowPayColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityCard(BuildContext context, ActivityModel a, bool isDark) {
    final isAwaiting = a.status == FlowPayAppStatus.awaitingApproval;

    return Padding(
      padding: const EdgeInsets.only(bottom: FlowPaySpacing.sm),
      child: FlowPayCard(
        onTap: () {
          ActivityDetailModal.show(
            context,
            activity: a,
            onApprove: _onActivityApproved,
          );
        },
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category / Type Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkSurfaceElevated
                        : FlowPayColors.lightSurfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.type.icon, color: FlowPayColors.primaryLight, size: 20),
                ),
                const SizedBox(width: FlowPaySpacing.md),

                // Title and Recipient/Merchant
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: FlowPayTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? FlowPayColors.darkTextPrimary
                              : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.counterparty,
                        style: FlowPayTypography.bodySm.copyWith(
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ref: ${a.reference}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: isDark
                              ? FlowPayColors.darkTextTertiary
                              : FlowPayColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: FlowPaySpacing.sm),

                // Amount & Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (a.amount != null)
                      Text(
                        a.amount!.formatFormatted(),
                        style: FlowPayTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.bold,
                          color: a.status == FlowPayAppStatus.failed
                              ? FlowPayColors.error
                              : (isDark
                                  ? FlowPayColors.darkTextPrimary
                                  : FlowPayColors.lightTextPrimary),
                        ),
                      )
                    else
                      Text(
                        'Free',
                        style: FlowPayTypography.bodySm.copyWith(
                          color: FlowPayColors.accentLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    FlowPayStatusBadge(
                      appStatus: a.status,
                      showDot: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.timeAgo,
                      style: FlowPayTypography.caption.copyWith(
                        color: isDark
                            ? FlowPayColors.darkTextTertiary
                            : FlowPayColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Inline 1-tap Approve button for items awaiting approval
            if (isAwaiting) ...[
              const SizedBox(height: FlowPaySpacing.md),
              const Divider(height: 1),
              const SizedBox(height: FlowPaySpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Requires 6-Digit B-Key PIN',
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  FlowPayButton(
                    text: 'Approve (PIN)',
                    icon: Icons.pin,
                    size: FlowPayButtonSize.small,
                    onPressed: () {
                      WalletPinAuthSheet.show(
                        context: context,
                        title: 'Approve ${a.type.label}',
                        subtitle: 'Sign canonical BMONI proposal for ${a.amount?.formatFormatted() ?? a.reference}',
                        onAuthorize: (pin) async {
                          final updated = a.copyWith(status: FlowPayAppStatus.completed);
                          _onActivityApproved(updated);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Action approved and signed via B-Key: ${a.reference}'),
                              backgroundColor: FlowPayColors.accent,
                            ),
                          );
                          return '0x_signed_bmoni_proposal';
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
