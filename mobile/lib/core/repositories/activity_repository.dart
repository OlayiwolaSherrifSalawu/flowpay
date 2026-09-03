import '../design_system/states.dart';
import '../money/money.dart';

enum ActivityCategory {
  mission,
  transfer,
  card,
  fx,
  payroll,
  system,
}

class ActivityModel {
  final String id;
  final String title;
  final String description;
  final Money? amount;
  final ActivityCategory category;
  final FlowPayAppStatus status;
  final DateTime timestamp;
  final String? reference;
  final Map<String, dynamic>? metadata;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    this.amount,
    required this.category,
    required this.status,
    required this.timestamp,
    this.reference,
    this.metadata,
  });

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 7).floor()}w ago';
    }
  }
}

abstract class ActivityRepository {
  Future<List<ActivityModel>> getRecentActivities({
    int limit = 20,
    ActivityCategory? category,
  });

  Future<ActivityModel> recordActivity(ActivityModel activity);
}
