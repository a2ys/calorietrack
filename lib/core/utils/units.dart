enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.label);
  final String label;
}

enum HeightUnit {
  cm('cm'),
  ft('ft');

  const HeightUnit(this.label);
  final String label;
}

abstract final class Units {
  static const double kgPerLb = 0.45359237;
  static const double cmPerInch = 2.54;
  static const int inchesPerFoot = 12;

  static double kgToLb(double kg) => kg / kgPerLb;
  static double lbToKg(double lb) => lb * kgPerLb;

  static double cmToInches(double cm) => cm / cmPerInch;
  static double inchesToCm(num inches) => inches * cmPerInch;

  /// 175 cm -> (5, 9)
  static (int feet, int inches) cmToFeetInches(double cm) {
    final total = cmToInches(cm).round();
    return (total ~/ inchesPerFoot, total % inchesPerFoot);
  }

  static String formatWeight(double kg, WeightUnit unit) => switch (unit) {
        WeightUnit.kg => '${_trim(kg)} kg',
        WeightUnit.lb => '${_trim(kgToLb(kg))} lb',
      };

  static String formatHeight(double cm, HeightUnit unit) {
    switch (unit) {
      case HeightUnit.cm:
        return '${cm.round()} cm';
      case HeightUnit.ft:
        final (ft, inch) = cmToFeetInches(cm);
        return '$ft′ $inch″';
    }
  }

  static String _trim(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1);
  }
}
