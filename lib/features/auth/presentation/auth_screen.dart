import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/safo_logo.dart';
import '../data/auth_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE9F1E5), Color(0xFFF6E2CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFE2D7C6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SafoLogo(
                    variant: SafoLogoVariant.iconTransparent,
                    width: 56,
                    height: 56,
                  ),
                  const SizedBox(height: 18),
                  const SafoLogo(
                    variant: SafoLogoVariant.horizontalLight,
                    height: 52,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      en: 'Your kitchen assistant,\nwithout the chaos.',
                      sk: 'Tvoj kuchynský asistent,\nbez chaosu.',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      en: 'Safo helps you know what you have at home, what to use soon, what to cook today, and what to buy next.',
                      sk: 'Safo ti pomáha vedieť, čo máš doma, čo treba čoskoro minúť, čo sa oplatí dnes navariť a čo treba kúpiť.',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF4B5A4D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE6DDCF)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(en: 'Get started', sk: 'Začni'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        en: 'Sign in to keep your Safo household, pantry, shopping list, and preferences safely linked to one account.',
                        sk: 'Prihlás sa, aby si mal svoju domácnosť v Safo, špajzu, nákupný zoznam a preferencie bezpečne prepojené s jedným účtom.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: appInputDecoration(
                        context.tr(en: 'Email', sk: 'E-mail'),
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
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(
                          _isSubmitting
                              ? context.tr(en: 'Sending...', sk: 'Odosielam...')
                              : context.tr(
                                  en: 'Continue with email',
                                  sk: 'Pokračovať e-mailom',
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
                          en: 'Email sign-in keeps the same account, household, and data after refresh or reopening the app.',
                          sk: 'Prihlásenie e-mailom zachová rovnaký účet, domácnosť a dáta aj po obnovení alebo znovuotvorení aplikácie.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        context.tr(
                          en: 'or use guest mode',
                          sk: 'alebo použi režim hosťa',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _continueAsGuest,
                        child: Text(
                          _isSubmitting
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
                        en: 'Guest is best for quick testing. It may not preserve your identity as reliably as email sign-in.',
                        sk: 'Hosť je najlepší na rýchle testovanie. Nemusí zachovať tvoju identitu tak spoľahlivo ako prihlásenie e-mailom.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF617065),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EEE4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(_message!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
