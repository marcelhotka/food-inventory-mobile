import 'package:flutter_test/flutter_test.dart';
import 'package:food_inventory_mobile/features/households/domain/household.dart';

void main() {
  group('Household.inviteCode', () {
    test(
      'returns the first 8 uppercase characters of a UUID without hyphens',
      () {
        final household = _household(
          id: '12345678-abcd-4ef0-9876-1234567890ab',
        );

        expect(household.inviteCode, '12345678');
      },
    );

    test('uppercases short non-hyphenated values', () {
      final household = _household(id: 'ab12cd');

      expect(household.inviteCode, 'AB12CD');
    });
  });
}

Household _household({required String id}) {
  final timestamp = DateTime(2026, 5, 13);
  return Household(
    id: id,
    name: 'Safo Home',
    ownerUserId: 'user-1',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
