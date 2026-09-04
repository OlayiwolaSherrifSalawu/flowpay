import 'package:flutter/material.dart';
import '../../core/design_system/amount_display.dart';
import '../../core/design_system/spacing.dart';
import '../../core/models/shared_transaction.dart';
import '../../core/repositories/business_audit_repository.dart';
import '../../core/repositories/payroll_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/state/business_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';
import 'components/payroll_run_detail_sheet.dart';
import 'components/transaction_detail_sheet.dart';

/// FlowPay Business — Payroll Activity & Corporate Audit Screen
/// Conforms strictly to requirements:
/// - Aggregation layer over data from Prompts 10-13 without calling BMONI for new endpoints.
/// - Shows: Payroll Runs, Employee Payments, Card Transactions, Wallet Operations, Failures.
/// - Reuses bkey_uikit's ActivitySectionCard and StatusText components everywhere for consistent status-chip rendering.
/// - Surfaces Payroll Run records with: Payroll ID, Date, Employee count, Countries, USD equivalent, Fees, Status.
/// - Supports all statuses: Draft, Pending Approval, Processing, Completed, Partially Completed, Failed.
/// - Strictly sanitizes and isolates signing secrets (never surfaces hashToSign, signature, or private keys).
class BusinessActivityScreen extends StatefulWidget {
  final AppState appState;

  const BusinessActivityScreen({super.key, required this.appState});

  @override
  State<BusinessActivityScreen> createState() => _BusinessActivityScreenState();
}

class _BusinessActivityScreenState extends State<BusinessActivityScreen> {
  AuditFilterCategory _activeFilter = AuditFilterCategory.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  BusinessProvider get _businessProvider => widget.appState.businessProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _businessProvider.loadAuditActivities();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    Widget content = AnimatedBuilder(
      animation: _businessProvider,
      builder: (context, _) {
        final isLoading = _businessProvider.isAuditLoading && _businessProvider.auditActivities.isEmpty;
        final rawActivities = _businessProvider.auditActivities;
        final payrollRuns = _businessProvider.payrollRuns;
        final failuresCount = _businessProvider.failureCount;

        // Apply local search query if present
        List<SharedTransactionModel> activities = rawActivities;
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          activities = activities.where((a) {
            return a.title.toLowerCase().contains(q) ||
                a.description.toLowerCase().contains(q) ||
                (a.counterparty?.toLowerCase().contains(q) ?? false) ||
                (a.flowpayReference?.toLowerCase().contains(q) ?? false) ||
                (a.bmoniReference?.toLowerCase().contains(q) ?? false) ||
                (a.country?.toLowerCase().contains(q) ?? false);
          }).toList();
        }

        List<PayrollRunModel> filteredRuns = payrollRuns;
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          filteredRuns = filteredRuns.where((r) {
            return r.title.toLowerCase().contains(q) ||
                r.runId.toLowerCase().contains(q) ||
                r.countries.any((c) => c.toLowerCase().contains(q));
          }).toList();
        }

