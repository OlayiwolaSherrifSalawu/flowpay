import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/navigation/invite_link.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef0123456789abcdef';
  test('parses web links, app links and bare tokens; rejects everything else', () {
    expect(InviteLink.parse('https://app.flowpay.finance/invite/$token'), token);
    expect(InviteLink.parse('flowpay://invite/$token'), token);
    expect(InviteLink.parse('  $token '), token);
    expect(InviteLink.parse('ada@example.com'), isNull);
    expect(InviteLink.parse('${token}zz'), isNull);
    expect(InviteLink.parse(null), isNull);
  });
}
