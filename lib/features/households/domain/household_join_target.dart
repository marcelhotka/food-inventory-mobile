typedef HouseholdJoinTarget = ({String value, bool isFullHouseholdId});

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

HouseholdJoinTarget parseHouseholdJoinTarget(String rawCode) {
  final trimmed = rawCode.trim();
  if (trimmed.isEmpty) {
    throw const HouseholdJoinCodeFormatException('Household code is empty.');
  }

  if (_uuidPattern.hasMatch(trimmed)) {
    return (value: trimmed.toLowerCase(), isFullHouseholdId: true);
  }

  final compact = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  if (compact.isEmpty) {
    throw const HouseholdJoinCodeFormatException('Household code is empty.');
  }

  if (compact.length == 32) {
    return (
      value:
          '${compact.substring(0, 8)}-'
          '${compact.substring(8, 12)}-'
          '${compact.substring(12, 16)}-'
          '${compact.substring(16, 20)}-'
          '${compact.substring(20)}',
      isFullHouseholdId: true,
    );
  }

  if (compact.length > 8) {
    throw const HouseholdJoinCodeFormatException(
      'Household code has invalid format.',
    );
  }

  return (value: compact, isFullHouseholdId: false);
}

class HouseholdJoinCodeFormatException implements Exception {
  final String message;

  const HouseholdJoinCodeFormatException(this.message);

  @override
  String toString() => message;
}
