import 'package:flutter_test/flutter_test.dart';
import 'package:food_inventory_mobile/features/households/domain/household_join_target.dart';

void main() {
  group('parseHouseholdJoinTarget', () {
    test('accepts short invite code with separators', () {
      final target = parseHouseholdJoinTarget('ABCD-1234');

      expect(target.value, 'abcd1234');
      expect(target.isFullHouseholdId, isFalse);
    });

    test('accepts full uuid with or without hyphens', () {
      final hyphenated = parseHouseholdJoinTarget(
        '12345678-abcd-4ef0-9876-1234567890ab',
      );
      final compact = parseHouseholdJoinTarget(
        '12345678abcd4ef098761234567890ab',
      );

      expect(hyphenated.value, '12345678-abcd-4ef0-9876-1234567890ab');
      expect(hyphenated.isFullHouseholdId, isTrue);
      expect(compact.value, '12345678-abcd-4ef0-9876-1234567890ab');
      expect(compact.isFullHouseholdId, isTrue);
    });

    test('rejects malformed long invite codes', () {
      expect(
        () => parseHouseholdJoinTarget('ABCDEF12345'),
        throwsA(isA<HouseholdJoinCodeFormatException>()),
      );
    });
  });
}
