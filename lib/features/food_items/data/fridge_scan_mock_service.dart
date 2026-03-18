import '../domain/food_item_prefill.dart';
import '../domain/scan_candidate.dart';

class FridgeScanMockService {
  const FridgeScanMockService();

  Future<List<ScanCandidate>> analyzePhoto({required String imageLabel}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    return const [
      ScanCandidate(
        id: 'scan-milk',
        confidence: 0.94,
        prefill: FoodItemPrefill(
          name: 'Milk',
          category: 'dairy',
          storageLocation: 'fridge',
          quantity: 1,
          unit: 'l',
        ),
      ),
      ScanCandidate(
        id: 'scan-eggs',
        confidence: 0.91,
        prefill: FoodItemPrefill(
          name: 'Eggs',
          category: 'dairy',
          storageLocation: 'fridge',
          quantity: 6,
          unit: 'pcs',
        ),
      ),
      ScanCandidate(
        id: 'scan-carrots',
        confidence: 0.82,
        prefill: FoodItemPrefill(
          name: 'Carrots',
          category: 'produce',
          storageLocation: 'fridge',
          quantity: 3,
          unit: 'pcs',
        ),
      ),
      ScanCandidate(
        id: 'scan-cheese',
        confidence: 0.77,
        prefill: FoodItemPrefill(
          name: 'Cheese',
          category: 'dairy',
          storageLocation: 'fridge',
          quantity: 200,
          unit: 'g',
        ),
      ),
    ];
  }
}
