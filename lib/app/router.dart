import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/app_async_state_widgets.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/households/data/household_repository.dart';
import '../features/households/domain/household.dart';
import '../features/households/presentation/household_setup_screen.dart';
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
  Future<Household?>? _householdFuture;
  String? _activeUserId;

  Future<void> _loadHousehold() async {
    setState(() {
      _householdFuture = _householdRepository.getPrimaryHousehold();
    });
    await _householdFuture!;
  }

  void _ensureHouseholdFuture(String userId) {
    if (_householdFuture != null && _activeUserId == userId) {
      return;
    }

    _activeUserId = userId;
    _householdFuture = _householdRepository.getPrimaryHousehold();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.authRepository.currentSession == null) {
      try {
        widget.authRepository.authStateChanges();
      } on AuthConfigException catch (error) {
        return _ConfigErrorScreen(message: error.message);
      }
    }

    final currentSession = widget.authRepository.currentSession;
    if (currentSession != null) {
      return _buildForAuthenticatedSession(currentSession.user.id);
    }

    return StreamBuilder<AuthState>(
      stream: widget.authRepository.authStateChanges(),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          return _buildForAuthenticatedSession(session.user.id);
        }

        return AuthScreen(repository: widget.authRepository);
      },
    );
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
            message: 'Failed to load household.',
            onRetry: _loadHousehold,
          );
        }

        final household = snapshot.data;
        if (household == null) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user?.isAnonymous ?? false) {
            return _AnonymousHouseholdBootstrap(
              repository: _householdRepository,
              authRepository: widget.authRepository,
              onCreated: _loadHousehold,
            );
          }

          return HouseholdSetupScreen(
            repository: _householdRepository,
            authRepository: widget.authRepository,
            onCreated: _loadHousehold,
          );
        }

        return HomeShell(
          authRepository: widget.authRepository,
          household: household,
        );
      },
    );
  }
}

class _AnonymousHouseholdBootstrap extends StatefulWidget {
  final HouseholdRepository repository;
  final AuthRepository authRepository;
  final Future<void> Function() onCreated;

  const _AnonymousHouseholdBootstrap({
    required this.repository,
    required this.authRepository,
    required this.onCreated,
  });

  @override
  State<_AnonymousHouseholdBootstrap> createState() =>
      _AnonymousHouseholdBootstrapState();
}

class _AnonymousHouseholdBootstrapState
    extends State<_AnonymousHouseholdBootstrap> {
  late final Future<void> _bootstrapFuture = _bootstrap();

  Future<void> _bootstrap() async {
    await widget.repository.createHousehold('My household');
    await widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Preparing your pantry')),
            body: const Center(child: AppLoadingState()),
          );
        }

        if (snapshot.hasError) {
          return HouseholdSetupScreen(
            repository: widget.repository,
            authRepository: widget.authRepository,
            onCreated: widget.onCreated,
          );
        }

        return const SizedBox.shrink();
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
      appBar: AppBar(title: const Text('Setup needed')),
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
            child: Text(message, textAlign: TextAlign.center),
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
      appBar: AppBar(title: const Text('Page not found')),
      body: const Center(child: Text('Unknown route')),
    );
  }
}
