import '../domain/staple_food.dart';
import 'staple_food_remote_data_source.dart';

class StapleFoodRepository {
  StapleFoodRepository({
    required String householdId,
    StapleFoodRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ??
           StapleFoodRemoteDataSource(householdId: householdId);

  final StapleFoodRemoteDataSource _remoteDataSource;

  Future<List<StapleFood>> getStapleFoods() {
    return _remoteDataSource.fetchStapleFoods();
  }

  Future<StapleFood> addStapleFood(StapleFood item) {
    return _remoteDataSource.createStapleFood(item);
  }

  Future<StapleFood> editStapleFood(StapleFood item) {
    return _remoteDataSource.updateStapleFood(item);
  }

  Future<void> removeStapleFood(String id) {
    return _remoteDataSource.deleteStapleFood(id);
  }
}
