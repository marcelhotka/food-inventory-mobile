import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const safoSupabaseSetupMessage =
    'Safo is not configured yet. Copy .env.example to .env and add SUPABASE_URL plus SUPABASE_ANON_KEY before testing this flow.';
const safoSupabaseSetupLogMessage =
    'Safo backend is not configured yet. Copy .env.example to .env and add SUPABASE_URL plus SUPABASE_ANON_KEY.';
const safoSignInRequiredMessage = 'Sign in to continue with this Safo flow.';
const safoLegacySignInRequiredMessage = 'Musíš byť prihlásený.';

Future<void> bootstrapSupabase() async {
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint(safoSupabaseSetupLogMessage);
    return;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}

SupabaseClient? tryGetSupabaseClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

bool isSignInRequiredError(Object? error) {
  if (error == null) {
    return false;
  }

  final message = error.toString().trim();
  return message.contains(safoSignInRequiredMessage) ||
      message.contains(safoLegacySignInRequiredMessage);
}
