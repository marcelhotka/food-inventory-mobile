import 'package:flutter/material.dart';

class AppLocaleController extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocaleCode(String? code) {
    final nextLocale = Locale(switch (code?.trim().toLowerCase()) {
      'sk' => 'sk',
      _ => 'en',
    });

    if (_locale == nextLocale) {
      return;
    }

    _locale = nextLocale;
    notifyListeners();
  }
}

class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope not found in widget tree.');
    return scope!.notifier!;
  }
}

extension AppLocaleBuildContext on BuildContext {
  AppLocaleController get localeController => AppLocaleScope.of(this);

  bool get isSlovak => localeController.locale.languageCode == 'sk';

  String tr({required String en, required String sk}) {
    return isSlovak ? sk : en;
  }
}
