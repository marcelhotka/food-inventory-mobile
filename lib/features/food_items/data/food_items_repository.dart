import '../domain/food_item.dart';
import 'food_item_remote_data_source.dart';

class FoodItemsRepository {
  FoodItemsRepository({
    required String householdId,
    FoodItemRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ??
           FoodItemRemoteDataSource(householdId: householdId);

  final FoodItemRemoteDataSource _remoteDataSource;

  Future<List<FoodItem>> getFoodItems() {
    return _remoteDataSource.fetchFoodItems();
  }

  Future<FoodItem> addFoodItem(FoodItem item) {
    return _remoteDataSource.createFoodItem(item);
  }

  Future<FoodItem> editFoodItem(FoodItem item) {
    return _remoteDataSource.updateFoodItem(item);
  }

  Future<void> removeFoodItem(String id) {
    return _remoteDataSource.deleteFoodItem(id);
  }
}