        return RefreshIndicator(
          color: FlowPayColors.brand500,
          backgroundColor: FlowPayColors.darkSurface,
          onRefresh: () => _businessProvider.loadAuditActivities(filter: _activeFilter),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Audit Overview Metrics Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildMetricsHeader(payrollRuns, rawActivities, failuresCount),
                ),
              ),

              // 2. Filter Category Pills
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildFilterTabs(failuresCount),
                ),
              ),

              // 3. Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _buildSearchBar(),
                ),
              ),

              // 4. Loading State
              if (isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: FlowPayColors.brand500),
                  ),
                )
              // 5. Dedicated Payroll Runs View
              else if (_activeFilter == AuditFilterCategory.payrollRuns)
                filteredRuns.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState('No payroll runs found'),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final run = filteredRuns[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildPayrollRunCard(run),
                              );
                            },
                            childCount: filteredRuns.length,
                          ),
                        ),
                      )
              // 6. Generic/Aggregated Transactions & Activities View
              else if (activities.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    _activeFilter == AuditFilterCategory.failures
                        ? 'Zero failures recorded. All corporate rails operating smoothly.'
                        : 'No activity found for this category',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = activities[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTransactionCard(item),
                        );
                      },
                      childCount: activities.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (canPop) {
      return Scaffold(
        backgroundColor: FlowPayColors.canvas,
        appBar: AppBar(
          backgroundColor: FlowPayColors.canvas,
          elevation: 0,
          title: const Text('Corporate Audit & Activity'),
          centerTitle: true,
        ),
        body: content,
      );
    }

    return content;
  }

  /// Top 4-Metric Grid
  Widget _buildMetricsHeader(
    List<PayrollRunModel> runs,
    List<SharedTransactionModel> activities,
    int failuresCount,
  ) {
    int totalMinor = 0;
    for (final run in runs) {
      totalMinor += run.totalUsd.minorUnits;
    }
    final totalDisbursed = '\$${(totalMinor / 100).toStringAsFixed(0)}';
    final completedRuns = runs.where((r) => r.status == 'COMPLETED').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowPayColors.darkSurface,
        borderRadius: FlowPaySpacing.borderRadiusMd,
        border: Border.all(color: FlowPayColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: FlowPayColors.brand400, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'CORPORATE AUDIT LEDGER',
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.brand400,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const PoweredByBmoniBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'TOTAL VOLUME',
                  value: totalDisbursed,
                  color: FlowPayColors.ink,
                ),
              ),
              Container(width: 1, height: 36, color: FlowPayColors.hairline),
              Expanded(
                child: _buildMetricTile(
                  label: 'PAYROLL RUNS',
                  value: '$completedRuns / ${runs.length}',
                  color: FlowPayColors.accent,
                ),
              ),
              Container(width: 1, height: 36, color: FlowPayColors.hairline),
              Expanded(
                child: _buildMetricTile(
                  label: 'SYSTEM FAILURES',
                  value: '$failuresCount',
                  color: failuresCount > 0 ? FlowPayColors.stateError : FlowPayColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: FlowPayTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: FlowPayTypography.caption.copyWith(
            color: FlowPayColors.darkTextSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// Filter Tabs: All, Payroll Runs, Employee Payments, Card Transactions, Wallet Operations, Failures
  Widget _buildFilterTabs(int failuresCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: AuditFilterCategory.values.map((filter) {
          final isSelected = _activeFilter == filter;
          final isFailures = filter == AuditFilterCategory.failures;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(filter.label),
                  if (isFailures && failuresCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: FlowPayColors.stateError,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$failuresCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: FlowPayColors.brand500,
              backgroundColor: FlowPayColors.darkSurface,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isFailures && failuresCount > 0 ? FlowPayColors.stateError : FlowPayColors.darkTextSecondary),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? FlowPayColors.brand500
                      : (isFailures && failuresCount > 0 ? FlowPayColors.stateError.withValues(alpha: 0.5) : FlowPayColors.hairline),
                ),
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _activeFilter = filter);
                  _businessProvider.setAuditFilter(filter);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: FlowPayTypography.bodySmall.copyWith(color: FlowPayColors.ink),
      decoration: InputDecoration(
        hintText: 'Search by employee, country, merchant, or reference...',
        hintStyle: FlowPayTypography.caption.copyWith(color: FlowPayColors.darkTextTertiary),
        prefixIcon: const Icon(Icons.search, color: FlowPayColors.darkTextSecondary, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: FlowPayColors.darkTextSecondary, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: FlowPayColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlowPayColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlowPayColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlowPayColors.brand500),
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim()),
    );
  }

  /// Payroll Run Record Item
  /// Displays: Payroll ID, Date, Employee count, Countries, USD equivalent, Fees, Status.
  /// Reuses ActivitySectionCard container and StatusText component.
  Widget _buildPayrollRunCard(PayrollRunModel run) {
    final flowpayRef = 'FP-PAY-${run.runId.length > 8 ? run.runId.substring(run.runId.length - 8) : run.runId}';

    return ActivitySectionCard(
      onTap: () => PayrollRunDetailSheet.show(
        context,
        run: run,
        businessProvider: _businessProvider,
      ),
      header: SectionHeader(
        title: run.title,
        subtitle: Text(
          'ID: ${run.runId} · ${_formatDate(run.executedAt)}',
          style: FlowPayTypography.caption.copyWith(
            color: FlowPayColors.darkTextSecondary,
          ),
        ),
        trailing: StatusText.fromStatusString(run.status),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: USD Equivalent & Fees
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'USD EQUIVALENT',
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.darkTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    run.totalUsd.formatted,
                    style: FlowPayTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: FlowPayColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fees: ${run.totalFeeUsd.formatted} (Saved ${run.totalSavedFeeUsd.formatted})',
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Right: Employee count & Countries
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RECIPIENTS',
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.darkTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${run.employeeCount} Employees',
                    style: FlowPayTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: FlowPayColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    run.countries.map((c) => c == 'NG' ? '🇳🇬 NG' : (c == 'MX' ? '🇲🇽 MX' : '🇨🇦 $c')).join(' · '),
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Footer bar with FlowPay reference and tap hint
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                flowpayRef,
                style: FlowPayTypography.caption.copyWith(
                  color: FlowPayColors.darkTextTertiary,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
              Row(
                children: [
                  Text(
                    'View Audit Details',
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.brand400,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: FlowPayColors.brand400),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Generic Shared Transaction / Failure Card
  Widget _buildTransactionCard(SharedTransactionModel item) {
    final flag = item.country == 'NG'
        ? '🇳🇬'
        : (item.country == 'MX'
            ? '🇲🇽'
            : (item.country == 'CA' ? '🇨🇦' : '🌐'));

    IconData icon;
    Color iconColor;

    switch (item.type) {
      case TransactionType.payrollRun:
        icon = Icons.payments_outlined;
        iconColor = FlowPayColors.brand400;
        break;
      case TransactionType.employeePayment:
        icon = Icons.person_outline;
        iconColor = FlowPayColors.accent;
        break;
      case TransactionType.cardTransaction:
        icon = Icons.credit_card_outlined;
        iconColor = FlowPayColors.amber;
        break;
      case TransactionType.walletOperation:
        icon = Icons.account_balance_wallet_outlined;
        iconColor = FlowPayColors.info;
        break;
      case TransactionType.failure:
        icon = Icons.warning_amber_rounded;
        iconColor = FlowPayColors.stateError;
        break;
    }

    return ActivitySectionCard(
      onTap: () {
        if (item.type == TransactionType.payrollRun) {
          final runMatch = _businessProvider.payrollRuns.where((r) => r.runId == item.id);
          if (runMatch.isNotEmpty) {
            PayrollRunDetailSheet.show(
              context,
              run: runMatch.first,
              businessProvider: _businessProvider,
            );
            return;
          }
        }
        TransactionDetailSheet.show(context, item);
      },
      header: SectionHeader(
        title: item.title,
        subtitle: Text(
          '${item.counterparty ?? 'FlowPay Business'} · $flag · ${item.timeAgo}',
          style: FlowPayTypography.caption.copyWith(
            color: FlowPayColors.darkTextSecondary,
          ),
        ),
        trailing: StatusText.fromStatusString(item.status.displayName),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: FlowPayTypography.bodySmall.copyWith(
                        color: FlowPayColors.ink,
                      ),
                    ),
                    if (item.flowpayReference != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ref: ${item.flowpayReference}',
                        style: FlowPayTypography.caption.copyWith(
                          color: FlowPayColors.darkTextTertiary,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FlowPayAmountDisplay(
                    amount: item.amount,
                    textStyle: FlowPayTypography.titleMedium.copyWith(
                      color: FlowPayColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.secondaryAmount != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${item.secondaryAmount!.formatted} ${item.secondaryCurrency ?? ''}',
                      style: FlowPayTypography.caption.copyWith(
                        color: FlowPayColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Explicit Failure Notice if item is failed
          if (item.isFailure && item.errorReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FlowPayColors.stateError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FlowPayColors.stateError.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 14, color: FlowPayColors.stateError),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.errorReason!,
                      style: FlowPayTypography.caption.copyWith(
                        color: FlowPayColors.stateError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: FlowPayColors.darkSurface,
                shape: BoxShape.circle,
                border: Border.all(color: FlowPayColors.hairline),
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 36, color: FlowPayColors.darkTextTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Audit Activity',
              style: FlowPayTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: FlowPayColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FlowPayTypography.caption.copyWith(
                color: FlowPayColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
