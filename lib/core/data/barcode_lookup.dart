import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;

import '../db/database.dart';
import '../widgets/emoji.dart';
import 'food.dart';

/// What a barcode scan turned up.
sealed class BarcodeResult {
  const BarcodeResult(this.barcode);
  final String barcode;
}

/// A product with nutrition, ready to log.
class BarcodeFound extends BarcodeResult {
  const BarcodeFound(super.barcode, this.food);
  final Food food;
}

/// Open Food Facts doesn't know the code, or has it without calories.
/// [name] is set when at least the product name was there.
class BarcodeNotFound extends BarcodeResult {
  const BarcodeNotFound(super.barcode, {this.name});
  final String? name;
}

/// The lookup couldn't be made (offline, timeout, server error).
class BarcodeFailed extends BarcodeResult {
  const BarcodeFailed(super.barcode);
}

/// Finds a packaged food by barcode: the on-device cache first, then Open
/// Food Facts (free, open data, no key). Found products are cached, so a
/// second scan is instant and works offline.
class BarcodeLookup {
  BarcodeLookup(this._db, {http.Client? client}) : _client = client ?? http.Client();

  final AppDatabase _db;
  final http.Client _client;

  static const _timeout = Duration(seconds: 8);
  static const _fields = 'product_name,product_name_en,generic_name,brands,nutriments,serving_quantity';

  Future<BarcodeResult> lookup(String barcode) async {
    final cached = await _db.getScannedFood(barcode);
    if (cached != null) return BarcodeFound(barcode, foodFromScanned(cached));

    final http.Response res;
    try {
      res = await _client.get(
        Uri.https('world.openfoodfacts.org', '/api/v2/product/$barcode.json', {'fields': _fields}),
        // Open Food Facts asks apps to identify themselves.
        headers: {'User-Agent': 'CalorieApp/1.0 (Android; personal calorie tracker)'},
      ).timeout(_timeout);
    } on Exception {
      return BarcodeFailed(barcode);
    }
    if (res.statusCode == 404) return BarcodeNotFound(barcode);
    if (res.statusCode != 200) return BarcodeFailed(barcode);

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      return BarcodeFailed(barcode);
    }
    final result = parseOpenFoodFacts(barcode, json);
    if (result is BarcodeFound) await remember(barcode, result.food);
    return result;
  }

  /// Caches [food] under [barcode]: a product found online, or one the user
  /// typed in after a miss, so the next scan finds it.
  Future<void> remember(String barcode, Food food) => _db.saveScannedFood(
        ScannedFoodsCompanion.insert(
          barcode: barcode,
          name: food.name,
          serving: food.serving,
          grams: Value(food.grams),
          kcal: food.kcal,
          protein: Value(food.protein),
          carbs: Value(food.carbs),
          fat: Value(food.fat),
          savedAt: DateTime.now(),
        ),
      );

  static Food foodFromScanned(ScannedFood f) => Food(
        name: f.name,
        emoji: AppEmoji.packaged,
        group: FoodGroup.other,
        // Rows cached by the first build were labelled "1 serving (50 g)".
        serving: f.grams != null && f.serving.startsWith('1 serving (') ? '${f.grams} g' : f.serving,
        grams: f.grams,
        kcal: f.kcal,
        protein: f.protein,
        carbs: f.carbs,
        fat: f.fat,
      );

  /// Reads an Open Food Facts v2 product response. Nutrition there is per
  /// 100 g; the serving is the pack's own serving weight when it gives a
  /// sensible one, else 100 g. Exposed for testing.
  static BarcodeResult parseOpenFoodFacts(String barcode, Map<String, dynamic> json) {
    final product = json['product'];
    if (json['status'] != 1 || product is! Map<String, dynamic>) return BarcodeNotFound(barcode);

    final name = _name(product);
    final n = product['nutriments'];
    if (n is! Map<String, dynamic>) return BarcodeNotFound(barcode, name: name);

    // Some products only list kJ.
    final kcal = _num(n['energy-kcal_100g']) ?? _kj(_num(n['energy_100g']));
    if (kcal == null || name == null) return BarcodeNotFound(barcode, name: name);

    final serving = _num(product['serving_quantity']);
    final grams = (serving != null && serving >= 5 && serving <= 1000) ? serving.round() : 100;

    return BarcodeFound(
      barcode,
      Food.per100g(
        name: name,
        emoji: AppEmoji.packaged,
        group: FoodGroup.other,
        serving: '$grams g',
        grams: grams,
        kcal: kcal,
        protein: _num(n['proteins_100g']) ?? 0,
        carbs: _num(n['carbohydrates_100g']) ?? 0,
        fat: _num(n['fat_100g']) ?? 0,
      ),
    );
  }

  /// "Brand Product", without repeating a brand the name already starts with.
  static String? _name(Map<String, dynamic> p) {
    String? clean(Object? v) {
      final s = v is String ? v.trim() : '';
      return s.isEmpty ? null : s;
    }

    final name = clean(p['product_name']) ?? clean(p['product_name_en']) ?? clean(p['generic_name']);
    if (name == null) return null;
    final brand = clean((p['brands'] as Object?)?.toString().split(',').first);
    final full = brand == null || name.toLowerCase().startsWith(brand.toLowerCase()) ? name : '$brand $name';
    return full.length > 120 ? full.substring(0, 120) : full;
  }

  // Values arrive as numbers or numeric strings.
  static num? _num(Object? v) => switch (v) {
        num n => n,
        String s => num.tryParse(s.replaceAll(',', '.')),
        _ => null,
      };

  static num? _kj(num? kj) => kj == null ? null : kj / 4.184;
}
