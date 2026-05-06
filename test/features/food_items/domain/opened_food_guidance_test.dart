import 'package:flutter_test/flutter_test.dart';
import 'package:food_inventory_mobile/features/food_items/domain/food_item.dart';
import 'package:food_inventory_mobile/features/food_items/domain/opened_food_guidance.dart';

void main() {
  group('opened food guidance', () {
    test('recommends short opened horizon for milk', () {
      final item = _foodItem(name: 'Milk', category: 'dairy');

      expect(recommendedOpenedUseWithinDays(item), 3);
    });

    test('recommends bread-specific opened horizon', () {
      final item = _foodItem(name: 'Chlieb', category: 'grains');

      expect(recommendedOpenedUseWithinDays(item), 4);
    });

    test('keeps earlier expiration when opening does not shorten it more', () {
      final item = _foodItem(
        name: 'Cheese',
        category: 'dairy',
        expirationDate: DateTime(2026, 5, 8),
      );

      expect(
        adjustedExpirationAfterOpening(item, openedDate: DateTime(2026, 5, 6)),
        DateTime(2026, 5, 8),
      );
    });

    test('shortens expiration when opened guidance is earlier', () {
      final item = _foodItem(
        name: 'Cheese',
        category: 'dairy',
        expirationDate: DateTime(2026, 5, 20),
      );

      expect(
        adjustedExpirationAfterOpening(item, openedDate: DateTime(2026, 5, 6)),
        DateTime(2026, 5, 10),
      );
    });
  });
}

FoodItem _foodItem({
  required String name,
  required String category,
  DateTime? expirationDate,
}) {
  final createdAt = DateTime(2026, 5, 6);
  return FoodItem(
    id: 'item-1',
    userId: 'user-1',
    householdId: 'household-1',
    name: name,
    barcode: null,
    category: category,
    storageLocation: 'fridge',
    quantity: 1,
    lowStockThreshold: null,
    unit: 'pcs',
    expirationDate: expirationDate,
    openedAt: null,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
