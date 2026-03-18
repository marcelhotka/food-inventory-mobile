import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/supabase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const FoodInventoryApp());
}
