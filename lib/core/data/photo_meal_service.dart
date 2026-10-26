import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../db/models.dart';
import '../widgets/emoji.dart';

/// A meal read from a photo: the plate as items the meal sheet can show,
/// scale and log.
class PhotoMeal {
  const PhotoMeal({
    required this.dish,
    required this.emoji,
    required this.mealType,
    required this.healthScore,
    required this.items,
  });

  final String dish;
  final String emoji;
  final MealType mealType;

  /// 1-10.
  final int healthScore;
  final List<MealItem> items;
}

sealed class PhotoMealResult {
  const PhotoMealResult();
}

class PhotoMealFound extends PhotoMealResult {
  const PhotoMealFound(this.meal);
  final PhotoMeal meal;
}

/// The photo doesn't show food.
class PhotoMealNotFood extends PhotoMealResult {
  const PhotoMealNotFood();
}

class PhotoMealFailed extends PhotoMealResult {
  const PhotoMealFailed(this.message);

  /// Readable, ready to show.
  final String message;
}

/// Sends a food photo to the app's proxy (see proxy/README.md), which asks
/// Claude what's on the plate. The proxy URL and token are baked in at build
/// time; without them photo logging is hidden.
class PhotoMealService {
  PhotoMealService({required this.installId, http.Client? client}) : _client = client ?? http.Client();

  static const _url = String.fromEnvironment('PHOTO_PROXY_URL');
  static const _token = String.fromEnvironment('PHOTO_PROXY_TOKEN');

  static bool get isConfigured => _url.isNotEmpty && _token.isNotEmpty;

  /// Why photo logging is switched off on the server right now (it can be
  /// paused there, e.g. out of API credit), or null when it's on. Asked
  /// before the camera opens so nobody takes a photo for nothing. Offline
  /// counts as on: the upload then explains the problem itself.
  static Future<String?> offReason({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse('$_url/status')).timeout(const Duration(seconds: 5));
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode != 200 || body is! Map<String, dynamic> || body['enabled'] != false) return null;
      final message = body['message'];
      return message is String && message.isNotEmpty ? message : 'Photo logging is paused for now.';
    } on Exception {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Random per install, for the proxy's per-install rate limit.
  final String installId;
  final http.Client _client;

  // Claude can take a while on a busy plate.
  static const _timeout = Duration(seconds: 60);

  /// [note] is the user's correction when re-asking ("it's paneer, not tofu").
  Future<PhotoMealResult> analyze(Uint8List image, {required DateTime at, String? note}) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$_url/analyze'),
            headers: {
              'Authorization': 'Bearer $_token',
              'X-Install-Id': installId,
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'image': base64Encode(image),
              'mediaType': mediaTypeOf(image),
              'localTime': '${_two(at.hour)}:${_two(at.minute)}',
              if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      return const PhotoMealFailed('That took too long. Check your connection and try again.');
    } on Exception {
      return const PhotoMealFailed('Couldn’t reach the server. Check your connection and try again.');
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      return const PhotoMealFailed('Something went wrong. Try again.');
    }
    if (res.statusCode != 200) {
      final message = body is Map<String, dynamic> ? body['message'] : null;
      return PhotoMealFailed(message is String ? message : 'Something went wrong. Try again.');
    }
    return body is Map<String, dynamic> ? parse(body) : const PhotoMealFailed('Something went wrong. Try again.');
  }

  /// Reads the proxy's answer. Exposed for testing.
  static PhotoMealResult parse(Map<String, dynamic> j) {
    final items = <MealItem>[
      for (final raw in (j['items'] as List?) ?? const [])
        if (raw is Map<String, dynamic>) ?_item(raw),
    ];
    if (j['is_food'] == false || items.isEmpty) return const PhotoMealNotFood();

    final emoji = j['emoji'] is String && (j['emoji'] as String).isNotEmpty ? j['emoji'] as String : AppEmoji.meal;
    final dish = (j['dish'] as String?)?.trim();
    return PhotoMealFound(PhotoMeal(
      dish: dish == null || dish.isEmpty ? 'Meal' : dish,
      emoji: emoji,
      mealType: MealType.values.asNameMap()[j['meal_type']] ?? MealType.forTime(DateTime.now()),
      healthScore: ((j['health_score'] as num?)?.round() ?? 5).clamp(1, 10),
      items: [for (final i in items) i.withEmoji(emoji)],
    ));
  }

  static MealItem? _item(Map<String, dynamic> j) {
    final name = (j['name'] as String?)?.trim();
    final grams = (j['grams'] as num?)?.round();
    final kcal = (j['kcal'] as num?)?.round();
    if (name == null || name.isEmpty || kcal == null || kcal < 0) return null;
    double g(String k) => ((j[k] as num?)?.toDouble() ?? 0).clamp(0, 1000);
    return MealItem(
      name: name.length > 120 ? name.substring(0, 120) : name,
      emoji: AppEmoji.meal,
      serving: grams != null && grams > 0 ? '$grams g' : '1 portion',
      qty: 1,
      kcal: kcal,
      protein: _round1(g('protein')),
      carbs: _round1(g('carbs')),
      fat: _round1(g('fat')),
    );
  }

  /// JPEG unless the bytes say PNG or WebP (gallery picks can be either).
  static String mediaTypeOf(Uint8List b) {
    if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    if (b.length > 12 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return 'image/webp';
    return 'image/jpeg';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static double _round1(double v) => (v * 10).roundToDouble() / 10;
}

extension on MealItem {
  MealItem withEmoji(String e) => MealItem(
        name: name,
        emoji: e,
        serving: serving,
        qty: qty,
        kcal: kcal,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
}
