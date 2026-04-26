import '../domain/household.dart';
import '../domain/household_member.dart';
import 'household_remote_data_source.dart';

class HouseholdRepository {
  HouseholdRepository({HouseholdRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? HouseholdRemoteDataSource();

  final HouseholdRemoteDataSource _remoteDataSource;

  Future<Household?> getPrimaryHousehold() {
    return _remoteDataSource.fetchPrimaryHousehold();
  }

  Future<Household> createHousehold(String name) {
    return _remoteDataSource.createHousehold(name);
  }

  Future<Household> joinHousehold(String householdId) {
    return _remoteDataSource.joinHousehold(householdId);
  }

  Future<Household> updateHouseholdName(String householdId, String name) {
    return _remoteDataSource.updateHouseholdName(householdId, name);
  }

  Future<List<HouseholdMember>> getMembers(String householdId) {
    return _remoteDataSource.fetchMembers(householdId);
  }
}
