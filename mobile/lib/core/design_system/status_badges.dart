import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

enum FlowPayAppStatus {
  loading,
  success,
  error,
  empty,
  pending,
  awaitingApproval,
  processing,
  completed,
  failed,
  cancelled,
}

extension FlowPayAppStatusX on FlowPayAppStatus {
  String get label {
    switch (this) {
      case FlowPayAppStatus.loading:
        return 'Loading';
      case FlowPayAppStatus.success:
        return 'Success';
      case FlowPayAppStatus.error:
        return 'Error';
      case FlowPayAppStatus.empty:
        return 'Empty';
      case FlowPayAppStatus.pending:
        return 'Pending';
      case FlowPayAppStatus.awaitingApproval:
        return 'Awaiting Approval';
      case FlowPayAppStatus.processing:
        return 'Processing';
      case FlowPayAppStatus.completed:
        return 'Completed';
      case FlowPayAppStatus.failed:
        return 'Failed';
      case FlowPayAppStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case FlowPayAppStatus.loading:
      case FlowPayAppStatus.processing:
        return FlowPayColors.info;
      case FlowPayAppStatus.success:
      case FlowPayAppStatus.completed:
        return FlowPayColors.accent;
      case FlowPayAppStatus.pending:
      case FlowPayAppStatus.awaitingApproval:
        return FlowPayColors.warning;
      case FlowPayAppStatus.error:
      case FlowPayAppStatus.failed:
        return FlowPayColors.error;
      case FlowPayAppStatus.cancelled:
      case FlowPayAppStatus.empty:
        return FlowPayColors.darkTextTertiary;
    }
  }
}

class FlowPayBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;
  final IconData? icon;

  const FlowPayBadge({
    super.key,
    required this.label,
    this.color = FlowPayColors.primary,
    this.showDot = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: FlowPaySpacing.borderRadiusSm,
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class FlowPayStatusBadge extends StatelessWidget {
  final FlowPayAppStatus? appStatus;
  final String? status;
  final bool showDot;

  const FlowPayStatusBadge({
    super.key,
    this.appStatus,
    this.status,
    this.showDot = true,
  }) : assert(appStatus != null || status != null,
            'Provide either appStatus or status');

  @override
  Widget build(BuildContext context) {
    if (appStatus != null) {
      return FlowPayBadge(
        label: appStatus!.label,
        color: appStatus!.color,
        showDot: showDot,
      );
    }

    final s = status!.toUpperCase();
    Color color;

    switch (s) {
      case 'ACTIVE':
      case 'LINKED':
      case 'SUCCESS':
      case 'COMPLETED':
      case 'PAID':
        color = FlowPayColors.accent;
        break;
      case 'PENDING':
      case 'INVITED':
      case 'PROCESSING':
      case 'AWAITING_APPROVAL':
        color = FlowPayColors.warning;
        break;
      case 'FROZEN':
      case 'SUSPENDED':
      case 'FAILED':
      case 'REJECTED':
        color = FlowPayColors.error;
        break;
      case 'CANCELLED':
        color = FlowPayColors.darkTextTertiary;
        break;
      case 'SELF-CUSTODY (B-KEY)':
      case 'SECURE':
        color = FlowPayColors.primaryLight;
        break;
      default:
        color = FlowPayColors.darkTextSecondary;
    }

    return FlowPayBadge(
      label: status!,
      color: color,
      showDot: showDot,
    );
  }
}

// Alias for backward compatibility
typedef StatusBadge = FlowPayStatusBadge;
