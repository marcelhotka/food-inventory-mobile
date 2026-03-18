import 'food_item_prefill.dart';

class ScanCandidate {
  final String id;
  final FoodItemPrefill prefill;
  final double confidence;
  final bool isSelected;

  const ScanCandidate({
    required this.id,
    required this.prefill,
    required this.confidence,
    this.isSelected = true,
  });

  factory ScanCandidate.fromMap(Map<String, dynamic> map) {
    return ScanCandidate(
      id: map['id'] as String,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      isSelected: (map['is_selected'] as bool?) ?? true,
      prefill: FoodItemPrefill(
        name: map['name'] as String,
        barcode: map['barcode'] as String?,
        category: (map['category'] as String?) ?? 'other',
        storageLocation: (map['storage_location'] as String?) ?? 'pantry',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
        unit: (map['unit'] as String?) ?? 'pcs',
        expirationDate: map['expiration_date'] == null
            ? null
            : DateTime.parse(map['expiration_date'] as String),
        lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble(),
      ),
    );
  }

  ScanCandidate copyWith({
    String? id,
    FoodItemPrefill? prefill,
    double? confidence,
    bool? isSelected,
  }) {
    return ScanCandidate(
      id: id ?? this.id,
      prefill: prefill ?? this.prefill,
      confidence: confidence ?? this.confidence,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toInsertMap({
    required String scanSessionId,
    required int sortOrder,
    required bool isConfirmed,
  }) {
    return {
      'scan_session_id': scanSessionId,
      'name': prefill.name,
      'barcode': prefill.barcode,
      'category': prefill.category,
      'storage_location': prefill.storageLocation,
      'quantity': prefill.quantity,
      'unit': prefill.unit,
      'expiration_date': prefill.expirationDate
          ?.toIso8601String()
          .split('T')
          .first,
      'low_stock_threshold': prefill.lowStockThreshold,
      'confidence': confidence,
      'is_selected': isSelected,
      'is_confirmed': isConfirmed,
      'sort_order': sortOrder,
    };
  }
}
