import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/sounds.dart';
import '../../core/utils/water.dart';

/// Logs [ml] of water on [day] (at the current time of day) and returns the new
/// log's id. Offers undo in a snackbar unless [showUndo] is false: a snackbar
/// from inside a sheet sits behind it, so the water sheet shows its own undo.
Future<int> logWater(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
  int ml, {
  bool showUndo = true,
}) async {
  final db = ref.read(databaseProvider);
  final p = context.palette;
  final now = DateTime.now();
  final id = await db.addWater(
    ml,
    DateTime(day.year, day.month, day.day, now.hour, now.minute, now.second),
  );
  Haptics.success(Sfx.water);
  if (!showUndo || !context.mounted) return id;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      clipBehavior: Clip.none, // see snackBarTheme
      duration: const Duration(seconds: 3),
      content: Text('Added ${formatWater(ml)} of water'),
      action: SnackBarAction(
        label: 'Undo',
        textColor: p.onInk,
        onPressed: () => db.deleteWater(id),
      ),
    ));
  return id;
}
