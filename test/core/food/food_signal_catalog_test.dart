import 'package:flutter_test/flutter_test.dart';
import 'package:food_inventory_mobile/core/food/food_signal_catalog.dart';

void main() {
  group('deriveFoodSignalInfo', () {
    test('does not add lactose signal to eggs', () {
      final info = deriveFoodSignalInfo('Eggs');

      expect(info.itemKey, 'eggs');
      expect(info.signals.contains('eggs'), isTrue);
      expect(info.signals.contains('lactose'), isFalse);
    });

    test('treats lactose-free cheese as safe from lactose signal', () {
      final info = deriveFoodSignalInfo('Bezlaktózový syr');

      expect(info.itemKey, 'cheese');
      expect(info.isLactoseFree, isTrue);
      expect(info.signals.contains('lactose'), isFalse);
    });

    test('treats gluten-free bread as safe from gluten signal', () {
      final info = deriveFoodSignalInfo('Bezlepkový chlieb');

      expect(info.itemKey, 'bread');
      expect(info.isGlutenFree, isTrue);
      expect(info.signals.contains('gluten'), isFalse);
    });

    test('detects gluten in regular baguette aliases', () {
      final info = deriveFoodSignalInfo('Bageta');

      expect(info.itemKey, 'bread');
      expect(info.signals.contains('gluten'), isTrue);
    });
  });
}
