import '../../design_system/states.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
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

      final list = (res is Map && res['items'] is List)
          ? res['items'] as List
          : (res is Map && res['data'] is List)
              ? res['data'] as List
              : (res is List ? res : []);

      if (list.isNotEmpty) {
        remoteList = list.map((item) {
          final catStr =
              (item['category'] as String? ?? 'SYSTEM').toLowerCase();
          ActivityCategory cat = ActivityCategory.system;
          if (catStr.contains('mission')) cat = ActivityCategory.mission;
          if (catStr.contains('transfer')) cat = ActivityCategory.transfer;
          if (catStr.contains('card')) cat = ActivityCategory.card;
          if (catStr.contains('fx')) cat = ActivityCategory.fx;
          if (catStr.contains('payroll')) cat = ActivityCategory.payroll;

          final details = (item['details_json'] ?? item['detailsJson'])
              as Map<String, dynamic>?;

          final isReceived = item['action'] == 'TRANSFER_RECEIVED';
          final isCompleted = item['action'] == 'TRANSFER_COMPLETED';

          // Parse amount & currency safely
          Money? amount;
          final rawAmt = details?['amountReceived'] ??
              details?['amount'] ??
              details?['amountSent'] ??
              item['amount'];
          if (rawAmt != null) {
            final cleanAmt = rawAmt.toString().replaceAll(',', '');
            final currStr = (details?['currencyReceived'] ??
                    details?['currency'] ??
                    details?['currencySent'] ??
                    item['currency'] ??
                    'USD')
                .toString()
                .toUpperCase();
            final cur = Currency.fromCode(currStr);
            if (double.tryParse(cleanAmt) != null) {
              amount = Money.fromMajorString(cleanAmt, cur);
            } else if (int.tryParse(cleanAmt) != null) {
              amount = Money.fromMinor(int.parse(cleanAmt), cur);
            }
          }

          final sender = details?['sender']?.toString();
          final recipient = details?['recipient']?.toString() ??
              details?['counterparty']?.toString();
          final counterparty = isReceived
              ? (sender ?? 'FlowPay Sender')
              : (recipient ??
                  (item['actor']?.toString() ?? 'FlowPay Rail'));

          ActivityType actType = ActivityType.wallet;
          if (cat == ActivityCategory.transfer || isReceived || isCompleted) {
            actType = ActivityType.transfer;
          }
          if (cat == ActivityCategory.mission) actType = ActivityType.mission;
          if (cat == ActivityCategory.card) actType = ActivityType.card;
          if (cat == ActivityCategory.fx) actType = ActivityType.conversion;
          if (cat == ActivityCategory.payroll) actType = ActivityType.transfer;

          String title = item['action']?.toString() ?? 'Account Activity';
          if (isReceived) {
            title = 'Received from $counterparty';
          } else if (recipient != null &&
              recipient.isNotEmpty &&
              (title == 'TRANSFER_COMPLETED' || title.contains('TRANSFER'))) {
            title = 'Transfer to $recipient';
          } else if (title == 'MONEY_MISSION_EXECUTED' &&
              details?['rule'] != null) {
            title = '⚡ Mission: ${details!['rule']}';
          }

          String description = details?['description']?.toString() ?? '';
          if (description.isEmpty) {
            if (isReceived) {
              description = 'Incoming transfer from $counterparty';
            } else if (isCompleted && recipient != null) {
              description = 'Transfer to $recipient';
            } else {
              description = item['actor']?.toString() ?? 'BMONI rail event recorded';
            }
          }

          final statusStr = (details?['status'] ??
                  details?['bmoniStatus'] ??
                  item['status'] ??
                  'COMPLETED')
              .toString()
              .toUpperCase();
          FlowPayAppStatus status = FlowPayAppStatus.completed;
          if (statusStr.contains('FAIL')) status = FlowPayAppStatus.failed;
          if (statusStr.contains('PENDING')) status = FlowPayAppStatus.pending;
          if (statusStr.contains('CANCEL')) status = FlowPayAppStatus.cancelled;

          final source = isReceived
              ? counterparty
              : (details?['fundingWallet']?.toString() ??
                  details?['source']?.toString());
          final destination = isReceived
              ? 'My Wallet'
              : (details?['destination']?.toString() ??
                  (recipient != null ? "$recipient's Wallet" : null));

          return ActivityModel(
            id: item['id']?.toString() ??
                'act_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            description: description,
            category: cat,
            type: actType,
            status: status,
            amount: amount,
            currency: amount?.currency,
            counterparty: counterparty,
            source: source,
            destination: destination,
            timestamp: item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString()) ??
                    DateTime.now()
                : (item['createdAt'] != null
                    ? DateTime.tryParse(item['createdAt'].toString()) ??
                        DateTime.now()
                    : DateTime.now()),
            reference: details?['transferId']?.toString() ??
                details?['reference']?.toString() ??
                item['id']?.toString() ??
                '',
            metadata: details,
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
