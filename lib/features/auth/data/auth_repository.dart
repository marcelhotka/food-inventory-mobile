import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client}) : _client = client ?? tryGetSupabaseClient();

  final SupabaseClient? _client;

  Stream<AuthState> authStateChanges() {
    final client = _requireClient();
    return client.auth.onAuthStateChange;
  }

  Session? get currentSession {
    return _client?.auth.currentSession;
  }

  Future<void> signInWithMagicLink(String email) async {
    final client = _requireClient();
    await client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: null,
    );
  }

  Future<void> signInAnonymously() async {
    final client = _requireClient();
    await client.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    final client = _requireClient();
    await client.auth.signOut();
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const AuthConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }
}

class AuthConfigException implements Exception {
  final String message;

  const AuthConfigException(this.message);

  @override
  String toString() => message;
}
