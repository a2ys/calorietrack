import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/db/providers.dart';
import 'core/db/seed.dart';
import 'core/router/app_router.dart';
import 'core/utils/sounds.dart';
import 'features/settings/licenses_sheet.dart';

const bool _seed = bool.fromEnvironment('SEED');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Asset credits also appear on Flutter's package license page.
  LicenseRegistry.addLicense(() => Stream.fromIterable([
        for (final (name, use, license, author) in kCredits)
          LicenseEntryWithLineBreaks([name], '$use by $author.\n\nLicense: $license'),
      ]));

  // Loads the sound cues in the background; taps before it finishes are silent.
  Sounds.init();

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
