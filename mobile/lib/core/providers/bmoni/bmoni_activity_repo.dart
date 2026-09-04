import '../../design_system/states.dart';
import '../../network/api_client.dart';
import '../../repositories/activity_repository.dart';

class BmoniActivityRepository implements ActivityRepository {
  final FlowPayApiClient apiClient;
  final List<ActivityModel> _localActivities = [];

  BmoniActivityRepository({required this.apiClient});

  @override
  Future<List<ActivityModel>> getRecentActivities({
    int limit = 20,
    ActivityCategory? category,
    ActivityType? type,
  }) async {
    List<ActivityModel> remoteList = [];
    try {
      final res = await apiClient.get('/api/activity', queryParams: {
        'limit': limit.toString(),
        if (category != null) 'category': category.name.toUpperCase(),
        if (type != null) 'type': type.name.toUpperCase(),
      });

      if (res is List) {
        remoteList = res.map((item) {
          final catStr =
              (item['category'] as String? ?? 'SYSTEM').toLowerCase();
          ActivityCategory cat = ActivityCategory.system;
          if (catStr.contains('mission')) cat = ActivityCategory.mission;
          if (catStr.contains('transfer')) cat = ActivityCategory.transfer;
          if (catStr.contains('card')) cat = ActivityCategory.card;
          if (catStr.contains('fx')) cat = ActivityCategory.fx;
          if (catStr.contains('payroll')) cat = ActivityCategory.payroll;

          return ActivityModel(
            id: item['id']?.toString() ??
                'act_${DateTime.now().millisecondsSinceEpoch}',
            title: item['action']?.toString() ?? 'Account Activity',
            description:
                item['actor']?.toString() ?? 'BMONI rail event recorded',
            category: cat,
            status: FlowPayAppStatus.completed,
            timestamp: item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
            reference: item['id']?.toString(),
            metadata: item['details_json'] as Map<String, dynamic>?,
          );
        }).toList();
      }
    } catch (_) {}

    // Merge local activities with remote, preserving local updates and ordering by timestamp desc
    final combined = <ActivityModel>[..._localActivities];
    for (final rem in remoteList) {
      if (!combined
          .any((loc) => loc.id == rem.id || loc.reference == rem.reference)) {
        combined.add(rem);
      }
    }

    var filtered = combined;
    if (type != null) {
      filtered = filtered.where((a) => a.type == type).toList();
    } else if (category != null) {
      filtered = filtered.where((a) => a.category == category).toList();
    }

    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered.take(limit).toList();
  }

  @override
  Future<ActivityModel> recordActivity(ActivityModel activity) async {
    final idx = _localActivities.indexWhere(
      (a) =>
          a.id == activity.id ||
          (a.reference.isNotEmpty && a.reference == activity.reference),
    );
    if (idx != -1) {
      _localActivities[idx] = activity;
    } else {
      _localActivities.insert(0, activity);
    }
    return activity;
  }
}
