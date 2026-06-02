import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HlthApp()));
    expect(find.text('HLTH'), findsWidgets);
  });
}
