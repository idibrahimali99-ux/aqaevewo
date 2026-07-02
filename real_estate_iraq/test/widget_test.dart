import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:real_estate_iraq/src/app/app.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    // اجعل حجم الشاشة كبيرًا لتجنب فشل Golden/Layout بسبب كروت الشبكة.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
