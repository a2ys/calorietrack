import 'dart:convert';

import 'package:flutter/services.dart';

import 'common_foods.dart';
import 'food.dart';

/// Every food the app can look up: the curated list (instant, ships in code)
/// plus ~6,000 USDA foods loaded from an asset in the background.
class FoodCatalog {
  FoodCatalog(this.all) {
    for (final f in all) {
      (_byGroup[f.group] ??= []).add(f);
    }
  }

  final List<Food> all;
  final Map<FoodGroup, List<Food>> _byGroup = {};

  /// Available immediately, before the USDA asset has loaded.
  static final FoodCatalog curated = FoodCatalog(kCommonFoods);

  static const _asset = 'assets/data/usda_foods.json';

  static Future<FoodCatalog> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(_asset);
    return FoodCatalog([...kCommonFoods, ...parseUsda(raw)]);
  }

  /// Rows are `[name, group, emoji, kcal, protein, carbs, fat, grams, serving]`
  /// with nutrition per 100 g.
  static List<Food> parseUsda(String json) => [
        for (final r in jsonDecode(json) as List)
          Food.per100g(
            name: r[0] as String,
            group: FoodGroup.parse(r[1] as String),
            emoji: r[2] as String,
            kcal: r[3] as num,
            protein: r[4] as num,
            carbs: r[5] as num,
            fat: r[6] as num,
            grams: (r[7] as num).round(),
            serving: r[8] as String,
          ),
      ];

  List<Food> inGroup(FoodGroup g) => _byGroup[g] ?? const [];

  /// First curated food with exactly this name.
  Food? byName(String name) {
    for (final f in all) {
      if (f.name == name) return f;
    }
    return null;
  }

  /// Foods whose name or aliases contain every word of [query] (each word
  /// matched from the start of a word), best matches first.
  List<Food> search(String query, {int limit = 80}) {
    final tokens = normalizeSearch(query).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];
    final phrase = tokens.join(' ');

    var hits = _match(tokens, (f, t) => f.key.contains(' $t'));
    // Nothing starts with that? Fall back to matching inside words.
    if (hits.isEmpty) hits = _match(tokens, (f, t) => f.key.contains(t));

    final scored = <(double, Food)>[];
    for (final f in hits) {
      final name = normalizeSearch(f.name);
      var score = name.length * 0.05;
      if (name == phrase) {
        score -= 60;
      } else if (name.startsWith(phrase)) {
        score -= 30;
      } else if (name.startsWith(tokens.first)) {
        score -= 15;
      }
      // The headline alias ("chawal" for rice) beats a food that merely lists it.
      if (f.aliasText.startsWith(tokens.first)) score -= 20;
      if (f.curated) score -= 40;
      scored.add((score, f));
    }
    scored.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final s in scored.take(limit)) s.$2];
  }

  List<Food> _match(List<String> tokens, bool Function(Food, String) test) => [
        for (final f in all)
          if (tokens.every((t) => test(f, t))) f,
      ];
}
