import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/missions/mission_intent.dart';

void main() {
  test('mission enums serialize to the backend SCREAMING_SNAKE wire format', () {
    expect(wireName(MissionActionType.convertFx.name), 'CONVERT_FX');
    expect(wireName(MissionActionType.sweepVault.name), 'SWEEP_VAULT');
    expect(wireName(MissionActionType.hold.name), 'HOLD');
    expect(wireName(MissionIntentType.splitIncoming.name), 'SPLIT_INCOMING');
    for (final t in MissionActionType.values) {
      expect(MissionActionType.fromString(wireName(t.name)), t, reason: 'round-trips ${t.name}');
    }
    for (final t in MissionIntentType.values) {
      expect(MissionIntentType.fromString(wireName(t.name)), t, reason: 'round-trips ${t.name}');
    }
  });
}
