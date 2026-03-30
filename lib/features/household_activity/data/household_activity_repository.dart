import '../domain/household_activity_event.dart';
import 'household_activity_remote_data_source.dart';

class HouseholdActivityRepository {
  HouseholdActivityRepository({
    required String householdId,
    HouseholdActivityRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ??
           HouseholdActivityRemoteDataSource(householdId: householdId);

  final HouseholdActivityRemoteDataSource _remoteDataSource;

  Future<List<HouseholdActivityEvent>> getRecentEvents() {
    return _remoteDataSource.fetchRecentEvents();
  }

  Future<HouseholdActivityEvent> addEvent(HouseholdActivityEvent event) {
    return _remoteDataSource.createEvent(event);
  }
}
