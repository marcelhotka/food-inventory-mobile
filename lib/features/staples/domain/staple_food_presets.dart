class StapleFoodPreset {
  final String id;
  final String nameEn;
  final String nameSk;
  final String category;
  final double quantity;
  final String unit;

  const StapleFoodPreset({
    required this.id,
    required this.nameEn,
    required this.nameSk,
    required this.category,
    required this.quantity,
    required this.unit,
  });
}

const stapleFoodPresets = <StapleFoodPreset>[
  StapleFoodPreset(
    id: 'milk',
    nameEn: 'milk',
    nameSk: 'mlieko',
    category: 'dairy',
    quantity: 2,
    unit: 'l',
  ),
  StapleFoodPreset(
    id: 'eggs',
    nameEn: 'eggs',
    nameSk: 'vajcia',
    category: 'dairy',
    quantity: 10,
    unit: 'pcs',
  ),
  StapleFoodPreset(
    id: 'bread',
    nameEn: 'bread',
    nameSk: 'chlieb',
    category: 'grains',
    quantity: 1,
    unit: 'pcs',
  ),
  StapleFoodPreset(
    id: 'butter',
    nameEn: 'butter',
    nameSk: 'maslo',
    category: 'dairy',
    quantity: 250,
    unit: 'g',
  ),
  StapleFoodPreset(
    id: 'yogurt',
    nameEn: 'yogurt',
    nameSk: 'jogurt',
    category: 'dairy',
    quantity: 4,
    unit: 'pcs',
  ),
  StapleFoodPreset(
    id: 'rice',
    nameEn: 'rice',
    nameSk: 'ryža',
    category: 'grains',
    quantity: 1,
    unit: 'kg',
  ),
  StapleFoodPreset(
    id: 'pasta',
    nameEn: 'pasta',
    nameSk: 'cestoviny',
    category: 'grains',
    quantity: 500,
    unit: 'g',
  ),
  StapleFoodPreset(
    id: 'beans',
    nameEn: 'beans',
    nameSk: 'fazuľa',
    category: 'canned',
    quantity: 2,
    unit: 'pcs',
  ),
  StapleFoodPreset(
    id: 'tomato_sauce',
    nameEn: 'tomato sauce',
    nameSk: 'paradajková omáčka',
    category: 'canned',
    quantity: 2,
    unit: 'pcs',
  ),
  StapleFoodPreset(
    id: 'flour',
    nameEn: 'flour',
    nameSk: 'múka',
    category: 'grains',
    quantity: 1,
    unit: 'kg',
  ),
  StapleFoodPreset(
    id: 'oil',
    nameEn: 'oil',
    nameSk: 'olej',
    category: 'beverages',
    quantity: 1,
    unit: 'l',
  ),
];
