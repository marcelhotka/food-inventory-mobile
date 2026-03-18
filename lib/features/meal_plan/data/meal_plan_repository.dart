import '../domain/meal_plan_entry.dart';
import 'meal_plan_remote_data_source.dart';

class MealPlanRepository {
  MealPlanRepository({
    required String householdId,
    MealPlanRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ??
           MealPlanRemoteDataSource(householdId: householdId);

  final MealPlanRemoteDataSource _remoteDataSource;

  Future<List<MealPlanEntry>> getEntries() => _remoteDataSource.fetchEntries();

  Future<MealPlanEntry> addEntry(MealPlanEntry entry) =>
      _remoteDataSource.createEntry(entry);

  Future<MealPlanEntry> editEntry(MealPlanEntry entry) =>
      _remoteDataSource.updateEntry(entry);

  Future<void> removeEntry(String id) => _remoteDataSource.deleteEntry(id);
}
