import '../domain/shopping_list_item.dart';
import 'shopping_list_remote_data_source.dart';

class ShoppingListRepository {
  ShoppingListRepository({
    required String householdId,
    ShoppingListRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ??
           ShoppingListRemoteDataSource(householdId: householdId);

  final ShoppingListRemoteDataSource _remoteDataSource;

  Future<List<ShoppingListItem>> getShoppingListItems() {
    return _remoteDataSource.fetchShoppingListItems();
  }

  Future<ShoppingListItem> addShoppingListItem(ShoppingListItem item) {
    return _remoteDataSource.createShoppingListItem(item);
  }

  Future<ShoppingListItem> editShoppingListItem(ShoppingListItem item) {
    return _remoteDataSource.updateShoppingListItem(item);
  }

  Future<void> removeShoppingListItem(String id) {
    return _remoteDataSource.deleteShoppingListItem(id);
  }
}
