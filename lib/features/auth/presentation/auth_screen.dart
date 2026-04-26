import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../data/auth_repository.dart';

enum _AuthFlowStep {
  splash,
  onboardingSummary,
  welcome,
  onboardingInventory,
  onboardingExpiry,
  onboardingPlanning,
  signIn,
  register,
  forgotPassword,
}

enum AuthScreenInitialStep { splash, welcome, account }

class AuthScreen extends StatefulWidget {
  final AuthRepository repository;
  final AuthScreenInitialStep initialStep;

  const AuthScreen({
    super.key,
    required this.repository,
    this.initialStep = AuthScreenInitialStep.splash,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _welcomeImageUrl =
      'https://readdy.ai/api/search-image?query=beautiful%20organized%20kitchen%20pantry%20shelves%20with%20jars%20fresh%20vegetables%20herbs%20warm%20natural%20light%20cream%20and%20green%20tones%20minimal%20elegant%20lifestyle%20photography&width=390&height=420&seq=w1&orientation=portrait';
  static const _onboardingInventoryImageUrl =
      'https://readdy.ai/api/search-image?query=kitchen%20pantry%20shelves%20organized%20food%20jars%20cans%20vegetables%20fresh%20produce%20warm%20overhead%20light%20minimal%20clean%20home%20organization%20aesthetic&width=320&height=320&seq=ob1&orientation=squarish';
  static const _onboardingExpiryImageUrl =
      'https://readdy.ai/api/search-image?query=fresh%20food%20expiration%20dates%20close%20up%20yogurt%20milk%20vegetables%20on%20kitchen%20counter%20warm%20soft%20lighting%20minimal%20clean%20food%20photography&width=320&height=320&seq=ob2&orientation=squarish';
  static const _onboardingPlanningImageUrl =
      'https://readdy.ai/api/search-image?query=shopping%20list%20notebook%20pen%20recipes%20meal%20planning%20calendar%20flat%20lay%20kitchen%20table%20natural%20light%20earthy%20minimal%20aesthetic%20food%20lifestyle&width=320&height=320&seq=ob3&orientation=squarish';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  String? _message;
  late _AuthFlowStep _step;
  late _AuthFlowStep _registerBackStep;
  bool _didPrecacheImages = false;

  @override
  void initState() {
    super.initState();
    _step = switch (widget.initialStep) {
      AuthScreenInitialStep.splash => _AuthFlowStep.splash,
      AuthScreenInitialStep.welcome => _AuthFlowStep.welcome,
      AuthScreenInitialStep.account => _AuthFlowStep.signIn,
    };
    _registerBackStep = _AuthFlowStep.onboardingPlanning;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheImages) {
      return;
    }
    _didPrecacheImages = true;
    for (final imageUrl in const [
      _welcomeImageUrl,
      _onboardingInventoryImageUrl,
      _onboardingExpiryImageUrl,
      _onboardingPlanningImageUrl,
    ]) {
      precacheImage(NetworkImage(imageUrl), context);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      await widget.repository.signInWithMagicLink(_emailController.text.trim());
      setState(() {
        _message = context.tr(
          en: 'Check your email for the sign-in link.',
          sk: 'Skontroluj si e-mail pre prihlasovací odkaz.',
        );
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      await widget.repository.signInAnonymously();
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      final launched = await widget.repository.signInWithGoogle();
      if (!launched) {
        setState(() {
          _message = context.tr(
            en: 'Google sign-in could not open right now.',
            sk: 'Google prihlásenie sa teraz nepodarilo otvoriť.',
          );
        });
      }
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _continueWithApple() async {
    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      final launched = await widget.repository.signInWithApple();
      if (!launched) {
        setState(() {
          _message = context.tr(
            en: 'Apple sign-in could not open right now.',
            sk: 'Apple prihlásenie sa teraz nepodarilo otvoriť.',
          );
        });
      }
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _message = context.tr(
          en: 'Enter a valid email first.',
          sk: 'Najprv zadaj platný e-mail.',
        );
      });
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _message = null;
      });

      await widget.repository.sendPasswordResetEmail(email);
      if (!mounted) {
        return;
      }
      showSuccessFeedback(
        context,
        context.tr(
          en: 'If this account uses password sign-in, a reset link is on the way.',
          sk: 'Ak tento účet používa heslo, odkaz na reset je na ceste.',
        ),
      );
      _goTo(_AuthFlowStep.signIn);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _goTo(_AuthFlowStep step) {
    setState(() {
      _step = step;
      _message = null;
    });
  }

  void _goToRegister({required _AuthFlowStep backStep}) {
    setState(() {
      _registerBackStep = backStep;
      _step = _AuthFlowStep.register;
      _message = null;
    });
  }

  void _goBack() {
    switch (_step) {
      case _AuthFlowStep.splash:
        break;
      case _AuthFlowStep.onboardingSummary:
        _goTo(_AuthFlowStep.splash);
      case _AuthFlowStep.welcome:
        _goTo(_AuthFlowStep.onboardingSummary);
      case _AuthFlowStep.onboardingInventory:
        _goTo(_AuthFlowStep.welcome);
      case _AuthFlowStep.onboardingExpiry:
        _goTo(_AuthFlowStep.onboardingInventory);
      case _AuthFlowStep.onboardingPlanning:
        _goTo(_AuthFlowStep.onboardingExpiry);
      case _AuthFlowStep.signIn:
        _goTo(_AuthFlowStep.welcome);
      case _AuthFlowStep.register:
        _goTo(_registerBackStep);
      case _AuthFlowStep.forgotPassword:
        _goTo(_AuthFlowStep.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SafoColors.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: switch (_step) {
            _AuthFlowStep.splash => _SplashStep(
              key: const ValueKey('splash'),
              onContinue: () => _goTo(_AuthFlowStep.onboardingSummary),
            ),
            _AuthFlowStep.onboardingSummary => _AuthOnboardingSummaryStep(
              key: const ValueKey('onboarding-summary'),
              onContinue: () => _goTo(_AuthFlowStep.welcome),
              onBack: () => _goTo(_AuthFlowStep.splash),
            ),
            _AuthFlowStep.welcome => _WelcomeStep(
              key: const ValueKey('welcome'),
              imageUrl: _welcomeImageUrl,
              onGetStarted: () => _goTo(_AuthFlowStep.onboardingInventory),
              onGoBack: () => _goTo(_AuthFlowStep.splash),
              onSignIn: () => _goTo(_AuthFlowStep.signIn),
            ),
            _AuthFlowStep.onboardingInventory => _OnboardingStep(
              key: const ValueKey('onboarding-1'),
              stepIndex: 0,
              imageUrl: _onboardingInventoryImageUrl,
              title: context.tr(
                en: 'Track everything at home',
                sk: 'Maj prehľad o všetkom doma',
              ),
              subtitle: context.tr(
                en: 'See pantry items, quantities, and categories in one calm place.',
                sk: 'Vidíš potraviny, množstvá aj kategórie na jednom prehľadnom mieste.',
              ),
              icon: Icons.inventory_2_outlined,
              accent: SafoColors.primary,
              background: const Color(0xFFE8F7EE),
              onSkip: () => _goToRegister(
                backStep: _AuthFlowStep.onboardingInventory,
              ),
              onBack: () => _goTo(_AuthFlowStep.welcome),
              onNext: () => _goTo(_AuthFlowStep.onboardingExpiry),
            ),
            _AuthFlowStep.onboardingExpiry => _OnboardingStep(
              key: const ValueKey('onboarding-2'),
              stepIndex: 1,
              imageUrl: _onboardingExpiryImageUrl,
              title: context.tr(
                en: 'Waste less food',
                sk: 'Vyhadzuj menej potravín',
              ),
              subtitle: context.tr(
                en: 'Safo highlights items that expire soon and warns you about open products or low stock.',
                sk: 'Safo zvýrazní položky pred expiráciou a upozorní ťa na otvorené produkty aj low stock.',
              ),
              icon: Icons.timer_outlined,
              accent: SafoColors.danger,
              background: const Color(0xFFFFF0EB),
              onSkip: () => _goToRegister(
                backStep: _AuthFlowStep.onboardingExpiry,
              ),
              onBack: () => _goTo(_AuthFlowStep.onboardingInventory),
              onNext: () => _goTo(_AuthFlowStep.onboardingPlanning),
            ),
            _AuthFlowStep.onboardingPlanning => _OnboardingStep(
              key: const ValueKey('onboarding-3'),
              stepIndex: 2,
              imageUrl: _onboardingPlanningImageUrl,
              title: context.tr(
                en: 'Plan and shop smarter',
                sk: 'Plánuj a nakupuj múdrejšie',
              ),
              subtitle: context.tr(
                en: 'Build shopping lists, discover recipes from what you have, and coordinate the whole household.',
                sk: 'Vytváraj nákupné zoznamy, objav recepty z toho čo máš doma a koordinuj celú domácnosť.',
              ),
              icon: Icons.calendar_month_outlined,
              accent: SafoColors.accent,
              background: const Color(0xFFEEF0FF),
              onSkip: () => _goToRegister(
                backStep: _AuthFlowStep.onboardingPlanning,
              ),
              onBack: () => _goTo(_AuthFlowStep.onboardingExpiry),
              onNext: () => _goToRegister(
                backStep: _AuthFlowStep.onboardingPlanning,
              ),
              isLast: true,
            ),
            _AuthFlowStep.signIn => _AuthEntryStep(
              key: const ValueKey('sign-in'),
              formKey: _formKey,
              emailController: _emailController,
              isSubmitting: _isSubmitting,
              message: _message,
              onBack: _goBack,
              onSubmit: _submit,
              onForgotPassword: () => _goTo(_AuthFlowStep.forgotPassword),
              onContinueWithGoogle: _continueWithGoogle,
              onContinueWithApple: _continueWithApple,
              onContinueAsGuest: _continueAsGuest,
              mode: _AuthEntryMode.signIn,
              onSwitchMode: () => _goToRegister(backStep: _AuthFlowStep.signIn),
            ),
            _AuthFlowStep.register => _AuthEntryStep(
              key: const ValueKey('register'),
              formKey: _formKey,
              emailController: _emailController,
              isSubmitting: _isSubmitting,
              message: _message,
              onBack: _goBack,
              onSubmit: _submit,
              onForgotPassword: () => _goTo(_AuthFlowStep.forgotPassword),
              onContinueWithGoogle: _continueWithGoogle,
              onContinueWithApple: _continueWithApple,
              onContinueAsGuest: _continueAsGuest,
              mode: _AuthEntryMode.register,
              onSwitchMode: () => _goTo(_AuthFlowStep.signIn),
            ),
            _AuthFlowStep.forgotPassword => _ForgotPasswordStep(
              key: const ValueKey('forgot-password'),
              emailController: _emailController,
              isSubmitting: _isSubmitting,
              message: _message,
              onBack: _goBack,
              onSubmit: _sendPasswordReset,
            ),
          },
        ),
      ),
    );
  }
}

class _SplashStep extends StatelessWidget {
  final VoidCallback onContinue;

