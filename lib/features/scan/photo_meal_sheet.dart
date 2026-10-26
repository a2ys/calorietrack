import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/photo_meal_service.dart';
import '../../core/db/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../meals/meal_detail_sheet.dart';

/// Takes or picks a photo of a meal, reads it and opens it ready to log.
/// Completes with `true` if a meal was logged.
Future<bool> logMealFromPhoto(BuildContext context, AppDatabase db, {DateTime? day}) async {
  final off = await PhotoMealService.offReason();
  if (!context.mounted) return false;
  if (off != null) {
    Haptics.warning();
    await showAppSheet<void>(context, initialSize: 0.36, builder: (_) => _OffSheet(message: off));
    return false;
  }

  final source = await showAppSheet<ImageSource>(
    context,
    initialSize: 0.36,
    builder: (_) => const _SourceSheet(),
  );
  if (source == null) return false;

  final XFile? file;
  try {
    // Plenty for the model to read a plate; keeps the upload small.
    file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
  } on Exception {
    return false;
  }
  if (file == null) return false;
  final photo = await file.readAsBytes();
  final service = PhotoMealService(installId: await db.installId());
  if (!context.mounted) return false;

  final logged = await showAppSheet<bool>(
    context,
    initialSize: 0.92,
    maxSize: 0.96,
    builder: (_) => PhotoMealSheet(photo: photo, service: service, day: day),
  );
  return logged == true;
}

/// Photo logging is switched off on the server.
class _OffSheet extends StatelessWidget {
  const _OffSheet({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return SheetScaffold(
      title: 'Photo logging is on a break',
      trailing: const PopIn(child: EmojiTile('💸', size: 52, radius: 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: t.body.copyWith(color: p.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Got it', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Log from a photo',
      subtitle: 'Snap your plate and we’ll work out what’s on it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: 'Take a photo',
            icon: AppIcons.camera,
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Choose from gallery',
            icon: AppIcons.image,
            style: AppButtonStyle.outline,
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

/// Reads [photo] and shows the meal it found, with portion, totals, health
/// score and items, ready to log. "Fix results" re-reads it with the user's
/// correction.
class PhotoMealSheet extends StatefulWidget {
  const PhotoMealSheet({super.key, required this.photo, required this.service, this.day});

  final Uint8List photo;
  final PhotoMealService service;
  final DateTime? day;

  @override
  State<PhotoMealSheet> createState() => _PhotoMealSheetState();
}

class _PhotoMealSheetState extends State<PhotoMealSheet> {
  /// Null while reading.
  PhotoMealResult? _result;

  /// Bumped per answer so the meal sheet starts fresh (portion back to 1×).
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read({String? note}) async {
    setState(() => _result = null);
    final result = await widget.service.analyze(widget.photo, at: DateTime.now(), note: note);
    if (!mounted) return;
    switch (result) {
      case PhotoMealFound():
        Haptics.success();
      case PhotoMealNotFood() || PhotoMealFailed():
        Haptics.warning();
    }
    setState(() {
      _result = result;
      _round++;
    });
  }

  Future<void> _fix() async {
    final note = await showAppDialog<String>(context, builder: (_) => const _FixDialog());
    if (note != null && note.trim().isNotEmpty) _read(note: note);
  }

  @override
  Widget build(BuildContext context) {
    // Switched outright: each state is a sheet scroll view on the sheet's one
    // controller, so two can't be on screen at once.
    return switch (_result) {
        null => _Reading(key: const ValueKey('reading'), photo: widget.photo),
        PhotoMealFound(:final meal) => MealDetailSheet(
            key: ValueKey('meal-$_round'),
            name: meal.dish,
            emoji: meal.emoji,
            items: meal.items,
            photo: widget.photo,
            healthScore: meal.healthScore,
            mealType: meal.mealType,
            day: widget.day,
            onFix: _fix,
          ),
        PhotoMealNotFood() => _Problem(
            key: ValueKey('none-$_round'),
            photo: widget.photo,
            title: 'No food here',
            message: 'We couldn’t spot any food or drink in this photo. Try one with the plate in view.',
            onRetry: null,
          ),
        PhotoMealFailed(:final message) => _Problem(
            key: ValueKey('failed-$_round'),
            photo: widget.photo,
            title: 'Couldn’t read that',
            message: message,
            onRetry: () {
              Haptics.tap();
              _read();
            },
          ),
    };
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.photo, this.dimmed = false});
  final Uint8List photo;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: AppRadii.card,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: AnimatedOpacity(
            opacity: dimmed ? 0.6 : 1,
            duration: AppMotion.normal,
            child: Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
      );
}

class _Reading extends StatelessWidget {
  const _Reading({super.key, required this.photo});
  final Uint8List photo;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return SheetScaffold(
      title: 'Reading your plate…',
      subtitle: 'Usually takes a few seconds.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Photo(photo: photo, dimmed: true),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: AppRadii.chip,
            child: LinearProgressIndicator(minHeight: 4, color: p.ink, backgroundColor: p.track),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Spotting each food and estimating portions', style: t.label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({
    super.key,
    required this.photo,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final Uint8List photo;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return SheetScaffold(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Photo(photo: photo, dimmed: true),
          const SizedBox(height: AppSpacing.lg),
          Text(message, style: t.body.copyWith(color: p.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          if (onRetry != null) ...[
            AppButton(label: 'Try again', onPressed: onRetry),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'Close',
            style: onRetry == null ? AppButtonStyle.primary : AppButtonStyle.outline,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// Asks what the estimate got wrong; completes with the correction.
class _FixDialog extends StatefulWidget {
  const _FixDialog();

  @override
  State<_FixDialog> createState() => _FixDialogState();
}

class _FixDialogState extends State<_FixDialog> {
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      insetPadding: const EdgeInsets.all(AppSpacing.screen),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What did we get wrong?', style: t.heading),
            const SizedBox(height: AppSpacing.sm),
            Text('Say what’s different and we’ll read the photo again.', style: t.body.copyWith(color: p.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _note,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: t.bodyStrong,
              decoration: const InputDecoration(hintText: 'e.g. It’s paneer, not tofu. 2 rotis, not 1.', counterText: ''),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Read it again',
              onPressed: _note.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_note.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Cancel',
              style: AppButtonStyle.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
