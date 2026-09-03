import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/repositories/activity_repository.dart';
import '../../core/state/app_state.dart';

class PersonalActivityScreen extends StatefulWidget {
  final AppState appState;

  const PersonalActivityScreen({super.key, required this.appState});

  @override
  State<PersonalActivityScreen> createState() => _PersonalActivityScreenState();
}

class _PersonalActivityScreenState extends State<PersonalActivityScreen> {
  List<ActivityModel> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    Widget content = _isLoading
        ? const FlowPayLoadingState(message: 'Loading financial audit trail...')
        : RefreshIndicator(
            onRefresh: _loadActivities,
            child: ListView.builder(
              padding: FlowPaySpacing.insetXl,
              itemCount: _activities.length,
              itemBuilder: (ctx, i) {
                final a = _activities[i];
                IconData catIcon = Icons.history;
                if (a.category == ActivityCategory.mission) catIcon = Icons.bolt;
                if (a.category == ActivityCategory.transfer) catIcon = Icons.arrow_outward;
                if (a.category == ActivityCategory.card) catIcon = Icons.credit_card;
                if (a.category == ActivityCategory.fx) catIcon = Icons.currency_exchange;

                return Padding(
                  padding: const EdgeInsets.only(bottom: FlowPaySpacing.md),
                  child: FlowPayCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? FlowPayColors.darkSurfaceElevated
                                : FlowPayColors.lightSurfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(catIcon, color: FlowPayColors.primaryLight, size: 20),
                        ),
                        const SizedBox(width: FlowPaySpacing.md),
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
                              const SizedBox(height: 3),
                              Text(
                                a.description,
                                style: FlowPayTypography.caption.copyWith(
                                  color: isDark
                                      ? FlowPayColors.darkTextSecondary
                                      : FlowPayColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: FlowPaySpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
                  ),
                );
              },
            ),
          );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Personal Activity'),
        ),
        body: content,
      );
    }

    return content;
  }
}
