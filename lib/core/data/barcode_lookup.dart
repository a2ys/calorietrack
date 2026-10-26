import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;

import '../db/database.dart';
import '../widgets/emoji.dart';
import 'app_proxy.dart';
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

/// Finds a packaged food by barcode, trying each source in turn:
///   1. this phone's cache (instant, offline),
///   2. Open Food Facts (free open data), under both forms of the code,
///   3. the products friends typed in after a miss ([SharedProducts]).
/// Whatever is found is cached, so a second scan is instant.
class BarcodeLookup {
  BarcodeLookup(this._db, {http.Client? client, this.shared}) : _client = client ?? http.Client();

  /// The lookup the app uses: with the shared list when the proxy is set up.
  static Future<BarcodeLookup> forApp(AppDatabase db) async => BarcodeLookup(
        db,
        shared: AppProxy.isConfigured ? SharedProducts(installId: await db.installId()) : null,
      );

  final AppDatabase _db;
  final http.Client _client;
  final SharedProducts? shared;

  static const _timeout = Duration(seconds: 8);
  static const _fields = 'product_name,product_name_en,generic_name,brands,nutriments,serving_quantity';

  /// The same product is often listed as a 12-digit UPC-A in one place and
  /// as the 13-digit EAN with a leading 0 in another. Exposed for testing.
  static List<String> variants(String code) => [
        code,
        if (code.length == 12) '0$code',
        if (code.length == 13 && code.startsWith('0')) code.substring(1),
      ];

  Future<BarcodeResult> lookup(String barcode) async {
    final codes = variants(barcode);
    for (final c in codes) {
      final cached = await _db.getScannedFood(c);
      if (cached != null) return BarcodeFound(barcode, foodFromScanned(cached));
    }

    // Open Food Facts. A name without nutrition still helps prefill the form.
    String? name;
    var offline = false;
    for (final c in codes) {
      final r = await _openFoodFacts(c);
      if (r is BarcodeFound) {
        await remember(barcode, r.food);
        return BarcodeFound(barcode, r.food);
      }
      if (r is BarcodeNotFound) name ??= r.name;
      if (r is BarcodeFailed) offline = true;
    }

    final s = shared;
    if (s != null) {
      for (final c in codes) {
        final food = await s.get(c);
        if (food != null) {
          await remember(barcode, food);
          return BarcodeFound(barcode, food);
        }
      }
    }
    // "Failed" only when nothing could be asked at all; otherwise it's a miss.
    return offline && name == null ? BarcodeFailed(barcode) : BarcodeNotFound(barcode, name: name);
  }

  Future<BarcodeResult> _openFoodFacts(String barcode) async {
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
    try {
      return parseOpenFoodFacts(barcode, jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } on FormatException {
      return BarcodeFailed(barcode);
    }
  }

  /// Saves a product the user typed in after a miss: on this phone, and in
  /// the shared list so friends' scans find it too.
  Future<void> contribute(String barcode, Food food) async {
    await remember(barcode, food);
    await shared?.put(barcode, food);
  }

  /// Caches [food] under [barcode] on this phone, so the next scan finds it.
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

/// Products friends typed in after a barcode miss, kept on the app's proxy
/// so one person's entry fixes the scan for everyone.
class SharedProducts {
  SharedProducts({required this.installId, http.Client? client}) : _client = client ?? http.Client();

  final String installId;
  final http.Client _client;

  static const _timeout = Duration(seconds: 6);

  Uri _uri(String barcode) => Uri.parse('${AppProxy.url}/product/$barcode');

  /// Null when nobody has added it, or the list can't be reached.
  Future<Food?> get(String barcode) async {
    try {
      final res = await _client.get(_uri(barcode), headers: AppProxy.headers(installId)).timeout(_timeout);
      if (res.statusCode != 200) return null;
      return foodFromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } on Exception {
      return null;
    }
  }

  /// Best effort: a failed share still leaves the product on this phone.
  Future<void> put(String barcode, Food food) async {
    try {
      await _client
          .put(_uri(barcode), headers: AppProxy.headers(installId), body: jsonEncode(foodToJson(food)))
          .timeout(_timeout);
    } on Exception {
      // Offline: it's still saved on this phone.
    }
  }

  static Map<String, Object?> foodToJson(Food f) => {
        'name': f.name,
        'serving': f.serving,
        'grams': f.grams,
        'kcal': f.kcal,
        'protein': f.protein,
        'carbs': f.carbs,
        'fat': f.fat,
      };

  /// Null unless it's a well-formed product. Exposed for testing.
  static Food? foodFromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final name = j['name'], serving = j['serving'], kcal = j['kcal'];
    if (name is! String || name.isEmpty || serving is! String || serving.isEmpty || kcal is! num) return null;
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return Food(
      name: name,
      emoji: AppEmoji.packaged,
      group: FoodGroup.other,
      serving: serving,
      grams: (j['grams'] as num?)?.round(),
      kcal: kcal.round(),
      protein: n('protein'),
      carbs: n('carbs'),
      fat: n('fat'),
    );
  }
}
