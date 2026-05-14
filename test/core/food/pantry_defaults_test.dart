import 'package:flutter_test/flutter_test.dart';
import 'package:food_inventory_mobile/core/food/pantry_defaults.dart';

void main() {
  group('defaultPantryCategory', () {
    test('keeps dairy items in dairy', () {
      expect(defaultPantryCategory('milk'), 'dairy');
      expect(defaultPantryCategory('cheese'), 'dairy');
      expect(defaultPantryCategory('yogurt'), 'dairy');
    });

    test('treats eggs as other instead of dairy', () {
      expect(defaultPantryCategory('eggs'), 'other');
    });

    test('keeps meat and pantry staples in expected groups', () {
      expect(defaultPantryCategory('ham'), 'meat');
      expect(defaultPantryCategory('bread'), 'grains');
      expect(defaultPantryCategory('peas'), 'frozen');
    });
  });

  group('defaultPantryStorage', () {
    test('stores chilled items in fridge', () {
      expect(defaultPantryStorage('milk'), 'fridge');
      expect(defaultPantryStorage('eggs'), 'fridge');
      expect(defaultPantryStorage('ham'), 'fridge');
    });

    test('stores frozen peas in freezer', () {
      expect(defaultPantryStorage('peas'), 'freezer');
    });

    test('falls back to pantry for shelf-stable items', () {
      expect(defaultPantryStorage('bread'), 'pantry');
      expect(defaultPantryStorage('unknown-item'), 'pantry');
    });
  });
}
