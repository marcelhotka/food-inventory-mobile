import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';

class TesterInfoScreen extends StatelessWidget {
  const TesterInfoScreen({super.key});

  static const _buildLabel = '1.0.0+1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Tester info', sk: 'Tester info')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: context.tr(en: 'Current build', sk: 'Aktuálny build'),
            child: Text(
              context.tr(en: 'Version $_buildLabel', sk: 'Verzia $_buildLabel'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: context.tr(
              en: 'Recommended test flow',
              sk: 'Odporúčaný test',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletText(
                  text: context.tr(
                    en: 'Open Preferences and try the sample tester profile.',
                    sk: 'Otvor Preferencie a skús ukážkový testerský profil.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Add a few Pantry items and test expiring soon, opened items, and low stock.',
                    sk: 'Pridaj pár pantry položiek a vyskúšaj čoskoro sa minie, otvorené položky a málo zásob.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Use Shopping List, mark items as bought, and move them to Pantry.',
                    sk: 'Použi nákupný zoznam, označ položky ako kúpené a presuň ich do špajze.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Try Recipes, serving changes, and add missing ingredients.',
                    sk: 'Skús Recepty, zmenu porcií a pridanie chýbajúcich ingrediencií.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Test Meal plan, Quick command, Notifications, Barcode lookup, and Fridge scan.',
                    sk: 'Otestuj Jedálniček, Rýchly príkaz, Upozornenia, sken kódu a sken chladničky.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: context.tr(en: 'What to watch', sk: 'Na čo sa zamerať'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletText(
                  text: context.tr(
                    en: 'Anything confusing or hard to find.',
                    sk: 'Čokoľvek, čo je mätúce alebo ťažko nájditeľné.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Unexpected duplicate items or quantity issues.',
                    sk: 'Nečakané duplicity položiek alebo problémy s množstvom.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Flows that need too many taps to finish.',
                    sk: 'Flowy, ktoré potrebujú priveľa klikov na dokončenie.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Places where the dashboard feels too dense.',
                    sk: 'Miesta, kde dashboard pôsobí príliš nahusto.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: context.tr(en: 'Best test setup', sk: 'Najlepší test setup'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletText(
                  text: context.tr(
                    en: 'Use Chrome for quick retesting and iPhone build for real-device checks.',
                    sk: 'Na rýchle retesty používaj Chrome a na kontrolu reálneho zariadenia iPhone build.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'If a flow feels slow, note the exact action that caused it.',
                    sk: 'Ak flow pôsobí pomaly, poznač si presne akciu, pri ktorej sa to stalo.',
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

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;

  const _BulletText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('• $text'),
    );
  }
}
