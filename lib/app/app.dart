import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/user_preferences/data/user_preferences_repository.dart';
import 'localization/app_locale.dart';
import 'router.dart';
import 'theme/safo_theme.dart';

class FoodInventoryApp extends StatefulWidget {
  const FoodInventoryApp({super.key});

  @override
  State<FoodInventoryApp> createState() => _FoodInventoryAppState();
}

class _FoodInventoryAppState extends State<FoodInventoryApp> {
  late final AuthRepository _authRepository = AuthRepository();
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();
  final AppLocaleController _localeController = AppLocaleController();

  @override
  void initState() {
    super.initState();
    _loadPreferredLanguage();
  }

  Future<void> _loadPreferredLanguage() async {
    try {
      final preferences = await _userPreferencesRepository
          .getCurrentUserPreferences();
      _localeController.setLocaleCode(preferences?.preferredLanguage);
    } catch (_) {
      _localeController.setLocaleCode(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      controller: _localeController,
      child: AnimatedBuilder(
        animation: _localeController,
        builder: (context, _) {
          return MaterialApp(
            title: 'Safo',
            debugShowCheckedModeBanner: false,
            locale: _localeController.locale,
            supportedLocales: const [Locale('en'), Locale('sk')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: SafoTheme.light(),
            onGenerateRoute: (settings) => AppRouter.onGenerateRoute(
              settings,
              authRepository: _authRepository,
            ),
            initialRoute: AppRouter.home,
          );
        },
      ),
    );
  }
}
