import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/food/food_signal_catalog.dart';
import '../domain/barcode_lookup_result.dart';
import '../domain/food_item_prefill.dart';

class BarcodeLookupService {
  const BarcodeLookupService();

  static final Map<String, FoodItemPrefill> _memoryCache = {};

  static const Map<String, FoodItemPrefill> _demoProducts = {
    '8588000123456': FoodItemPrefill(
      name: 'Milk',
      barcode: '8588000123456',
      quantity: 1,
      unit: 'l',
      category: 'dairy',
      storageLocation: 'fridge',
      lowStockThreshold: 1,
    ),
    '8586001234567': FoodItemPrefill(
      name: 'Yogurt',
      barcode: '8586001234567',
      quantity: 1,
      unit: 'pcs',
      category: 'dairy',
      storageLocation: 'fridge',
      lowStockThreshold: 2,
    ),
    '8594000000001': FoodItemPrefill(
      name: 'Rice',
      barcode: '8594000000001',
      quantity: 1,
      unit: 'kg',
      category: 'grains',
      storageLocation: 'pantry',
      lowStockThreshold: 1,
    ),
    '5901234123457': FoodItemPrefill(
      name: 'Pasta',
      barcode: '5901234123457',
      quantity: 1,
      unit: 'g',
      category: 'grains',
      storageLocation: 'pantry',
      lowStockThreshold: 500,
    ),
  };

  Future<BarcodeLookupResult?> lookup(String barcode) async {
    final normalizedBarcode = barcode.trim();
    final cached = _memoryCache[normalizedBarcode];
    if (cached != null) {
      return BarcodeLookupResult(
        prefill: cached,
        source: BarcodeLookupSource.cache,
      );
    }

    try {
      final onlineResult = await _lookupOnline(
        normalizedBarcode,
      ).timeout(const Duration(seconds: 2));
      if (onlineResult != null) {
        _memoryCache[normalizedBarcode] = onlineResult;
        return BarcodeLookupResult(
          prefill: onlineResult,
          source: BarcodeLookupSource.online,
        );
      }
    } catch (_) {
      // Fallback to local demo products when the online lookup is unavailable.
    }

    final demoResult = _demoProducts[normalizedBarcode];
    if (demoResult != null) {
      _memoryCache[normalizedBarcode] = demoResult;
      return BarcodeLookupResult(
        prefill: demoResult,
        source: BarcodeLookupSource.demo,
      );
    }

    return null;
  }

  List<String> get demoCodes => _demoProducts.keys.toList(growable: false);

  Future<FoodItemPrefill?> _lookupOnline(String barcode) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return null;
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final product = payload['product'];

    if (product is! Map<String, dynamic>) {
      return null;
    }

    final name = _extractName(product);
    if (name == null || name.isEmpty) {
      return null;
    }

    final parsedQuantity = _parseQuantity(product['quantity'] as String?);
    final defaults = _prefillDefaultsForName(name);
    final parsedUnit = parsedQuantity?.$2;
    final resolvedUnit = parsedUnit ?? defaults.unit;
    final resolvedQuantity = parsedQuantity?.$1 ?? defaults.quantity;
    final resolvedThreshold = _defaultLowStockThreshold(
      itemKey: defaults.itemKey,
      unit: resolvedUnit,
      quantity: resolvedQuantity,
    );

    return FoodItemPrefill(
      name: name,
      barcode: barcode,
      quantity: resolvedQuantity,
      unit: resolvedUnit,
      category: defaults.category,
      storageLocation: defaults.storageLocation,
      lowStockThreshold: resolvedThreshold,
    );
  }

  String? _extractName(Map<String, dynamic> product) {
    final name = product['product_name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }

    final genericName = product['generic_name'] as String?;
    if (genericName != null && genericName.trim().isNotEmpty) {
      return genericName.trim();
    }

    final productNameEn = product['product_name_en'] as String?;
    if (productNameEn != null && productNameEn.trim().isNotEmpty) {
      return productNameEn.trim();
    }

    final brands = product['brands'] as String?;
    if (brands != null && brands.trim().isNotEmpty) {
      return brands.trim();
    }

    return null;
  }

  (double, String)? _parseQuantity(String? quantityText) {
    if (quantityText == null) {
      return null;
    }

    final normalized = quantityText.trim().toLowerCase();
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*([a-z]+)',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final quantity = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (quantity == null) {
      return null;
    }

    final rawUnit = match.group(2)!;
    final unit = switch (rawUnit) {
      'g' => 'g',
      'kg' => 'kg',
      'ml' => 'ml',
      'l' => 'l',
      _ => 'pcs',
    };

    return (quantity, unit);
  }

  ({
    String itemKey,
    String category,
    String storageLocation,
    double quantity,
    String unit,
  })
  _prefillDefaultsForName(String name) {
    final info = deriveFoodSignalInfo(name);
    return (
      itemKey: info.itemKey,
      category: _defaultCategory(info.itemKey),
      storageLocation: _defaultStorage(info.itemKey),
      quantity: _defaultQuantity(info.itemKey),
      unit: _defaultUnit(info.itemKey),
    );
  }

  String _defaultCategory(String itemKey) {
    switch (itemKey) {
      case 'milk':
      case 'cheese':
      case 'yogurt':
      case 'butter':
      case 'cream':
      case 'eggs':
        return 'dairy';
      case 'ham':
      case 'chicken':
        return 'meat';
      case 'peas':
        return 'frozen';
      case 'bread':
      case 'pasta':
      case 'rice':
      case 'beans':
      case 'flour':
        return 'grains';
      case 'tomato':
        return 'produce';
      default:
        return 'other';
    }
  }

  String _defaultStorage(String itemKey) {
    switch (itemKey) {
      case 'milk':
      case 'cheese':
      case 'yogurt':
      case 'butter':
      case 'cream':
      case 'eggs':
      case 'ham':
      case 'chicken':
        return 'fridge';
      case 'peas':
        return 'freezer';
      default:
        return 'pantry';
    }
  }

  String _defaultUnit(String itemKey) {
    switch (itemKey) {
      case 'milk':
      case 'cream':
      case 'oil':
      case 'juice':
      case 'water':
        return 'l';
      case 'rice':
      case 'flour':
      case 'beans':
      case 'pasta':
      case 'cheese':
      case 'ham':
      case 'chicken':
      case 'peas':
      case 'butter':
        return 'g';
      default:
        return 'pcs';
    }
  }

  double _defaultQuantity(String itemKey) {
    switch (itemKey) {
      case 'milk':
      case 'juice':
      case 'water':
      case 'oil':
        return 1;
      case 'rice':
      case 'flour':
      case 'beans':
      case 'pasta':
      case 'cheese':
      case 'ham':
      case 'chicken':
      case 'peas':
      case 'butter':
        return 500;
      default:
        return 1;
    }
  }

  double? _defaultLowStockThreshold({
    required String itemKey,
    required String unit,
    required double quantity,
  }) {
    switch (itemKey) {
      case 'milk':
        return unit == 'ml' ? 500 : 1;
      case 'bread':
        return 1;
      case 'eggs':
        return 4;
      case 'yogurt':
        return 2;
      case 'cheese':
        return unit == 'g' ? 150 : quantity / 2;
      case 'pasta':
      case 'rice':
      case 'beans':
      case 'flour':
        return unit == 'g' ? 300 : quantity / 2;
      default:
        return null;
    }
  }
}
