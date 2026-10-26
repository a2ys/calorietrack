import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/units.dart';
import 'wheel_picker.dart';

/// Three wheels: age, height and weight. Values are always reported in
/// cm / kg; the wheels display whichever units are passed in.
class BodyStatsPicker extends StatelessWidget {
  const BodyStatsPicker({
    super.key,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.heightUnit,
    required this.weightUnit,
    required this.onAge,
    required this.onHeightCm,
    required this.onWeightKg,
  });

  final int age;
  final double heightCm;
  final double weightKg;
  final HeightUnit heightUnit;
  final WeightUnit weightUnit;
  final ValueChanged<int> onAge;
  final ValueChanged<double> onHeightCm;
  final ValueChanged<double> onWeightKg;

  static const int minAge = 13;
  static const int maxAge = 90;
  static const int minCm = 120;
  static const int maxCm = 230;
  static const int minInches = 48;
  static const int maxInches = 91;
  static const int minKg = 30;
  static const int maxKg = 250;
  static const int minLb = 66;
  static const int maxLb = 551;

  @override
  Widget build(BuildContext context) {
    final t = context.type;

    Widget column(String label, Widget wheel, {int flex = 1}) => Expanded(
          flex: flex,
          child: Column(
            children: [
              Text(label, style: t.label),
              const SizedBox(height: AppSpacing.sm),
              wheel,
            ],
          ),
        );

    return Row(
      children: [
        column(
          'Age',
          WheelPicker(
            count: maxAge - minAge + 1,
            labelOf: (i) => '${minAge + i}',
            initialIndex: (age - minAge).clamp(0, maxAge - minAge),
            onSelected: (i) => onAge(minAge + i),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        column(
          'Height',
          heightUnit == HeightUnit.cm
              ? WheelPicker(
                  key: const ValueKey('h-cm'),
                  count: maxCm - minCm + 1,
                  labelOf: (i) => '${minCm + i}',
                  suffix: 'cm',
                  initialIndex: (heightCm.round() - minCm).clamp(0, maxCm - minCm),
                  onSelected: (i) => onHeightCm((minCm + i).toDouble()),
                )
              : WheelPicker(
                  key: const ValueKey('h-ft'),
                  count: maxInches - minInches + 1,
                  labelOf: (i) {
                    final total = minInches + i;
                    return '${total ~/ Units.inchesPerFoot}′${total % Units.inchesPerFoot}″';
                  },
                  initialIndex: (Units.cmToInches(heightCm).round() - minInches)
                      .clamp(0, maxInches - minInches),
                  onSelected: (i) =>
                      onHeightCm(Units.inchesToCm(minInches + i).roundToDouble()),
                ),
          flex: 2,
        ),
        const SizedBox(width: AppSpacing.sm),
        column(
          'Weight',
          weightUnit == WeightUnit.kg
              ? WheelPicker(
                  key: const ValueKey('w-kg'),
                  count: maxKg - minKg + 1,
                  labelOf: (i) => '${minKg + i}',
                  suffix: 'kg',
                  initialIndex: (weightKg.round() - minKg).clamp(0, maxKg - minKg),
                  onSelected: (i) => onWeightKg((minKg + i).toDouble()),
                )
              : WheelPicker(
                  key: const ValueKey('w-lb'),
                  count: maxLb - minLb + 1,
                  labelOf: (i) => '${minLb + i}',
                  suffix: 'lb',
                  initialIndex: (Units.kgToLb(weightKg).round() - minLb)
                      .clamp(0, maxLb - minLb),
                  onSelected: (i) =>
                      onWeightKg(Units.lbToKg((minLb + i).toDouble())),
                ),
          flex: 2,
        ),
      ],
    );
  }
}
