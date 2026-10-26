import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/db/providers.dart';
import 'core/db/seed.dart';
import 'core/router/app_router.dart';

const bool _seed = bool.fromEnvironment('SEED');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.open();
  if (_seed) await seedSampleData(db);
  final onboarded = await db.getProfile() != null;

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: CalorieApp(router: createRouter(onboarded: onboarded)),
    ),
  );
}
