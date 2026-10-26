import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_app/core/data/photo_meal_service.dart';
import 'package:calorie_app/core/db/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> answer({bool isFood = true, List<Map<String, dynamic>>? items}) => {
      'is_food': isFood,
      'dish': 'Rajma chawal',
      'emoji': '🍛',
      'meal_type': 'lunch',
      'health_score': 7,
      'items': items ??
          [
            {'name': 'Rajma', 'grams': 180, 'kcal': 230, 'protein': 12.4, 'carbs': 30.06, 'fat': 6.5},
            {'name': 'Steamed rice', 'grams': 200, 'kcal': 260, 'protein': 5, 'carbs': 56, 'fat': 0.6},
          ],
    };

void main() {
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

  group('parse', () {
    test('turns the answer into loggable items', () {
      final meal = (PhotoMealService.parse(answer()) as PhotoMealFound).meal;
      expect(meal.dish, 'Rajma chawal');
      expect(meal.mealType, MealType.lunch);
      expect(meal.healthScore, 7);
      expect(meal.items.map((i) => i.serving), ['180 g', '200 g']);
      expect(meal.items.first.carbs, 30.1);
      expect(sumMealItems(meal.items).kcal, 490);
      expect(meal.items.every((i) => i.emoji == '🍛'), isTrue);
    });

    test('no food, or nothing usable, is not food', () {
      expect(PhotoMealService.parse(answer(isFood: false, items: [])), isA<PhotoMealNotFood>());
      expect(PhotoMealService.parse(answer(items: [{'name': '', 'kcal': 10}, {'name': 'x'}])), isA<PhotoMealNotFood>());
    });

    test('odd values are clamped or defaulted', () {
      final j = answer(items: [{'name': 'Thali', 'kcal': 800.6, 'protein': -3, 'carbs': 5000}])
        ..['health_score'] = 42
        ..['meal_type'] = 'brunch'
        ..['emoji'] = '';
      final meal = (PhotoMealService.parse(j) as PhotoMealFound).meal;
      final item = meal.items.single;
      expect(item.kcal, 801);
      expect(item.protein, 0);
      expect(item.carbs, 1000);
      expect(item.serving, '1 portion');
      expect(meal.healthScore, 10);
      expect(meal.emoji, isNotEmpty);
    });
  });

  group('analyze', () {
    test('sends the photo, time and correction; reads the answer', () async {
      late Map<String, dynamic> sent;
      late Map<String, String> headers;
      final service = PhotoMealService(
        installId: 'abc',
        client: MockClient((req) async {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          headers = req.headers;
          return http.Response(jsonEncode(answer()), 200, headers: {'content-type': 'application/json'});
        }),
      );
      final r = await service.analyze(jpeg, at: DateTime(2026, 10, 27, 9, 5), note: ' 2 rotis ');
      expect(r, isA<PhotoMealFound>());
      expect(sent['localTime'], '09:05');
      expect(sent['mediaType'], 'image/jpeg');
      expect(sent['note'], '2 rotis');
      expect(base64Decode(sent['image'] as String), jpeg);
      expect(headers['X-Install-Id'], 'abc');
    });

    test('server errors carry their message; network errors a readable one', () async {
      final busy = PhotoMealService(
        installId: 'x',
        client: MockClient((_) async => http.Response(jsonEncode({'error': 'busy', 'message': 'The service is busy.'}), 503)),
      );
      expect((await busy.analyze(jpeg, at: DateTime.now()) as PhotoMealFailed).message, 'The service is busy.');

      final offline = PhotoMealService(installId: 'x', client: MockClient((_) async => throw http.ClientException('x')));
      expect(await offline.analyze(jpeg, at: DateTime.now()), isA<PhotoMealFailed>());
    });
  });

  test('the server switch says why photos are off, and offline counts as on', () async {
    Future<String?> reason(Future<http.Response> Function() reply) =>
        PhotoMealService.offReason(client: MockClient((_) => reply()));

    expect(await reason(() async => http.Response('{"enabled":true}', 200)), isNull);
    expect(
      await reason(() async => http.Response(jsonEncode({'enabled': false, 'message': 'Out of tokens, lol.'}), 200)),
      'Out of tokens, lol.',
    );
    expect(await reason(() async => http.Response('{"enabled":false}', 200)), isNotEmpty);
    expect(await reason(() async => throw http.ClientException('offline')), isNull);
    expect(await reason(() async => http.Response('oops', 500)), isNull);
  });

  test('media type follows the bytes', () {
    expect(PhotoMealService.mediaTypeOf(jpeg), 'image/jpeg');
    expect(PhotoMealService.mediaTypeOf(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0])), 'image/png');
    expect(
      PhotoMealService.mediaTypeOf(Uint8List.fromList(utf8.encode('RIFF\x00\x00\x00\x00WEBPVP8 '))),
      'image/webp',
    );
  });
}
