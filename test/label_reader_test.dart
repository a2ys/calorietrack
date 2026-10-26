import 'dart:ui' show Rect;

import 'package:calorie_app/core/data/label_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// A cell of text at column [x] (left edge) on row [y].
LabelLine cell(String text, double x, double y, {double w = 80}) => LabelLine(text, Rect.fromLTWH(x, y, w, 24));

void main() {
  test('a typical Indian label: per 100 g, per serve and %RDA columns', () {
    final r = readNutritionLabel([
      cell('NUTRITIONAL INFORMATION', 0, 60, w: 300),
      cell('Per 100 g', 400, 110),
      cell('Per serve (30 g)', 560, 110, w: 140),
      cell('%RDA*', 760, 110),
      cell('Energy (kcal)', 0, 160, w: 160),
      cell('480', 410, 162),
      cell('144', 590, 158),
      cell('7%', 770, 160),
      cell('Protein (g)', 0, 200, w: 160),
      cell('7.1', 410, 201),
      cell('2.1', 590, 199),
      cell('Carbohydrate (g)', 0, 240, w: 160),
      cell('62.3', 410, 240),
      cell('18.7', 590, 241),
      cell('of which Total Sugars (g)', 20, 280, w: 200),
      cell('16.0', 410, 280),
      cell('Total Fat (g)', 0, 320, w: 160),
      cell('21.6', 410, 322),
      cell('6.5', 590, 319),
      cell('Saturated Fat (g)', 20, 360, w: 160),
      cell('10.2', 410, 360),
    ])!;
    expect(r.per100, isTrue);
    expect(r.kcal, 480);
    expect(r.protein, 7.1);
    expect(r.carbs, 62.3);
    expect(r.fat, 21.6);
    expect(r.servingGrams, 30);
  });

  test('picks the per 100 g column even when per serve comes first', () {
    final r = readNutritionLabel([
      cell('Per serve (25g)', 400, 100, w: 120),
      cell('Per 100g', 600, 100),
      cell('Energy', 0, 150),
      cell('130 kcal', 410, 150),
      cell('520 kcal', 610, 150),
      cell('Protein', 0, 190),
      cell('1.5g', 410, 190),
      cell('6g', 610, 190),
      cell('Carbohydrates', 0, 230, w: 120),
      cell('17g', 410, 230),
      cell('68g', 610, 230),
      cell('Fat', 0, 270),
      cell('6.3g', 410, 270),
      cell('25g', 610, 270),
    ])!;
    expect(r.kcal, 520);
    expect(r.protein, 6);
    expect(r.carbs, 68);
    expect(r.fat, 25);
    expect(r.servingGrams, 25);
  });

  test('values on the same line as their names, kJ and kcal together', () {
    final r = readNutritionLabel([
      cell('Typical values per 100g', 0, 40, w: 300),
      cell('Energy 2010 kJ / 480 kcal', 0, 80, w: 300),
      cell('Fat 21,6 g', 0, 110, w: 300),
      cell('of which saturates 10 g', 0, 140, w: 300),
      cell('Carbohydrate 62,3 g', 0, 170, w: 300),
      cell('Protein 7,1 g', 0, 200, w: 300),
    ])!;
    expect(r.kcal, 480);
    expect(r.fat, 21.6);
    expect(r.carbs, 62.3);
    expect(r.protein, 7.1);
  });

  test('kJ only is converted; missing energy is worked out from macros', () {
    final kj = readNutritionLabel([
      cell('Energy 1000 kJ', 0, 80, w: 300),
      cell('Protein 10 g', 0, 110, w: 300),
      cell('Carbohydrate 30 g', 0, 140, w: 300),
      cell('Fat 5 g', 0, 170, w: 300),
    ])!;
    expect(kj.kcal, closeTo(239, 1));

    final none = readNutritionLabel([
      cell('Protein 10 g', 0, 110, w: 300),
      cell('Carbohydrate 30 g', 0, 140, w: 300),
      cell('Total fat 5 g', 0, 170, w: 300),
    ])!;
    expect(none.kcal, 205);
  });

  test('too little or nonsense is not trusted', () {
    expect(readNutritionLabel([]), isNull);
    expect(readNutritionLabel([cell('Best before 12/2026', 0, 0, w: 300), cell('MRP Rs 20', 0, 40)]), isNull);
    expect(readNutritionLabel([cell('Energy 480 kcal', 0, 0, w: 300)]), isNull);
    // A misread 4800 kcal per 100 g is dropped, leaving too little.
    expect(
      readNutritionLabel([cell('Per 100 g', 300, 0), cell('Energy 4800 kcal', 0, 40, w: 300), cell('Protein 7 g', 0, 80, w: 300)]),
      isNull,
    );
  });
}
