import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/user_preferences/data/user_preferences_repository.dart';
import 'localization/app_locale.dart';
import 'router.dart';

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
    const seed = Color(0xFF5C8A5E);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: const Color(0xFF4E7A51),
      secondary: const Color(0xFFDD8B52),
      surface: const Color(0xFFFFFCF7),
    );

    return AppLocaleScope(
      controller: _localeController,
      child: AnimatedBuilder(
        animation: _localeController,
        builder: (context, _) {
          return MaterialApp(
            title: context.tr(en: 'Food Inventory', sk: 'Správa potravín'),
            debugShowCheckedModeBanner: false,
            locale: _localeController.locale,
            supportedLocales: const [Locale('en'), Locale('sk')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(
              colorScheme: colorScheme,
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF6F1E7),
              appBarTheme: AppBarTheme(
                centerTitle: false,
                backgroundColor: const Color(0xFFF6F1E7),
                foregroundColor: const Color(0xFF203126),
                elevation: 0,
                scrolledUnderElevation: 0,
                titleTextStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF203126),
                ),
              ),
              cardTheme: CardThemeData(
                color: const Color(0xFFFFFCF7),
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Color(0xFFE6DDCF)),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: const Color(0xFFFFFCF7),
                indicatorColor: const Color(0xFFE5F0DF),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF2E5131)
                        : const Color(0xFF617065),
                  );
                }),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFF4E7A51),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4E7A51),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4E7A51),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF203126),
                contentTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
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
