import '../../design_system/states.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/activity_repository.dart';

class BmoniActivityRepository implements ActivityRepository {
  final FlowPayApiClient apiClient;
  final Map<String, List<ActivityModel>> _localActivitiesByUser = {};

  BmoniActivityRepository({required this.apiClient});

  @override
  void clearLocalActivities([String? userId]) {
    if (userId != null && userId.isNotEmpty) {
      _localActivitiesByUser.remove(userId);
    } else {
      _localActivitiesByUser.clear();
    }
  }

  @override
  Future<List<ActivityModel>> getRecentActivities({
    int limit = 20,
    ActivityCategory? category,
    ActivityType? type,
  }) async {
    final currentUserId =
        apiClient.userId.isNotEmpty ? apiClient.userId : 'usr_flowpay_sandbox_master';
    List<ActivityModel> remoteList = [];
    try {
      final res = await apiClient.get('/api/activity', queryParams: {
        'limit': limit.toString(),
        if (currentUserId.isNotEmpty) 'userId': currentUserId,
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
          String rawCounterparty = isReceived
              ? (sender ?? 'FlowPay Sender')
              : (recipient ??
                  (item['actor']?.toString() ?? 'FlowPay Rail'));

          // Format counterparty display name cleanly
          String cleanCounterparty = rawCounterparty;
          final senderName = details?['senderName']?.toString();
          if (isReceived && senderName != null && senderName.isNotEmpty) {
            cleanCounterparty = senderName;
          } else if (cleanCounterparty.startsWith('usr_personal_') ||
              cleanCounterparty.startsWith('usr_bmoni_') ||
              cleanCounterparty.startsWith('usr_flowpay_')) {
            if (cleanCounterparty == 'usr_flowpay_sandbox_master') {
              cleanCounterparty = 'FlowPay Master Account';
            } else {
              final suffix = cleanCounterparty.length > 4
                  ? cleanCounterparty.substring(cleanCounterparty.length - 4)
                  : cleanCounterparty;
              cleanCounterparty =
                  isReceived ? 'FlowPay Member (..$suffix)' : 'FlowPay Member';
            }
          }

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
            title = 'Received from $cleanCounterparty';
          } else if (recipient != null &&
              recipient.isNotEmpty &&
              (title == 'TRANSFER_COMPLETED' || title.contains('TRANSFER'))) {
            title = 'Transfer to $cleanCounterparty';
          } else if (title == 'MONEY_MISSION_EXECUTED' &&
              details?['rule'] != null) {
            title = '⚡ Mission: ${details!['rule']}';
          }

          String description = details?['description']?.toString() ?? '';
          if (description.isEmpty) {
            if (isReceived) {
              description = 'Incoming transfer from $cleanCounterparty';
            } else if (isCompleted && recipient != null) {
              description = 'Transfer to $cleanCounterparty';
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
              ? cleanCounterparty
              : (details?['fundingWallet']?.toString() ??
                  details?['source']?.toString());
          final destination = isReceived
              ? 'My Wallet'
              : (details?['destination']?.toString() ??
                  (recipient != null ? "$cleanCounterparty's Wallet" : null));

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
            counterparty: cleanCounterparty,
            source: source,
            destination: destination,
            isIncoming: isReceived,
            userId: currentUserId,
            timestamp: item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString()) ??
                    DateTime.now()
                : (item['createdAt'] != null
                    ? DateTime.tryParse(item['createdAt'].toString()) ??
                        DateTime.now()
                    : DateTime.now()),
            reference: details?['transferId']?.toString() ??
                details?['reference']?.toString() ??
                details?['transactionHash']?.toString() ??
                item['id']?.toString() ??
                '',
            metadata: details,
          );
        }).toList();
      }
    } catch (_) {}

    // Only merge local activities belonging to the active current user
    final userLocalActivities = _localActivitiesByUser[currentUserId] ?? [];
    final combined = <ActivityModel>[...userLocalActivities];

    for (final rem in remoteList) {
      final remTxHash = rem.metadata?['transactionHash']?.toString();
      final remTransferId = rem.metadata?['transferId']?.toString() ??
          rem.metadata?['proposalId']?.toString();

      final isDuplicate = combined.any((loc) {
        if (loc.id == rem.id) return true;
        if (loc.reference.isNotEmpty) {
          if (loc.reference == rem.reference) return true;
          if (remTxHash != null && loc.reference == remTxHash) return true;
          if (remTransferId != null && loc.reference == remTransferId) {
            return true;
          }
        }
        final locTxHash = loc.metadata?['transactionHash']?.toString();
        if (locTxHash != null && remTxHash != null && locTxHash == remTxHash) {
          return true;
        }
        return false;
      });

      if (!isDuplicate) {
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
    final uid = activity.userId ??
        (apiClient.userId.isNotEmpty
            ? apiClient.userId
            : 'usr_flowpay_sandbox_master');
    final userList = _localActivitiesByUser.putIfAbsent(uid, () => []);

    final idx = userList.indexWhere(
      (a) =>
          a.id == activity.id ||
          (a.reference.isNotEmpty && a.reference == activity.reference) ||
          (activity.metadata?['transactionHash'] != null &&
              activity.metadata!['transactionHash'] ==
                  a.metadata?['transactionHash']),
    );
    if (idx != -1) {
      userList[idx] = activity;
    } else {
      userList.insert(0, activity);
    }
    return activity;
  }
}
