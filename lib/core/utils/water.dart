/// 250 -> "250 ml", 1500 -> "1.5 L", 3000 -> "3 L", 1250 -> "1.25 L".
String formatWater(int ml) =>
    ml < 1000 ? '$ml ml' : '${formatLiters(ml)} L';

/// Litres without the unit: 1500 -> "1.5", 3000 -> "3", 1250 -> "1.25".
String formatLiters(int ml) {
  final l = ml / 1000;
  var s = l.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Goal limits and the step used by the +/- controls, in millilitres.
abstract final class WaterLimits {
  static const int minGoal = 500;
  static const int maxGoal = 8000;
  static const int goalStep = 250;

  /// One-tap amounts offered in the water sheet.
  static const List<int> presets = [150, 250, 330, 500, 750, 1000];

  /// Choices for the Settings "glass size".
  static const List<int> glassSizes = [150, 200, 250, 330, 500];
}
