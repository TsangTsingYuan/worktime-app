import 'package:flutter_test/flutter_test.dart';
import 'package:worktime_app/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WorktimeApp());
    // One for the title, one for the button
    expect(find.text('登录'), findsNWidgets(2));
  });
}
