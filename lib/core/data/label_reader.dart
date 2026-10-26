import 'dart:ui' show Rect;

/// One line of text found on a photo of a nutrition label, with where it is.
class LabelLine {
  const LabelLine(this.text, this.box);
  final String text;
  final Rect box;
}

/// Nutrition read off a label. Values are per 100 g (or ml) when [per100] is
/// true, else per serving; [servingGrams] is the label's serving size if it
/// states one.
class LabelNutrition {
  const LabelNutrition({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.per100,
    this.servingGrams,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final bool per100;
  final int? servingGrams;
}

/// Reads the energy, protein, carbohydrate and fat rows of a nutrition table
/// from OCR lines. Tables come back as separate lines per cell, so cells are
/// regrouped into rows by height, and the "per 100 g" column is found by its
/// header's position (labels often add per-serving and %RDA columns). Null
/// when too little was readable to trust.
LabelNutrition? readNutritionLabel(List<LabelLine> lines) {
  if (lines.isEmpty) return null;
  final rows = _rows(lines);

  // Column headers: where "per 100 g" and "per serving" sit, left to right.
  double? per100X, servingX;
  int? servingGrams;
  for (final row in rows) {
    for (final cell in row) {
      final t = _norm(cell.text);
      if (per100X == null && RegExp(r'100\s*(g|gm|ml)\b').hasMatch(t)) per100X = cell.box.center.dx;
      if (RegExp(r'serv').hasMatch(t)) {
        servingX ??= cell.box.center.dx;
        final g = RegExp(r'(\d{1,4})\s*(g|gm|ml)\b').firstMatch(t.replaceAll(RegExp(r'100\s*(g|gm|ml)'), ''));
        if (g != null) servingGrams ??= int.tryParse(g.group(1)!);
      }
    }
  }
  final allText = _norm(lines.map((l) => l.text).join(' '));
  servingGrams ??= int.tryParse(
    RegExp(r'serv\w*\s*(size)?\s*[:\-]?\s*(\d{1,4})\s*(g|gm|ml)\b').firstMatch(allText)?.group(2) ?? '',
  );
  if (servingGrams != null && (servingGrams < 1 || servingGrams > 2000)) servingGrams = null;

  // With no headers at all, the first column is taken (usually per 100 g).
  final per100 = per100X != null || servingX == null;
  final columnX = per100X ?? servingX;

  double? energy, protein, carbs, fat;
  for (final row in rows) {
    final t = _norm(row.map((c) => c.text).join(' '));
    final tokens = _numbers(row);
    if (tokens.isEmpty) continue;
    if (energy == null && RegExp(r'energy|calori|kcal').hasMatch(t)) {
      final kcal = tokens.where((n) => n.unit == 'kcal').toList();
      final kj = tokens.where((n) => n.unit == 'kj').toList();
      if (kcal.isNotEmpty) {
        energy = _pick(kcal, columnX);
      } else if (kj.isNotEmpty) {
        energy = _pick(kj, columnX) / 4.184;
      } else if (!t.contains('kj')) {
        energy = _pick(tokens, columnX);
      }
    } else if (protein == null && t.contains('protein')) {
      protein = _pick(tokens, columnX);
    } else if (carbs == null && RegExp(r'carbohydrate|carbs').hasMatch(t)) {
      carbs = _pick(tokens, columnX);
    } else if (fat == null && RegExp(r'\bfat\b|\bfats\b').hasMatch(t) && !RegExp(r'satur|trans|mono|poly|\bsat\b').hasMatch(t)) {
      fat = _pick(tokens, columnX);
    }
  }

  // Values a label can't have (per 100 g) are misreads; drop them.
  double? sane(double? v, double max) => v == null || v < 0 || (per100 && v > max) ? null : v;
  energy = sane(energy, 950);
  protein = sane(protein, 100);
  carbs = sane(carbs, 100);
  fat = sane(fat, 100);

  final macros = [protein, carbs, fat].whereType<double>().length;
  if (energy == null && macros < 3) return null;
  if (energy != null && macros < 2) return null;
  energy ??= (protein! * 4 + carbs! * 4 + fat! * 9);

  return LabelNutrition(
    kcal: energy,
    protein: protein ?? 0,
    carbs: carbs ?? 0,
    fat: fat ?? 0,
    per100: per100,
    servingGrams: servingGrams,
  );
}

class _Num {
  const _Num(this.value, this.x, this.unit);
  final double value;
  final double x;

  /// 'kcal', 'kj' or ''.
  final String unit;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Cells regrouped into table rows (by vertical overlap), each left to right.
List<List<LabelLine>> _rows(List<LabelLine> lines) {
  final sorted = [...lines]..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));
  final rows = <List<LabelLine>>[];
  for (final l in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null) {
      final cy = row.map((c) => c.box.center.dy).reduce((a, b) => a + b) / row.length;
      final h = row.map((c) => c.box.height).reduce((a, b) => a > b ? a : b);
      if ((l.box.center.dy - cy).abs() < 0.5 * (h > l.box.height ? h : l.box.height)) {
        row.add(l);
        continue;
      }
    }
    rows.add([l]);
  }
  for (final r in rows) {
    r.sort((a, b) => a.box.left.compareTo(b.box.left));
  }
  return rows;
}

/// Numbers in a row with their approximate x, skipping percentages (%RDA).
List<_Num> _numbers(List<LabelLine> row) {
  final out = <_Num>[];
  for (final cell in row) {
    // OCR reads "7,1" for 7.1 and often "O" for 0 next to digits.
    final text = cell.text
        .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}')
        .replaceAllMapped(RegExp(r'(?<=\d)[oO]|[oO](?=\d)'), (_) => '0');
    for (final m in RegExp(r'(\d+(?:\.\d+)?)\s*(kcal|kj|cal|%)?', caseSensitive: false).allMatches(text)) {
      final unit = (m.group(2) ?? '').toLowerCase();
      if (unit == '%') continue;
      final v = double.tryParse(m.group(1)!);
      if (v == null) continue;
      final share = text.isEmpty ? 0.5 : (m.start + m.end) / 2 / text.length;
      out.add(_Num(v, cell.box.left + cell.box.width * share, unit == 'cal' ? 'kcal' : unit));
    }
  }
  return out;
}

/// The number in the wanted column (nearest the header), else the first.
double _pick(List<_Num> nums, double? columnX) {
  if (columnX == null) return nums.first.value;
  return (nums.toList()..sort((a, b) => (a.x - columnX).abs().compareTo((b.x - columnX).abs()))).first.value;
}
