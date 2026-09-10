import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import 'components/add_employee_modal.dart';
import 'employee_detail_screen.dart';

/// Global Team Screen
/// Conforms to FlowPay Design System & Dribbble Fintech styling:
/// - Theme-adaptive Paper / Obsidian canvas
/// - Live team metrics pill bar (Total Team, Ready, Monthly Payroll)
/// - Pillowed search bar & interactive horizontal filter chips
/// - Full employee rows with: Name, Flag squircle avatar, Payroll Currency & Amount,
///   Onboarding Stage, Wallet & Card badges
/// - FlowPayEmptyState with zero-state illustration and action CTA
/// - Pull-to-refresh & instant detail navigation
class EmployeesScreen extends StatefulWidget {
  final AppState appState;

  const EmployeesScreen({super.key, required this.appState});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<EmployeeModel> _employees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final emps = await widget.appState.employeeRepo.getEmployees();
    if (mounted) {
      setState(() {
        _employees = emps;
        _isLoading = false;
      });
    }
  }

  void _showAddEmployeeDialog() async {
    await AddEmployeeModal.show(context, widget.appState.businessProvider);
    _load();
  }

  List<EmployeeModel> get _filteredEmployees {
    return _employees.where((emp) {
      final matchesSearch = _searchQuery.isEmpty ||
          emp.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.country.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.targetCurrency.code.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      switch (_selectedFilter) {
        case 'Nigeria':
          return emp.country.toUpperCase() == 'NG';
        case 'Mexico':
          return emp.country.toUpperCase() == 'MX';
        case 'Ready':
          return emp.isReady;
        case 'Pending':
          return !emp.isReady && !emp.isFailed;
        case 'Failed':
          return emp.isFailed;
        default:
          return true;
      }
    }).toList();
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

    final readyCount = _employees.where((e) => e.isReady).length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Global Team',
          style: FlowPayTypography.title(color: textPrimaryColor).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FlowPayButton(
              text: '+ Add',
              variant: FlowPayButtonVariant.primary,
              size: FlowPayButtonSize.small,
              onPressed: _showAddEmployeeDialog,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: FlowPayColors.primary),
            )
          : _employees.isEmpty
              ? FlowPayEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No employees yet',
                  description:
                      'Add remote team members across Nigeria and Mexico to run payroll and issue virtual cards.',
                  actionText: 'Add Employee',
                  onAction: _showAddEmployeeDialog,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: FlowPayColors.primary,
                  backgroundColor: surfaceColor,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    children: [
                      // 1. Team Summary Header Pill Bar
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
                            _HeaderStatPill(
                              label: 'TOTAL ROSTER',
                              value: '${_employees.length}',
                              icon: Icons.people_alt_rounded,
                              iconColor: FlowPayColors.primary,
                              isDark: isDark,
                            ),
                            Container(
                              height: 32,
                              width: 1,
                              color: borderColor,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            _HeaderStatPill(
                              label: 'PAYROLL READY',
                              value: '$readyCount / ${_employees.length}',
                              icon: Icons.verified_user_rounded,
                              iconColor: FlowPayColors.accent,
                              isDark: isDark,
                            ),
                            Container(
                              height: 32,
                              width: 1,
                              color: borderColor,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            _HeaderStatPill(
                              label: 'COUNTRIES',
                              value: '2 (Nigeria, Mexico)',
                              icon: Icons.public_rounded,
                              iconColor: FlowPayColors.info,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Pillowed Search Field
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: FlowPayRadii.input,
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val.trim()),
                          style: FlowPayTypography.body(color: textPrimaryColor),
                          decoration: InputDecoration(
                            hintText: 'Search by employee name or country...',
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. Horizontal Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All (${_employees.length})',
                              isSelected: _selectedFilter == 'All',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'All'),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '🇳🇬 Nigeria',
                              isSelected: _selectedFilter == 'Nigeria',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'Nigeria'),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '🇲🇽 Mexico',
                              isSelected: _selectedFilter == 'Mexico',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'Mexico'),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Ready ($readyCount)',
                              isSelected: _selectedFilter == 'Ready',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'Ready'),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Pending (${_employees.length - readyCount})',
                              isSelected: _selectedFilter == 'Pending',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'Pending'),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Employee Rows List
                      if (_filteredEmployees.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.person_search_rounded,
                                  size: 40,
                                  color: textSecondaryColor.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No matching employees found',
                                style: FlowPayTypography.body(
                                    color: textSecondaryColor),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._filteredEmployees.map(
                          (emp) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EmployeeRowCard(
                              employee: emp,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EmployeeDetailScreen(
                                      appState: widget.appState,
                                      employee: emp,
                                    ),
                                  ),
                                ).then((_) => _load());
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _HeaderStatPill({
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({
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

class _EmployeeRowCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback onTap;

  const _EmployeeRowCard({
    required this.employee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = FlowPayColors.surfaceOf(context);
    final borderColor = FlowPayColors.borderOf(context);
    final textPrimaryColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    final formattedPayroll = employee.payrollAmount != null
        ? employee.payrollAmount!.formatFormatted()
        : '${employee.targetCurrency.symbol}2,000.00';

    return Container(
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
          onTap: onTap,
          borderRadius: FlowPayRadii.card,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Squircle Flag Avatar, Name, Email, Status Badge
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? FlowPayColors.darkSurfaceElevated
                            : FlowPayColors.mintSurface.withValues(alpha: 0.5),
                        borderRadius: FlowPayRadii.avatar,
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        employee.flagEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.fullName,
                            style: FlowPayTypography.body(color: textPrimaryColor)
                                .copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            employee.email,
                            style: FlowPayTypography.captionStyle(
                                color: textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                    // Onboarding Lifecycle Stage Badge
                    FlowPayBadge(
                      label: employee.simpleStatusLabel,
                      color: employee.isFailed
                          ? FlowPayColors.error
                          : employee.isReady
                              ? FlowPayColors.accent
                              : FlowPayColors.warning,
                      icon: employee.isFailed
                          ? Icons.error_outline_rounded
                          : employee.isReady
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Wallet ID row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkSurfaceElevated.withValues(alpha: 0.6)
                        : FlowPayColors.paper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 13, color: FlowPayColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          employee.displayWalletId != null
                              ? 'Wallet ${employee.displayWalletId}'
                              : 'Wallet not yet generated — awaiting employee onboarding',
                          style: FlowPayTypography.captionStyle(
                                  color: employee.displayWalletId != null
                                      ? textPrimaryColor
                                      : textSecondaryColor)
                              .copyWith(
                            fontFamily: employee.displayWalletId != null
                                ? 'monospace'
                                : null,
                            fontSize: 11,
                            fontWeight: employee.displayWalletId != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 12),

                // Row 2: Payroll Amount & Status Badges (Wallet & Card)
                Row(
                  children: [
                    // Payroll Currency & Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAYROLL (${employee.targetCurrency.code})',
                          style: FlowPayTypography.captionStyle(
                                  color: textSecondaryColor)
                              .copyWith(
                            fontSize: 10,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedPayroll,
                          style: FlowPayTypography.body(color: textPrimaryColor)
                              .copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Wallet Status Badge
                    _MiniBadge(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Wallet: ${employee.walletStatus}',
                      isActive:
                          employee.walletStatus.toUpperCase() == 'ACTIVE' ||
                              employee.walletStatus.toUpperCase() ==
                                  'PROVISIONED',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),

                    // Card Status Badge
                    _MiniBadge(
                      icon: Icons.credit_card_rounded,
                      label: 'Card: ${employee.cardStatus}',
                      isActive:
                          employee.cardStatus.toUpperCase() == 'ACTIVE' ||
                              employee.cardStatus.toUpperCase() == 'ISSUED',
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDark;

  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark
        ? FlowPayColors.primary.withValues(alpha: 0.18)
        : FlowPayColors.mint100;
    final inactiveBg = isDark
        ? FlowPayColors.darkSurfaceElevated
        : FlowPayColors.canvas;
    final activeBorder =
        isDark ? FlowPayColors.primary.withValues(alpha: 0.4) : FlowPayColors.mintSurface;
    final inactiveBorder = FlowPayColors.borderOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? activeBg : inactiveBg,
        borderRadius: FlowPayRadii.chip,
        border: Border.all(color: isActive ? activeBorder : inactiveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isActive ? FlowPayColors.accent : FlowPayColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? (isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink)
                  : FlowPayColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
