import 'dart:convert';

import 'package:calorie_app/core/data/barcode_lookup.dart';
import 'package:calorie_app/core/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> product({
  Object? name = 'Digestive Biscuits',
  Object? brands = 'McVitie\'s,Pladis',
  Map<String, dynamic>? nutriments,
  Object? serving = 30,
}) =>
    {
      'status': 1,
      'product': {
        'product_name': name,
        'brands': brands,
        'serving_quantity': serving,
        'nutriments': nutriments ??
            {
              'energy-kcal_100g': 480,
              'proteins_100g': 7.1,
              'carbohydrates_100g': 62.3,
              'fat_100g': 21.6,
            },
      },
    };

void main() {
  group('parseOpenFoodFacts', () {
    test('scales per-100 g nutrition to the pack serving', () {
      final r = BarcodeLookup.parseOpenFoodFacts('1', product());
      final food = (r as BarcodeFound).food;
      expect(food.name, 'McVitie\'s Digestive Biscuits');
      expect(food.grams, 30);
      expect(food.serving, '30 g');
      expect(food.kcal, 144);
      expect(food.protein, 2.1);
      // Any weight can be logged from it.
      expect(food.withGrams(100).kcal, 480);
    });

    test('falls back to 100 g when the serving is missing or odd', () {
      for (final s in [null, 0, 'abc', 5000]) {
        final food = (BarcodeLookup.parseOpenFoodFacts('1', product(serving: s)) as BarcodeFound).food;
        expect(food.grams, 100, reason: '$s');
        expect(food.serving, '100 g');
        expect(food.kcal, 480);
      }
    });

    test('reads kJ-only energy and numeric strings', () {
      final r = BarcodeLookup.parseOpenFoodFacts(
        '1',
        product(serving: '50', nutriments: {'energy_100g': '1000', 'proteins_100g': '10,5'}),
      );
      final food = (r as BarcodeFound).food;
      expect(food.kcal, 120); // 1000 kJ / 4.184 = 239 kcal per 100 g
      expect(food.protein, 5.3);
    });

    test('does not repeat a brand the name already has', () {
      final food = (BarcodeLookup.parseOpenFoodFacts('1', product(name: 'Maggi Noodles', brands: 'Maggi'))
              as BarcodeFound)
          .food;
      expect(food.name, 'Maggi Noodles');
    });

    test('a product without calories is not found, but keeps its name', () {
      final r = BarcodeLookup.parseOpenFoodFacts('1', product(nutriments: {'proteins_100g': 3}));
      expect(r, isA<BarcodeNotFound>());
      expect((r as BarcodeNotFound).name, 'McVitie\'s Digestive Biscuits');
    });

    test('an unknown code is not found', () {
      expect(BarcodeLookup.parseOpenFoodFacts('1', {'status': 0}), isA<BarcodeNotFound>());
    });
  });

  group('lookup', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('caches a found product so the next scan skips the network', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        expect(req.url.path, '/api/v2/product/5000168001029.json');
        return http.Response(jsonEncode(product()), 200);
      });
      final lookup = BarcodeLookup(db, client: client);

      final first = await lookup.lookup('5000168001029');
      expect((first as BarcodeFound).food.kcal, 144);

      final offline = BarcodeLookup(db, client: MockClient((_) async => throw http.ClientException('offline')));
      final second = await offline.lookup('5000168001029');
      expect((second as BarcodeFound).food.name, 'McVitie\'s Digestive Biscuits');
      expect(second.food.withGrams(45).kcal, 216);
      expect(calls, 1);
    });

    test('offline or server errors fail rather than say not found', () async {
      final offline = BarcodeLookup(db, client: MockClient((_) async => throw http.ClientException('x')));
      expect(await offline.lookup('1'), isA<BarcodeFailed>());
      final down = BarcodeLookup(db, client: MockClient((_) async => http.Response('', 503)));
      expect(await down.lookup('1'), isA<BarcodeFailed>());
      final unknown = BarcodeLookup(db, client: MockClient((_) async => http.Response('{"status":0}', 404)));
      expect(await unknown.lookup('1'), isA<BarcodeNotFound>());
    });

    test('a product typed in after a miss is found next time', () async {
      final lookup = BarcodeLookup(db, client: MockClient((_) async => http.Response('{"status":0}', 404)));
      expect(await lookup.lookup('42'), isA<BarcodeNotFound>());
      final typed = (BarcodeLookup.parseOpenFoodFacts('42', product(serving: null)) as BarcodeFound).food;
      await lookup.remember('42', typed);
      expect((await lookup.lookup('42') as BarcodeFound).food.kcal, 480);
    });
  });
}
