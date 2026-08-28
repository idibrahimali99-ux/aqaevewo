import 'package:flutter_test/flutter_test.dart';

import 'package:ibrahim_vpn/main.dart';

void main() {
  testWidgets('app title loads', (tester) async {
    await tester.pumpWidget(const IbrahimVpnApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ابراهيم VPN'), findsWidgets);
  });
}
