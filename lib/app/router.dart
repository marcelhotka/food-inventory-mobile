import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'localization/app_locale.dart';
import '../core/widgets/app_async_state_widgets.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/households/data/household_repository.dart';
import '../features/households/domain/household.dart';
import '../features/households/presentation/household_setup_screen.dart';
import '../features/user_preferences/data/user_preferences_remote_data_source.dart';
import '../features/user_preferences/data/user_preferences_repository.dart';
import '../features/user_preferences/domain/user_preferences.dart';
import '../features/user_preferences/presentation/user_preferences_screen.dart';
import 'home_shell.dart';

class AppRouter {
  static const home = '/';

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    required AuthRepository authRepository,
  }) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => _RootScreen(authRepository: authRepository),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const _UnknownRouteScreen(),
          settings: settings,
        );
    }
  }
}

class _RootScreen extends StatefulWidget {
  final AuthRepository authRepository;

  const _RootScreen({required this.authRepository});

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  late final HouseholdRepository _householdRepository = HouseholdRepository();
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();
  Future<Household?>? _householdFuture;
  Future<UserPreferences?>? _preferencesFuture;
  String? _activeUserId;

  Future<void> _loadHousehold() async {
    setState(() {
      _householdFuture = _householdRepository.getPrimaryHousehold();
    });
    await _householdFuture!;
  }

  void _ensureHouseholdFuture(String userId) {
    if (_householdFuture != null &&
        _preferencesFuture != null &&
        _activeUserId == userId) {
      return;
    }

    _activeUserId = userId;
    _householdFuture = _householdRepository.getPrimaryHousehold();
    _preferencesFuture = _userPreferencesRepository.getCurrentUserPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _preferencesFuture = _userPreferencesRepository
          .getCurrentUserPreferences();
    });
    await _preferencesFuture!;
  }

  bool _shouldBypassPreferencesGate(Object error) {
    return error is UserPreferencesConfigException;
  }

  void _resetCachedSessionState() {
    _householdFuture = null;
    _preferencesFuture = null;
    _activeUserId = null;
  }

  @override
  Widget build(BuildContext context) {
    try {
      return StreamBuilder<AuthState>(
        stream: widget.authRepository.authStateChanges(),
        builder: (context, snapshot) {
          final session =
              snapshot.data?.session ?? widget.authRepository.currentSession;
          if (session == null) {
            _resetCachedSessionState();
            return AuthScreen(repository: widget.authRepository);
          }

          return _buildForAuthenticatedSession(session.user.id);
        },
      );
    } on AuthConfigException catch (error) {
      return _ConfigErrorScreen(message: error.message);
    }
  }

  Widget _buildForAuthenticatedSession(String userId) {
    _ensureHouseholdFuture(userId);

    return FutureBuilder<Household?>(
      future: _householdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState();
        }

        if (snapshot.hasError) {
          return AppErrorState(
            kind: AppErrorKind.sync,
            title: context.tr(
              en: 'Unable to open your household',
              sk: 'Nepodarilo sa otvoriť tvoju domácnosť',
            ),
            message: context.tr(
              en: 'Failed to load household.',
              sk: 'Nepodarilo sa načítať domácnosť.',
            ),
            onRetry: _loadHousehold,
          );
        }

        final household = snapshot.data;
        if (household == null) {
          return HouseholdSetupScreen(
            repository: _householdRepository,
            authRepository: widget.authRepository,
            onCreated: _loadHousehold,
          );
        }

        return FutureBuilder<UserPreferences?>(
          future: _preferencesFuture,
          builder: (context, preferencesSnapshot) {
            if (preferencesSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const AppLoadingState();
            }

            if (preferencesSnapshot.hasError) {
              final error = preferencesSnapshot.error;
              if (error != null && _shouldBypassPreferencesGate(error)) {
                return HomeShell(
                  authRepository: widget.authRepository,
                  household: household,
                );
              }

              return AppErrorState(
                kind: AppErrorKind.sync,
                title: context.tr(
                  en: 'Unable to open preferences',
                  sk: 'Nepodarilo sa otvoriť preferencie',
                ),
                message: context.tr(
                  en: 'Failed to load preferences.',
                  sk: 'Nepodarilo sa načítať preferencie.',
                ),
                onRetry: _loadPreferences,
              );
            }

            final preferences = preferencesSnapshot.data;
            if (preferences == null || !preferences.onboardingCompleted) {
              return UserPreferencesScreen(
                isOnboarding: true,
                onCompleted: _loadPreferences,
              );
            }

            return HomeShell(
              authRepository: widget.authRepository,
              household: household,
            );
          },
        );
      },
    );
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  final String message;

  const _ConfigErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Setup needed', sk: 'Treba nastavenie')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE6DDCF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.settings_suggest_rounded,
                  size: 40,
                  color: Color(0xFF4C6FFF),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    en: 'Safo needs setup',
                    sk: 'Safo potrebuje nastavenie',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    en: 'This usually means environment or integration settings are still missing.',
                    sk: 'Zvyčajne to znamená, že ešte chýbajú nastavenia prostredia alebo integrácie.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Page not found', sk: 'Stránka sa nenašla')),
      ),
      body: Center(
        child: Text(context.tr(en: 'Unknown route', sk: 'Neznáma stránka')),
      ),
    );
  }
}
