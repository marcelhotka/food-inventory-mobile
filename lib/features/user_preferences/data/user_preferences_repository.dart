import '../domain/user_preferences.dart';
import 'user_preferences_remote_data_source.dart';

class UserPreferencesRepository {
  UserPreferencesRepository({UserPreferencesRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? UserPreferencesRemoteDataSource();

  final UserPreferencesRemoteDataSource _remoteDataSource;

  Future<UserPreferences?> getCurrentUserPreferences() {
    return _remoteDataSource.fetchCurrentUserPreferences();
  }

  Future<UserPreferences> savePreferences(UserPreferences preferences) {
    return _remoteDataSource.upsertPreferences(preferences);
  }
}
