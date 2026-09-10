import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/network/api_client.dart';
import 'package:flowpay_mobile/core/providers/bmoni/bmoni_activity_repo.dart';
import 'package:flowpay_mobile/core/repositories/activity_repository.dart';
import 'package:flowpay_mobile/core/design_system/states.dart';

void main() {
  group('Activity Direction and User Isolation Tests', () {
    test('ActivityModel correctly identifies incoming transfers and displayIcon', () {
      final outgoing = ActivityModel(
        id: 'act_out_1',
        title: 'Transfer to EVM Account',
        description: 'Send 100 CAD to 0x933c',
        amount: Money.fromMajorString('100.00', Currency.cad),
        type: ActivityType.transfer,
        category: ActivityCategory.transfer,
        counterparty: '0x933c...9473',
        status: FlowPayAppStatus.completed,
        timestamp: DateTime.now(),
      );

      expect(outgoing.isIncoming, isFalse);
      expect(outgoing.displayIcon, Icons.arrow_outward);

      final incoming = ActivityModel(
        id: 'act_in_1',
        title: 'Received from FlowPay Member',
        description: 'Incoming transfer of 100 CAD',
        amount: Money.fromMajorString('100.00', Currency.cad),
        type: ActivityType.transfer,
        category: ActivityCategory.transfer,
        counterparty: 'FlowPay Member (..9579)',
        status: FlowPayAppStatus.completed,
        timestamp: DateTime.now(),
        isIncoming: true,
      );

      expect(incoming.isIncoming, isTrue);
      expect(incoming.displayIcon, Icons.south_west);
    });

    test('BmoniActivityRepository isolates local activities per user', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': []}), 200);
      });

      final apiClient = FlowPayApiClient(client: mockClient, userId: 'usr_sender_A');
      final repo = BmoniActivityRepository(apiClient: apiClient);

      // Sender A records a local send activity
      await repo.recordActivity(ActivityModel(
        id: 'act_local_sender_A',
        title: 'Send CA\$100.00 to EVM Account',
        description: 'Transfer to 0x933c',
        amount: Money.fromMajorString('100.00', Currency.cad),
        type: ActivityType.transfer,
        category: ActivityCategory.transfer,
        status: FlowPayAppStatus.completed,
        timestamp: DateTime.now(),
      ));

      // User A fetches activities -> Sees their local send activity
      final actsForA = await repo.getRecentActivities();
      expect(actsForA.length, 1);
      expect(actsForA.first.id, 'act_local_sender_A');

      // Now switch user to Receiver B
      apiClient.setUserId('usr_receiver_B');

      // Receiver B fetches activities -> Must NOT see User A's send activity!
      final actsForB = await repo.getRecentActivities();
      expect(actsForB, isEmpty, reason: 'Receiver must not inherit Sender A local activities');
    });

    test('BmoniActivityRepository sets isIncoming: true for TRANSFER_RECEIVED from backend', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'act_recv_999',
                'category': 'PERSONAL',
                'action': 'TRANSFER_RECEIVED',
                'actor': 'usr_receiver_B',
                'detailsJson': {
                  'amount': '100.00',
                  'currency': 'CAD',
                  'sender': 'usr_personal_1788911299579',
                  'counterparty': 'usr_personal_1788911299579',
                  'status': 'COMPLETED',
                },
                'createdAt': DateTime.now().toIso8601String(),
              }
            ]
          }),
          200,
        );
      });

      final apiClient = FlowPayApiClient(client: mockClient, userId: 'usr_receiver_B');
      final repo = BmoniActivityRepository(apiClient: apiClient);

      final acts = await repo.getRecentActivities();
      expect(acts.length, 1);
      final item = acts.first;

      expect(item.isIncoming, isTrue);
      expect(item.displayIcon, Icons.south_west);
      expect(item.title, startsWith('Received from'));
      expect(item.counterparty, 'FlowPay Member (..9579)');
    });
  });
}
