import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'localization/app_locale.dart';
import 'theme/safo_tokens.dart';
import '../core/widgets/app_async_state_widgets.dart';
import '../core/widgets/safo_page_header.dart';
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
  bool _showKitchenSetupAgain = false;
  bool _showHouseholdSetupAgain = false;
  AuthScreenInitialStep _authInitialStep = AuthScreenInitialStep.splash;

  Future<void> _loadHousehold() async {
    setState(() {
      _showHouseholdSetupAgain = false;
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
    _authInitialStep = AuthScreenInitialStep.splash;
    _householdFuture = _householdRepository.getPrimaryHousehold();
    _preferencesFuture = _userPreferencesRepository.getCurrentUserPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _showKitchenSetupAgain = false;
      _showHouseholdSetupAgain = false;
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
    _showKitchenSetupAgain = false;
    _showHouseholdSetupAgain = false;
  }

  void _returnToKitchenSetup() {
    setState(() {
      _showKitchenSetupAgain = true;
      _showHouseholdSetupAgain = false;
    });
  }

  void _goToHouseholdSetup() {
    setState(() {
      _showKitchenSetupAgain = false;
      _showHouseholdSetupAgain = true;
    });
  }

  Future<void> _returnToSignIn() async {
    setState(() {
      _authInitialStep = AuthScreenInitialStep.account;
    });
    await widget.authRepository.signOut();
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
            return AuthScreen(
              repository: widget.authRepository,
              initialStep: _authInitialStep,
            );
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
            kind: inferAppErrorKind(
              snapshot.error,
              fallback: AppErrorKind.sync,
            ),
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
          if (_showKitchenSetupAgain) {
            return UserPreferencesScreen(
              isOnboarding: true,
              onCompleted: _loadPreferences,
              onBackToSignIn: _returnToSignIn,
              onNextToHouseholdSetup: _goToHouseholdSetup,
            );
          }

          return HouseholdSetupScreen(
            repository: _householdRepository,
            authRepository: widget.authRepository,
            onCreated: _loadHousehold,
            onBackToKitchenSetup: _returnToKitchenSetup,
          );
        }

        if (_showHouseholdSetupAgain) {
          return HouseholdSetupScreen(
            repository: _householdRepository,
            authRepository: widget.authRepository,
            onCreated: _loadHousehold,
            onBackToKitchenSetup: _returnToKitchenSetup,
            editableHousehold: household,
            openCreateByDefault: true,
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
                kind: inferAppErrorKind(
                  preferencesSnapshot.error,
                  fallback: AppErrorKind.sync,
                ),
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
                onBackToSignIn: _returnToSignIn,
                onNextToHouseholdSetup: _goToHouseholdSetup,
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SafoSpacing.md,
            SafoSpacing.sm,
            SafoSpacing.md,
            SafoSpacing.xxl,
          ),
          children: [
            SafoPageHeader(
              title: context.tr(en: 'Setup needed', sk: 'Treba nastavenie'),
              subtitle: context.tr(
                en: 'Safo still needs a small configuration step before it can continue.',
                sk: 'Safo ešte potrebuje malé nastavenie, aby mohlo pokračovať.',
              ),
              dark: false,
              badges: [
                _RouterInfoBadge(
                  icon: Icons.settings_suggest_rounded,
                  label: context.tr(en: 'Environment', sk: 'Prostredie'),
                ),
              ],
            ),
            const SizedBox(height: SafoSpacing.lg),
            Container(
              padding: const EdgeInsets.all(SafoSpacing.lg),
              decoration: BoxDecoration(
                color: SafoColors.surface,
                borderRadius: BorderRadius.circular(SafoRadii.xl),
                border: Border.all(color: SafoColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: SafoColors.primarySoft,
                      borderRadius: BorderRadius.circular(SafoRadii.lg),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: SafoColors.primary,
                    ),
                  ),
                  const SizedBox(height: SafoSpacing.md),
                  Text(
                    context.tr(
                      en: 'Safo needs setup',
                      sk: 'Safo potrebuje nastavenie',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: SafoSpacing.sm),
                  Text(message),
                  const SizedBox(height: SafoSpacing.sm),
                  Text(
                    context.tr(
                      en: 'This usually means environment or integration settings are still missing.',
                      sk: 'Zvyčajne to znamená, že ešte chýbajú nastavenia prostredia alebo integrácie.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SafoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouterInfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RouterInfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SafoSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: SafoColors.surfaceSoft,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
        border: Border.all(color: SafoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: SafoColors.textPrimary),
          const SizedBox(width: SafoSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SafoSpacing.md,
            SafoSpacing.sm,
            SafoSpacing.md,
            SafoSpacing.xxl,
          ),
          children: [
            SafoPageHeader(
              title: context.tr(
                en: 'Page not found',
                sk: 'Stránka sa nenašla',
              ),
              subtitle: context.tr(
                en: 'That part of Safo is not available from this route.',
                sk: 'Táto časť Safo nie je cez túto cestu dostupná.',
              ),
              dark: false,
              onBack: () => Navigator.of(context).maybePop(),
              badges: [
                _RouterInfoBadge(
                  icon: Icons.explore_off_rounded,
                  label: context.tr(en: 'Unknown route', sk: 'Neznáma cesta'),
                ),
              ],
            ),
            const SizedBox(height: SafoSpacing.lg),
            Container(
              padding: const EdgeInsets.all(SafoSpacing.lg),
              decoration: BoxDecoration(
                color: SafoColors.surface,
                borderRadius: BorderRadius.circular(SafoRadii.xl),
                border: Border.all(color: SafoColors.border),
              ),
              child: Text(
                context.tr(
                  en: 'Try going back to the previous screen or return to the main dashboard.',
                  sk: 'Skús sa vrátiť na predchádzajúcu obrazovku alebo späť na hlavný dashboard.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