  const _SplashStep({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SafoColors.textPrimary,
      child: InkWell(
        onTap: onContinue,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SafoLogo(
                    variant: SafoLogoVariant.icon,
                    width: 96,
                    height: 96,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'SAFO',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SMART & FRESH ORGANIZER',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 84,
              child: Column(
                children: [
                  Text(
                    context.tr(
                      en: 'Eat safe. Waste less. Live more.',
                      sk: 'Jedz bezpečne. Plytvaj menej. Ži viac.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFA8E6C1),
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == 1 ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: index == 1 ? 1 : 0.3,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Text(
                context.tr(
                  en: 'Tap to continue',
                  sk: 'Ťukni pre pokračovanie',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthOnboardingSummaryStep extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const _AuthOnboardingSummaryStep({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -180) {
          onContinue();
        } else if (velocity > 180) {
          onBack();
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Row(
            children: [
              SafoLogo(
                variant: SafoLogoVariant.iconTransparent,
                width: 28,
                height: 28,
              ),
              SizedBox(width: 10),
              SafoLogo(
                variant: SafoLogoVariant.pill,
                height: 28,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: SafoColors.border),
            ),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.12,
                  child: Image.asset(
                    'assets/branding/create-household-hero.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.02),
                          const Color(0xFFF7F3EB).withValues(alpha: 0.18),
                          SafoColors.background.withValues(alpha: 0.84),
                          SafoColors.background,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.36, 0.78, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          en: 'Everything in one shared kitchen flow',
                          sk: 'Všetko v jednom spoločnom kuchynskom flowe',
                        ),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr(
                          en: 'Safo connects pantry, shopping, recipes, and household routines into one calmer daily rhythm.',
                          sk: 'Safo prepája špajzu, nákupy, recepty a chod domácnosti do jedného pokojnejšieho denného rytmu.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SafoColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AuthSummaryCard(
            title: context.tr(
              en: 'What you’ll get',
              sk: 'Čo získaš',
            ),
            items: [
              context.tr(
                en: 'A clear place for pantry, shopping, and recipes',
                sk: 'Jedno jasné miesto pre špajzu, nákupy a recepty',
              ),
              context.tr(
                en: 'Smarter suggestions based on your kitchen and household',
                sk: 'Múdrejšie odporúčania podľa tvojej kuchyne a domácnosti',
              ),
              context.tr(
                en: 'A smoother setup before you start testing the app',
                sk: 'Plynulejšie nastavenie ešte pred testovaním aplikácie',
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: Text(
                context.tr(
                  en: 'Continue',
                  sk: 'Pokračovať',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthSummaryCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _AuthSummaryCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SafoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: SafoColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SafoColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onGetStarted;
  final VoidCallback onGoBack;
  final VoidCallback onSignIn;

  const _WelcomeStep({
    super.key,
    required this.imageUrl,
    required this.onGetStarted,
    required this.onGoBack,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -180) {
          onGetStarted();
        } else if ((details.primaryVelocity ?? 0) > 180) {
          onGoBack();
        }
      },
      child: Column(
      children: [
        Expanded(
          flex: 11,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(34),
              bottomRight: Radius.circular(34),
            ),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDDEBDD), Color(0xFFF0E3D2), Color(0xFFF6F2EA)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const SizedBox.shrink();
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF7F3EB).withValues(alpha: 0.12),
                          const Color(0xFFF7F3EB).withValues(alpha: 0.22),
                          SafoColors.background.withValues(alpha: 0.82),
                          SafoColors.background,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.35, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -18,
                  left: -24,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 54,
                  right: -30,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F1D9).withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 160,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            SafoColors.background.withValues(alpha: 0),
                            SafoColors.background.withValues(alpha: 0.42),
                            SafoColors.background,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
        Expanded(
          flex: 9,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    en: 'Less waste.\nLess stress.\nMore control.',
                    sk: 'Menej odpadu.\nMenej stresu.\nViac kontroly.',
                  ),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: SafoColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 0.98,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr(
                    en: 'Track your pantry, plan meals, and manage your household shopping all in one place.',
                    sk: 'Sleduj špajzu, plánuj jedlá a spravuj nákup domácnosti na jednom mieste.',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SafoColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    en: 'Eat safe. Waste less. Live more.',
                    sk: 'Jedz bezpečne. Plytvaj menej. Ži viac.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.primary,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onGetStarted,
                    child: Text(context.tr(en: 'Get Started', sk: 'Začať')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSignIn,
                    child: Text(context.tr(en: 'Sign In', sk: 'Prihlásiť sa')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final int stepIndex;
  final String? imageUrl;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color background;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final bool isLast;

  const _OnboardingStep({
    super.key,
    required this.stepIndex,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.background,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -180) {
          onNext();
        } else if ((details.primaryVelocity ?? 0) > 180) {
          onBack();
        }
      },
      child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSkip,
              child: Text(context.tr(en: 'Skip', sk: 'Preskočiť')),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 276,
                  height: 276,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: SafoColors.border),
                  ),
                  child: Stack(
                    children: [
                      if (imageUrl != null)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: background,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      icon,
                                      size: 116,
                                      color: accent,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: background,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      icon,
                                      size: 116,
                                      color: accent,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Center(
                            child: Icon(
                              icon,
                              size: 116,
                              color: accent,
                            ),
                          ),
                        ),
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.22),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == stepIndex ? 26 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == stepIndex ? SafoColors.primary : SafoColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: SafoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SafoColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: Text(
                isLast
                    ? context.tr(en: 'Get Started', sk: 'Začať')
                    : context.tr(en: 'Continue', sk: 'Pokračovať'),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

enum _AuthEntryMode { signIn, register }

class _AuthEntryStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isSubmitting;
  final String? message;
  final VoidCallback onBack;
  final Future<void> Function() onSubmit;
  final VoidCallback onForgotPassword;
  final Future<void> Function() onContinueWithGoogle;
  final Future<void> Function() onContinueWithApple;
  final Future<void> Function() onContinueAsGuest;
  final _AuthEntryMode mode;
  final VoidCallback onSwitchMode;

  const _AuthEntryStep({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.isSubmitting,
    required this.message,
    required this.onBack,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onContinueWithGoogle,
    required this.onContinueWithApple,
    required this.onContinueAsGuest,
    required this.mode,
    required this.onSwitchMode,
  });

  bool get _isRegister => mode == _AuthEntryMode.register;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Row(
          children: [
            _HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
            const Spacer(),
            const SafoLogo(
              variant: SafoLogoVariant.pill,
              height: 28,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _AccountHeroCard(
          title: _isRegister
              ? context.tr(
                  en: 'Create your Safo account',
                  sk: 'Vytvor si Safo účet',
                )
              : context.tr(en: 'Welcome to Safo', sk: 'Vitaj v Safo'),
          subtitle: context.tr(
            en: _isRegister
                ? 'Create an account to save your household, pantry, shopping list, and preferences in one place.'
                : 'Sign in to keep your household, pantry, shopping list, and preferences safely linked to one account.',
            sk: _isRegister
                ? 'Vytvor si účet a ulož si domácnosť, špajzu, nákupný zoznam aj preferencie na jednom mieste.'
                : 'Prihlás sa, aby si mal svoju domácnosť, špajzu, nákupný zoznam a preferencie bezpečne prepojené s jedným účtom.',
          ),
        ),
        const SizedBox(height: 18),
        _AccountSummaryCard(
          title: _isRegister
              ? context.tr(
                  en: 'Why create an account',
                  sk: 'Prečo si vytvoriť účet',
                )
              : context.tr(
                  en: 'Why sign in now',
                  sk: 'Prečo sa prihlásiť teraz',
                ),
          items: _isRegister
              ? [
                  context.tr(
                    en: 'Your household setup stays saved after the first launch',
                    sk: 'Nastavenie domácnosti ostane uložené aj po prvom spustení',
                  ),
                  context.tr(
                    en: 'Recipes, pantry, and shopping suggestions can stay personal',
                    sk: 'Recepty, špajza aj nákupné odporúčania môžu zostať osobné',
                  ),
                ]
              : [
                  context.tr(
                    en: 'Your household and pantry stay linked after reopening the app',
                    sk: 'Domácnosť a špajza ostanú prepojené aj po znovuotvorení aplikácie',
                  ),
                  context.tr(
                    en: 'Shopping lists and preferences stay attached to one account',
                    sk: 'Nákupné zoznamy a preferencie ostanú naviazané na jeden účet',
                  ),
                ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: SafoColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: SafoColors.border),
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRegister
                      ? context.tr(
                          en: 'Create account with email',
                          sk: 'Vytvoriť účet e-mailom',
                        )
                      : context.tr(
                          en: 'Continue with email',
                          sk: 'Pokračovať e-mailom',
                        ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    en: _isRegister
                        ? 'We will send you a magic link so you can create your account without remembering a password.'
                        : 'We will send you a magic link so you can safely continue without a password.',
                    sk: _isRegister
                        ? 'Pošleme ti magic link, aby si si mohol vytvoriť účet bez potreby pamätať si heslo.'
                        : 'Pošleme ti magic link, aby si mohol bezpečne pokračovať bez hesla.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: appInputDecoration(
                    context.tr(en: 'Email address', sk: 'E-mailová adresa'),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return context.tr(
                        en: 'Enter your email',
                        sk: 'Zadaj svoj e-mail',
                      );
                    }
                    if (!email.contains('@')) {
                      return context.tr(
                        en: 'Enter a valid email',
                        sk: 'Zadaj platný e-mail',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSubmitting ? null : onSubmit,
                    child: Text(
                      isSubmitting
                          ? context.tr(en: 'Sending...', sk: 'Odosielam...')
                          : _isRegister
                          ? context.tr(
                              en: 'Create account',
                              sk: 'Vytvoriť účet',
                            )
                          : context.tr(
                              en: 'Send magic link',
                              sk: 'Poslať magic link',
                            ),
                    ),
                  ),
                ),
                if (!_isRegister) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isSubmitting ? null : onForgotPassword,
                      child: Text(
                        context.tr(
                          en: 'Forgot password?',
                          sk: 'Zabudnuté heslo?',
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEE4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    context.tr(
                      en: _isRegister
                          ? 'Creating an account now makes it easier to keep your household, planning, and pantry synced later.'
                          : 'Email sign-in keeps the same account, household, and data after reopening the app.',
                      sk: _isRegister
                          ? 'Vytvorenie účtu teraz uľahčí, aby ti domácnosť, plánovanie a špajza ostali synchronizované aj neskôr.'
                          : 'Prihlásenie e-mailom zachová rovnaký účet, domácnosť a dáta aj po znovuotvorení aplikácie.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SafoColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Divider(color: SafoColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        context.tr(
                          en: 'or continue with',
                          sk: 'alebo pokračuj cez',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SafoColors.textSecondary,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: SafoColors.border)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SocialSignInButton(
                        label: 'Google',
                        onTap: isSubmitting ? null : onContinueWithGoogle,
                        leading: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: SafoColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialSignInButton(
                        label: 'Apple',
                        onTap: isSubmitting ? null : onContinueWithApple,
                        leading: const Icon(
                          Icons.apple_rounded,
                          color: SafoColors.textPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SwitchAuthModeCard(
                  prompt: _isRegister
                      ? context.tr(
                          en: 'Already have an account?',
                          sk: 'Už máš účet?',
                        )
                      : context.tr(
                          en: 'New to Safo?',
                          sk: 'Si v Safo nový?',
                        ),
                  actionLabel: _isRegister
                      ? context.tr(en: 'Sign in', sk: 'Prihlásiť sa')
                      : context.tr(en: 'Create account', sk: 'Vytvoriť účet'),
                  onTap: onSwitchMode,
                ),
                if (!_isRegister) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EB),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: SafoColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            en: 'Just testing?',
                            sk: 'Len testuješ?',
                          ),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            en: 'Guest mode is best for quick testing. You can still go through the full household and onboarding flow.',
                            sk: 'Hosť je najlepší na rýchle testovanie. Stále si vieš prejsť celý household a onboarding flow.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SafoColors.textMuted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : onContinueAsGuest,
                            child: Text(
                              isSubmitting
                                  ? context.tr(
                                      en: 'Please wait...',
                                      sk: 'Počkaj chvíľu...',
                                    )
                                  : context.tr(
                                      en: 'Continue as guest',
                                      sk: 'Pokračovať ako hosť',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEE4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SafoColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchAuthModeCard extends StatelessWidget {
  final String prompt;
  final String actionLabel;
  final VoidCallback onTap;

  const _SwitchAuthModeCard({
    required this.prompt,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SafoColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              prompt,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SafoColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordStep extends StatelessWidget {
  final TextEditingController emailController;
  final bool isSubmitting;
  final String? message;
  final VoidCallback onBack;
  final Future<void> Function() onSubmit;

  const _ForgotPasswordStep({
    super.key,
    required this.emailController,
    required this.isSubmitting,
    required this.message,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Row(
          children: [
            _HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
            const Spacer(),
            const SafoLogo(
              variant: SafoLogoVariant.pill,
              height: 28,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _AccountHeroCard(
          title: context.tr(
            en: 'Reset your password',
            sk: 'Obnov si heslo',
          ),
          subtitle: context.tr(
            en: 'Enter the email connected to your Safo account and we’ll send you a reset link.',
            sk: 'Zadaj e-mail pripojený k tvojmu Safo účtu a pošleme ti odkaz na obnovu hesla.',
          ),
        ),
        const SizedBox(height: 18),
        _AccountSummaryCard(
          title: context.tr(
            en: 'What happens next',
            sk: 'Čo sa stane ďalej',
          ),
          items: [
            context.tr(
              en: 'We send a reset link to your email',
              sk: 'Na tvoj e-mail pošleme odkaz na obnovu',
            ),
            context.tr(
              en: 'You return to Safo and continue with the same account',
              sk: 'Vrátiš sa do Safo a pokračuješ s tým istým účtom',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: SafoColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: SafoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  en: 'Account email',
                  sk: 'E-mail účtu',
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  en: 'Use the same email you use for signing in.',
                  sk: 'Použi ten istý e-mail, ktorým sa prihlasuješ.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SafoColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: appInputDecoration(
                  context.tr(en: 'Email address', sk: 'E-mailová adresa'),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  child: Text(
                    isSubmitting
                        ? context.tr(en: 'Sending...', sk: 'Odosielam...')
                        : context.tr(
                            en: 'Send reset link',
                            sk: 'Poslať odkaz na obnovu',
                          ),
                  ),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEE4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SafoColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AccountHeroCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SafoColors.border),
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F1D9), Color(0xFFF1E7D7), Color(0xFFFAF8F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -18,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    color: SafoColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: SafoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SafoColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _AccountSummaryCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SafoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: SafoColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SafoColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialSignInButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback? onTap;

  const _SocialSignInButton({
    required this.label,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SafoColors.surface,
      borderRadius: BorderRadius.circular(SafoRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SafoColors.surface,
            borderRadius: BorderRadius.circular(SafoRadii.pill),
            border: Border.all(color: SafoColors.border),
          ),
          child: Icon(icon, color: SafoColors.textPrimary),
        ),
      ),
    );
  }
}
