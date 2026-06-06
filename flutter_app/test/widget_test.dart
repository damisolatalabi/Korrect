import 'package:flutter_test/flutter_test.dart';

import 'package:korrect_app/main.dart';

void main() {
  testWidgets('Korrect app smoke test', (WidgetTester tester) async {
    // 앱이 정상적으로 빌드되는지 확인
    await tester.pumpWidget(const KorrectApp(showTutorial: false));
    // 홈 화면 AppBar 타이틀 확인
    expect(find.text('Korrect'), findsOneWidget);
  });
}
