import 'package:flutter_test/flutter_test.dart';
import 'package:food_inventory_mobile/app/supabase.dart';

void main() {
  group('isSupabaseSetupError', () {
    test('detects missing env setup messages', () {
      expect(
        isSupabaseSetupError(
          Exception(
            'Safo backend is not configured yet. Copy .env.example to .env and add SUPABASE_URL plus SUPABASE_ANON_KEY.',
          ),
        ),
        isTrue,
      );
    });

    test('detects missing supabase url and key messages', () {
      expect(
        isSupabaseSetupError(Exception('Supabase URL is missing.')),
        isTrue,
      );
      expect(
        isSupabaseSetupError(Exception('Supabase anon key is missing.')),
        isTrue,
      );
    });

    test('returns false for unrelated errors', () {
      expect(
        isSupabaseSetupError(Exception('Network request timed out.')),
        isFalse,
      );
    });
  });

  group('isSignInRequiredError', () {
    test('detects current shared auth-required message', () {
      expect(
        isSignInRequiredError(
          Exception('Sign in to continue with this Safo flow.'),
        ),
        isTrue,
      );
    });

    test('detects legacy localized auth-required message', () {
      expect(isSignInRequiredError(Exception('Musíš byť prihlásený.')), isTrue);
    });

    test('returns false for unrelated messages', () {
      expect(
        isSignInRequiredError(Exception('Something else happened.')),
        isFalse,
      );
    });
  });
}
