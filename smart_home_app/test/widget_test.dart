import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_app/main.dart';
import 'package:smart_home_app/providers/home_provider.dart';

void main() {
  testWidgets('SmartHomeApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => HomeProvider()),
        ],
        child: const SmartHomeApp(),
      ),
    );

    // Verify main screen renders title
    expect(find.text('Home Controller'), findsOneWidget);
  });
}
