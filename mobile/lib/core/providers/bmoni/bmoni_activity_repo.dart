import '../../design_system/states.dart';
import '../../network/api_client.dart';
import '../../repositories/activity_repository.dart';

class BmoniActivityRepository implements ActivityRepository {
  final FlowPayApiClient apiClient;

  BmoniActivityRepository({required this.apiClient});

  @override
  Future<List<ActivityModel>> getRecentActivities({
    int limit = 20,
    ActivityCategory? category,
  }) async {
    try {
      final res = await apiClient.get('/api/activity', queryParams: {
        'limit': limit.toString(),
        if (category != null) 'category': category.name.toUpperCase(),
      });

      if (res is List) {
        return res.map((item) {
          final catStr = (item['category'] as String? ?? 'SYSTEM').toLowerCase();
          ActivityCategory cat = ActivityCategory.system;
          if (catStr.contains('mission')) cat = ActivityCategory.mission;
          if (catStr.contains('transfer')) cat = ActivityCategory.transfer;
          if (catStr.contains('card')) cat = ActivityCategory.card;
          if (catStr.contains('fx')) cat = ActivityCategory.fx;
          if (catStr.contains('payroll')) cat = ActivityCategory.payroll;

          return ActivityModel(
            id: item['id']?.toString() ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
            title: item['action']?.toString() ?? 'Account Activity',
            description: item['actor']?.toString() ?? 'BMONI rail event recorded',
            category: cat,
            status: FlowPayAppStatus.completed,
            timestamp: item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
            reference: item['id']?.toString(),
            metadata: item['details_json'] as Map<String, dynamic>?,
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ActivityModel> recordActivity(ActivityModel activity) async {
    return activity;
  }
}
