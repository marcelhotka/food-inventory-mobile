import 'food_item_prefill.dart';

enum BarcodeLookupSource { cache, online, demo }

class BarcodeLookupResult {
  final FoodItemPrefill prefill;
  final BarcodeLookupSource source;

  const BarcodeLookupResult({required this.prefill, required this.source});
}
