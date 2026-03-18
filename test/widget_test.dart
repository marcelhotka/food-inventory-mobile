import 'package:flutter_test/flutter_test.dart';

import 'package:food_inventory_mobile/app/app.dart';

void main() {
  testWidgets('renders bootstrap home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FoodInventoryApp());

    await tester.pump();

    expect(find.text('Setup needed'), findsOneWidget);
  });
}
