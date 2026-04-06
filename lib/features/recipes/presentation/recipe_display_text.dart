import 'package:flutter/widgets.dart';

import '../../../app/localization/app_locale.dart';
import '../domain/recipe.dart';

String localizedRecipeName(BuildContext context, Recipe recipe) {
  return switch (recipe.id) {
    'omelette' => context.tr(en: 'Cheese Omelette', sk: 'Syrová omeleta'),
    'pasta' => context.tr(
      en: 'Tomato Pasta',
      sk: 'Cestoviny s paradajkovou omáčkou',
    ),
    'rice_bowl' => context.tr(
      en: 'Chicken Rice Bowl',
      sk: 'Kuracie ryžové bowl',
    ),
    'sandwich' => context.tr(en: 'Ham Sandwich', sk: 'Šunkový sendvič'),
    _ => recipe.name,
  };
}

String localizedRecipeDescription(BuildContext context, Recipe recipe) {
  return switch (recipe.id) {
    'omelette' => context.tr(
      en: 'Quick breakfast from fridge basics.',
      sk: 'Rýchle raňajky zo základných surovín z chladničky.',
    ),
    'pasta' => context.tr(
      en: 'Simple pantry dinner with just a few ingredients.',
      sk: 'Jednoduchá večera zo špajze len z pár surovín.',
    ),
    'rice_bowl' => context.tr(
      en: 'Easy lunch that works well with shared pantry stock.',
      sk: 'Jednoduchý obed, ktorý dobre funguje so spoločnými zásobami domácnosti.',
    ),
    'sandwich' => context.tr(
      en: 'Fast meal for busy evenings.',
      sk: 'Rýchle jedlo na rušné večery.',
    ),
    _ => recipe.description,
  };
}

String localizedIngredientName(
  BuildContext context,
  String canonicalKey,
  String fallback,
) {
  return switch (canonicalKey) {
    'eggs' => context.tr(en: 'Eggs', sk: 'Vajcia'),
    'milk' => context.tr(en: 'Milk', sk: 'Mlieko'),
    'cheese' => context.tr(en: 'Cheese', sk: 'Syr'),
    'carrots' => context.tr(en: 'Carrots', sk: 'Mrkva'),
    'pasta' => context.tr(en: 'Pasta', sk: 'Cestoviny'),
    'tomatosauce' => context.tr(en: 'Tomato sauce', sk: 'Paradajková omáčka'),
    'chicken' => context.tr(en: 'Chicken', sk: 'Kuracie mäso'),
    'rice' => context.tr(en: 'Rice', sk: 'Ryža'),
    'onion' => context.tr(en: 'Onion', sk: 'Cibuľa'),
    'bread' => context.tr(en: 'Bread', sk: 'Chlieb'),
    'ham' => context.tr(en: 'Ham', sk: 'Šunka'),
    _ => fallback,
  };
}

String localizedIngredientDisplayName(BuildContext context, String rawValue) {
  final lowerRaw = rawValue.toLowerCase();
  if (lowerRaw.contains('bezlakt')) {
    final normalizedSafe = _normalizeIngredientLabel(rawValue);
    if (normalizedSafe.contains('mlieko') || normalizedSafe.contains('milk')) {
      return context.tr(en: 'Lactose-free milk', sk: 'Bezlaktózové mlieko');
    }
    if (normalizedSafe.contains('syr') ||
        normalizedSafe.contains('cheese') ||
        normalizedSafe.contains('gorgonzola') ||
        normalizedSafe.contains('mozzarella')) {
      return context.tr(en: 'Lactose-free cheese', sk: 'Bezlaktózový syr');
    }
    if (normalizedSafe.contains('jogurt') ||
        normalizedSafe.contains('yogurt')) {
      return context.tr(en: 'Lactose-free yogurt', sk: 'Bezlaktózový jogurt');
    }
    if (normalizedSafe.contains('smotan') || normalizedSafe.contains('cream')) {
      return context.tr(en: 'Lactose-free cream', sk: 'Bezlaktózová smotana');
    }
    if (normalizedSafe.contains('maslo') || normalizedSafe.contains('butter')) {
      return context.tr(en: 'Lactose-free butter', sk: 'Bezlaktózové maslo');
    }
    return rawValue;
  }
  if (lowerRaw.contains('bezlepk')) {
    final normalizedSafe = _normalizeIngredientLabel(rawValue);
    if (normalizedSafe.contains('cestovin') ||
        normalizedSafe.contains('pasta')) {
      return context.tr(en: 'Gluten-free pasta', sk: 'Bezlepkové cestoviny');
    }
    if (normalizedSafe.contains('baget')) {
      return context.tr(en: 'Gluten-free baguette', sk: 'Bezlepková bageta');
    }
    if (normalizedSafe.contains('chlieb') ||
        normalizedSafe.contains('peciv') ||
        normalizedSafe.contains('bread')) {
      return context.tr(en: 'Gluten-free bread', sk: 'Bezlepkový chlieb');
    }
    if (normalizedSafe.contains('muka') || normalizedSafe.contains('flour')) {
      return context.tr(en: 'Gluten-free flour', sk: 'Bezlepková múka');
    }
    return rawValue;
  }
  if (lowerRaw.contains('nahrada vajec') || lowerRaw.contains('bezvajec')) {
    if (lowerRaw.contains('nahrada vajec')) {
      return context.tr(en: 'Egg replacement', sk: 'Náhrada vajec');
    }
    return context.tr(en: 'Egg-free alternative', sk: 'Bezvaječná alternatíva');
  }

  final normalized = _normalizeIngredientLabel(rawValue);
  const canonicalMap = {
    'eggs': 'eggs',
    'egg': 'eggs',
    'vajce': 'eggs',
    'vajcia': 'eggs',
    'milk': 'milk',
    'mlieko': 'milk',
    'cheese': 'cheese',
    'syr': 'cheese',
    'gorgonzola': 'cheese',
    'mozzarella': 'cheese',
    'carrot': 'carrots',
    'carrots': 'carrots',
    'mrkva': 'carrots',
    'mrkvy': 'carrots',
    'pasta': 'pasta',
    'cestoviny': 'pasta',
    'tomatosauce': 'tomatosauce',
    'tomato': 'tomatosauce',
    'paradajkovaomacka': 'tomatosauce',
    'paradajky': 'tomatosauce',
    'chicken': 'chicken',
    'kuracie': 'chicken',
    'kuraciemaso': 'chicken',
    'kura': 'chicken',
    'rice': 'rice',
    'ryza': 'rice',
    'onion': 'onion',
    'cibula': 'onion',
    'bread': 'bread',
    'chlieb': 'bread',
    'pecivo': 'bread',
    'ham': 'ham',
    'sunka': 'ham',
    'sunku': 'ham',
    'sunky': 'ham',
  };

  return localizedIngredientName(
    context,
    canonicalMap[normalized] ?? normalized,
    rawValue,
  );
}

String _normalizeIngredientLabel(String value) {
  const replacements = {
    'á': 'a',
    'ä': 'a',
    'č': 'c',
    'ď': 'd',
    'é': 'e',
    'ě': 'e',
    'í': 'i',
    'ĺ': 'l',
    'ľ': 'l',
    'ň': 'n',
    'ó': 'o',
    'ô': 'o',
    'ŕ': 'r',
    'ř': 'r',
    'š': 's',
    'ť': 't',
    'ú': 'u',
    'ů': 'u',
    'ý': 'y',
    'ž': 'z',
  };

  var normalized = value.toLowerCase();
  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
}
