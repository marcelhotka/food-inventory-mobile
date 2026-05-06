import 'package:flutter_test/flutter_test.dart';
import 'package:food_inventory_mobile/core/widgets/app_async_state_widgets.dart';

void main() {
  group('inferAppErrorKind', () {
    test('detects connection problems from network errors', () {
      expect(
        inferAppErrorKind(Exception('SocketException: Failed host lookup')),
        AppErrorKind.connection,
      );
    });

    test('detects permission problems from denied access messages', () {
      expect(
        inferAppErrorKind(Exception('Permission denied for photo library')),
        AppErrorKind.permission,
      );
    });

    test('detects setup problems from Supabase config errors', () {
      expect(
        inferAppErrorKind(Exception('Missing Supabase anon key')),
        AppErrorKind.setup,
      );
    });

    test('falls back when error does not match a known kind', () {
      expect(
        inferAppErrorKind(
          Exception('something unrelated'),
          fallback: AppErrorKind.sync,
        ),
        AppErrorKind.sync,
      );
    });
  });
}
