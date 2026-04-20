import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../data/auth_repository.dart';

enum _AuthFlowStep {
  splash,
  welcome,
  onboardingInventory,
  onboardingExpiry,
  onboardingPlanning,
  account,
}

class AuthScreen extends StatefulWidget {
  final AuthRepository repository;

  const AuthScreen({super.key, required this.repository});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  String? _message;
  _AuthFlowStep _step = _AuthFlowStep.splash;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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

  Future<void> _openForgotPassword() async {
    final dialogController = TextEditingController(text: _emailController.text);
    try {
      final email = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              dialogContext.tr(
                en: 'Reset password',
                sk: 'Obnoviť heslo',
              ),
            ),
            content: TextField(
              controller: dialogController,
              keyboardType: TextInputType.emailAddress,
              decoration: appInputDecoration(
                dialogContext.tr(
                  en: 'Email address',
                  sk: 'E-mailová adresa',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.tr(en: 'Cancel', sk: 'Zrušiť')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(dialogController.text.trim()),
                child: Text(
                  dialogContext.tr(
                    en: 'Send link',
                    sk: 'Poslať odkaz',
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted || email == null || email.isEmpty) {
        return;
      }

      setState(() {
        _isSubmitting = true;
        _message = null;
        _emailController.text = email;
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.toString();
      });
    } finally {
      dialogController.dispose();
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

  void _goBack() {
    switch (_step) {
      case _AuthFlowStep.splash:
        _goTo(_AuthFlowStep.welcome);
      case _AuthFlowStep.welcome:
        break;
      case _AuthFlowStep.onboardingInventory:
        _goTo(_AuthFlowStep.welcome);
      case _AuthFlowStep.onboardingExpiry:
        _goTo(_AuthFlowStep.onboardingInventory);
      case _AuthFlowStep.onboardingPlanning:
        _goTo(_AuthFlowStep.onboardingExpiry);
      case _AuthFlowStep.account:
        _goTo(_AuthFlowStep.welcome);
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
              onContinue: () => _goTo(_AuthFlowStep.welcome),
            ),
            _AuthFlowStep.welcome => _WelcomeStep(
              key: const ValueKey('welcome'),
              onGetStarted: () => _goTo(_AuthFlowStep.onboardingInventory),
              onSignIn: () => _goTo(_AuthFlowStep.account),
            ),
            _AuthFlowStep.onboardingInventory => _OnboardingStep(
              key: const ValueKey('onboarding-1'),
              stepIndex: 0,
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
              onSkip: () => _goTo(_AuthFlowStep.account),
              onNext: () => _goTo(_AuthFlowStep.onboardingExpiry),
            ),
            _AuthFlowStep.onboardingExpiry => _OnboardingStep(
              key: const ValueKey('onboarding-2'),
              stepIndex: 1,
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
              onSkip: () => _goTo(_AuthFlowStep.account),
              onNext: () => _goTo(_AuthFlowStep.onboardingPlanning),
            ),
            _AuthFlowStep.onboardingPlanning => _OnboardingStep(
              key: const ValueKey('onboarding-3'),
              stepIndex: 2,
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
              onSkip: () => _goTo(_AuthFlowStep.account),
              onNext: () => _goTo(_AuthFlowStep.account),
              isLast: true,
            ),
            _AuthFlowStep.account => _AccountStep(
              key: const ValueKey('account'),
              formKey: _formKey,
              emailController: _emailController,
              isSubmitting: _isSubmitting,
              message: _message,
              onBack: _goBack,
              onSubmit: _submit,
              onForgotPassword: _openForgotPassword,
              onContinueWithGoogle: _continueWithGoogle,
              onContinueWithApple: _continueWithApple,
              onContinueAsGuest: _continueAsGuest,
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

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const _WelcomeStep({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    'https://readdy.ai/api/search-image?query=beautiful%20organized%20kitchen%20pantry%20shelves%20with%20jars%20fresh%20vegetables%20herbs%20warm%20natural%20light%20cream%20and%20green%20tones%20minimal%20elegant%20lifestyle%20photography&width=390&height=420&seq=w1&orientation=portrait',
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
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final int stepIndex;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color background;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  const _OnboardingStep({
    super.key,
    required this.stepIndex,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.background,
    required this.onNext,
    required this.onSkip,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
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
    );
  }
}

class _AccountStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isSubmitting;
  final String? message;
  final VoidCallback onBack;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onForgotPassword;
  final Future<void> Function() onContinueWithGoogle;
  final Future<void> Function() onContinueWithApple;
  final Future<void> Function() onContinueAsGuest;

  const _AccountStep({
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
        const SizedBox(height: 28),
        Text(
          context.tr(en: 'Welcome to Safo', sk: 'Vitaj v Safo'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: SafoColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            en: 'Sign in to keep your household, pantry, shopping list, and preferences safely linked to one account.',
            sk: 'Prihlás sa, aby si mal svoju domácnosť, špajzu, nákupný zoznam a preferencie bezpečne prepojené s jedným účtom.',
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: SafoColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
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
                  context.tr(en: 'Continue with email', sk: 'Pokračovať e-mailom'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    en: 'We will send you a magic link so you can safely continue without a password.',
                    sk: 'Pošleme ti magic link, aby si mohol bezpečne pokračovať bez hesla.',
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
                  child: FilledButton.tonal(
                    onPressed: isSubmitting ? null : onSubmit,
                    child: Text(
                      isSubmitting
                          ? context.tr(en: 'Sending...', sk: 'Odosielam...')
                          : context.tr(
                              en: 'Send magic link',
                              sk: 'Poslať magic link',
                            ),
                    ),
                  ),
                ),
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
                      en: 'Email sign-in keeps the same account, household, and data after reopening the app.',
                      sk: 'Prihlásenie e-mailom zachová rovnaký účet, domácnosť a dáta aj po znovuotvorení aplikácie.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SafoColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
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
                            color: const Color(0xFFF3EEE4),
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
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
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    en: 'Guest mode is best for quick testing. You can still go through the full household and onboarding flow.',
                    sk: 'Hosť je najlepší na rýchle testovanie. Stále si vieš prejsť celý household a onboarding flow.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SafoColors.textMuted,
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
        ),
      ],
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
