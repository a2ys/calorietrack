import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/photo_meal_service.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/utils/greeting.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/sounds.dart';
import '../../core/utils/units.dart';
import '../../core/utils/water.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/body_stats_picker.dart';
import '../../core/widgets/choice_card.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/segmented_pills.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../../core/widgets/staggered_entrance.dart';
import '../../core/widgets/target_editor.dart';
import '../water/water_widgets.dart';
import '../../core/widgets/app_icon.dart';
import 'licenses_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final p = context.palette;
    final profile = ref.watch(profileProvider).value;
    final prefs = readPrefs(ref);
    final db = ref.read(databaseProvider);

    if (profile == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.lg,
          AppSpacing.screen,
          AppSpacing.huge,
        ),
        children: [
          Text('Settings', style: t.title),
          const SizedBox(height: AppSpacing.xl),

          // ------------------------------------------------------ profile
          StaggeredEntrance(
            index: 0,
            child: AppCard(
              onTap: () => showAppSheet<void>(
                context,
                initialSize: 0.78,
                builder: (_) => _ProfileSheet(prefs: prefs),
              ),
              child: Row(
                children: [
                  EmojiTile(prefs.avatar, size: 64, radius: 32),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prefs.name.trim().isEmpty ? 'Add your name' : firstName(prefs.name),
                          style: t.heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          prefs.name.trim().isEmpty
                              ? 'So we can say hello properly'
                              : '${profile.goal.label} · ${profile.calorieTarget} kcal',
                          style: t.label,
                        ),
                      ],
                    ),
                  ),
                  AppIcon(AppIcons.caretRight, size: 16, color: p.textTertiary),
                ],
              ),
            ),
          ),

          // -------------------------------------------------------- goals
          const _SectionLabel('Your plan'),
          _Group(children: [
            _Row(
              emoji: AppEmoji.calories,
              title: '${profile.calorieTarget} kcal a day',
              subtitle:
                  'Protein ${profile.proteinTarget}g · Carbs ${profile.carbsTarget}g · Fat ${profile.fatTarget}g',
              chevron: true,
              onTap: () => showAppSheet<void>(
                context,
                initialSize: 0.88,
                builder: (_) => _TargetSheet(profile: profile),
              ),
            ),
            _Row(
              emoji: '🎯',
              title: profile.goal.label,
              subtitle:
                  '${Units.formatWeight(profile.weightKg, prefs.weightUnit)} · ${Units.formatHeight(profile.heightCm, prefs.heightUnit)} · ${profile.age} years',
              chevron: true,
              onTap: () => showAppSheet<void>(
                context,
                initialSize: 0.94,
                builder: (_) => _BodySheet(profile: profile, prefs: prefs),
              ),
            ),
          ]),

          // ----------------------------------------------------- Today view
          const _SectionLabel('Today screen'),
          _Group(children: [
            _Row(
              emoji: '👀',
              title: 'Big number shows',
              bottom: SegmentedPills<CalorieView>(
                compact: true,
                options: CalorieView.values,
                labelOf: (v) => v == CalorieView.left ? 'Calories left' : 'Calories eaten',
                selected: prefs.calorieView,
                onChanged: (v) => db.setPref(PrefKeys.calorieView, v.name),
              ),
            ),
            _Row(
              emoji: '🥩',
              title: 'Show macro rings',
              subtitle: 'Protein, carbs and fat under the calories',
              trailing: _Switch(
                value: prefs.showMacros,
                onChanged: (v) => db.setPref(PrefKeys.showMacros, v ? '1' : '0'),
              ),
            ),
          ]),

          // ----------------------------------------------------- water
          const _SectionLabel('Water'),
          _Group(children: [
            _Row(
              emoji: AppEmoji.water,
              title: 'Daily goal',
              subtitle: 'About ${(prefs.waterGoalMl / prefs.waterGlassMl).round()} glasses of ${formatWater(prefs.waterGlassMl)}',
              trailing: WaterGoalStepper(
                goalMl: prefs.waterGoalMl,
                onChanged: (v) => db.setPref(PrefKeys.waterGoal, '$v'),
              ),
            ),
            _Row(
              emoji: '🥛',
              title: 'Quick-add size',
              subtitle: 'The + button on the Today card',
              bottom: SegmentedPills<int>(
                compact: true,
                options: WaterLimits.glassSizes,
                labelOf: (ml) => '$ml',
                selected: WaterLimits.glassSizes.contains(prefs.waterGlassMl)
                    ? prefs.waterGlassMl
                    : WaterLimits.glassSizes[2],
                onChanged: (ml) => db.setPref(PrefKeys.waterGlass, '$ml'),
              ),
            ),
            _Row(
              emoji: '📌',
              title: 'Show on Today',
              trailing: _Switch(
                value: prefs.showWater,
                onChanged: (v) => db.setPref(PrefKeys.showWater, v ? '1' : '0'),
              ),
            ),
          ]),

          // ------------------------------------------------------ feel
          const _SectionLabel('Feel'),
          _Group(children: [
            _Row(
              emoji: '🎨',
              title: 'Appearance',
              bottom: SegmentedPills<String>(
                compact: true,
                options: const ['light', 'dark', 'system'],
                labelOf: (m) => switch (m) {
                  'light' => 'Light',
                  'dark' => 'Dark',
                  _ => 'Auto',
                },
                selected: prefs.themeMode,
                onChanged: (m) => db.setPref(PrefKeys.theme, m),
              ),
            ),
            _Row(
              emoji: '📳',
              title: 'Haptics',
              subtitle: 'How strongly taps, logs and saves feel',
              bottom: _HapticSlider(
                level: prefs.hapticLevel,
                onSaved: (v) => db.setPref(PrefKeys.hapticLevel, '$v'),
              ),
            ),
            _Row(
              emoji: '🔊',
              title: 'Sounds',
              subtitle: 'Muted in silent mode',
              trailing: _Switch(
                value: prefs.sounds,
                onChanged: (v) {
                  Sounds.enabled = v;
                  // Turning sounds on plays one, so you hear what you chose.
                  if (v) Sounds.play(Sfx.success);
                  db.setPref(PrefKeys.sounds, v ? '1' : '0');
                },
              ),
            ),
          ]),

          // ------------------------------------------------------ units
          const _SectionLabel('Units'),
          _Group(children: [
            _Row(
              emoji: '⚖️',
              title: 'Weight',
              bottom: SegmentedPills<WeightUnit>(
                compact: true,
                options: WeightUnit.values,
                labelOf: (u) => u.label,
                selected: prefs.weightUnit,
                onChanged: (u) => db.setPref(PrefKeys.weightUnit, u.name),
              ),
            ),
            _Row(
              emoji: '📏',
              title: 'Height',
              bottom: SegmentedPills<HeightUnit>(
                compact: true,
                options: HeightUnit.values,
                labelOf: (u) => u.label,
                selected: prefs.heightUnit,
                onChanged: (u) => db.setPref(PrefKeys.heightUnit, u.name),
              ),
            ),
          ]),

          // ------------------------------------------------------ about
          const _SectionLabel('About'),
          _Group(children: [
            _Row(
              emoji: '📜',
              title: 'Open-source licenses',
              subtitle: 'Icons, emoji, font, sounds, food data',
              chevron: true,
              onTap: () => showLicensesSheet(context),
            ),
          ]),

          // ------------------------------------------------------- data
          const _SectionLabel('Data'),
          PressScale(
            onTap: () => _confirmReset(context, ref),
            child: AppCard(
              shadow: false,
              child: Row(
                children: [
                  AppIcon(AppIcons.trash, size: 20, color: p.accent),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Erase all data',
                      style: t.bodyStrong.copyWith(color: p.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Everything is stored on this device. No account, no cloud. Scanning a barcode sends only its number to Open Food Facts.'
            '${PhotoMealService.isConfigured ? ' Photos you log are sent to Claude (Anthropic) to estimate nutrition.' : ''}',
            style: t.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Made with ', style: t.caption),
              const Emoji(AppEmoji.fat, size: 13),
              Text(' for eating well', style: t.caption),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (_) => const ConfirmDialog(
        title: 'Erase everything?',
        message:
            'All logged foods, saved foods, meals and your profile will be deleted from this device. This cannot be undone.',
        confirmLabel: 'Erase',
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteEverything();
    Haptics.warning();
    if (context.mounted) context.go(Routes.onboarding);
  }
}

// -------------------------------------------------------- building blocks

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.xxl,
          bottom: AppSpacing.sm,
          left: AppSpacing.xs,
        ),
        child: Text(text.toUpperCase(), style: context.type.caption.copyWith(letterSpacing: 0.8)),
      );
}

/// Rounded card that stacks rows with hairline dividers, iOS "grouped" style.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, indent: AppSpacing.lg + 40 + AppSpacing.md, color: p.border),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.emoji,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.chevron = false,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;

    final row = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EmojiTile(emoji, size: 40, radius: 12),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.bodyStrong),
                    if (subtitle != null) Text(subtitle!, style: t.label),
                  ],
                ),
              ),
              ?trailing,
              if (chevron) AppIcon(AppIcons.caretRight, size: 16, color: p.textTertiary),
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: AppSpacing.md),
            bottom!,
          ],
        ],
      ),
    );

    return onTap == null ? row : PressScale(scale: 0.99, onTap: onTap, child: row);
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // The off thumb must stand out from the track in both themes.
    final light = Theme.of(context).brightness == Brightness.light;
    return CupertinoSwitch(
      value: value,
      activeTrackColor: p.ink,
      inactiveTrackColor: p.track,
      thumbColor: p.surface,
      inactiveThumbColor: light ? Colors.white : p.textSecondary,
      onChanged: (v) {
        Haptics.tap();
        onChanged(v);
      },
    );
  }
}

/// 0-100% strength slider. Dragging previews the feel at each 5% step; the
/// value is saved when the finger lifts. 0% turns haptics off.
class _HapticSlider extends StatefulWidget {
  const _HapticSlider({required this.level, required this.onSaved});

  final int level;
  final ValueChanged<int> onSaved;

  @override
  State<_HapticSlider> createState() => _HapticSliderState();
}

class _HapticSliderState extends State<_HapticSlider> {
  late double _value = widget.level.toDouble();
  bool _dragging = false;

  static String _word(int v) => v == 0
      ? 'Off'
      : v < 30
          ? 'Soft'
          : v < 60
              ? 'Medium'
              : v < 85
                  ? 'Strong'
                  : 'Max';

  @override
  void didUpdateWidget(_HapticSlider old) {
    super.didUpdateWidget(old);
    if (!_dragging) _value = widget.level.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final v = _value.round();

    return Column(
      children: [
        Row(
          children: [
            Text(_word(v), style: t.label),
            const Spacer(),
            Text('$v%', style: t.numeralS),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: p.ink,
            inactiveTrackColor: p.track,
            thumbColor: p.ink,
            overlayColor: p.ink.withValues(alpha: 0.08),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 0, pressedElevation: 0),
            trackShape: const RoundedRectSliderTrackShape(),
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            value: _value,
            min: 0,
            max: 100,
            divisions: 20,
            onChangeStart: (_) => _dragging = true,
            onChanged: (next) {
              final changed = next.round() != _value.round();
              setState(() => _value = next);
              if (changed) {
                // Apply right away so the tick you feel is the new strength.
                Haptics.level = next.round();
                Haptics.tap();
              }
            },
            onChangeEnd: (next) {
              _dragging = false;
              Haptics.level = next.round();
              Haptics.success();
              widget.onSaved(next.round());
            },
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- sheets

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet({required this.prefs});
  final AppPrefs prefs;

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  late final _name = TextEditingController(text: widget.prefs.name);
  late String _avatar = widget.prefs.avatar;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await db.setPref(PrefKeys.name, _name.text.trim());
    await db.setPref(PrefKeys.avatar, _avatar);
    Haptics.success();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;

    return SheetScaffold(
      title: 'Your profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PopIn(
              key: ValueKey(_avatar),
              from: 0.75,
              child: EmojiTile(_avatar, size: 88, radius: 44),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('What should we call you?', style: t.label),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: t.bodyStrong,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Pick an avatar', style: t.label),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final e in AppEmoji.avatars)
                PressScale(
                  scale: 0.9,
                  onTap: () {
                    if (e != _avatar) Haptics.tap();
                    setState(() => _avatar = e);
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.spring,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: e == _avatar ? p.ink : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: EmojiTile(e, size: 52, radius: 26),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(label: 'Save', onPressed: _save),
        ],
      ),
    );
  }
}

class _TargetSheet extends ConsumerStatefulWidget {
  const _TargetSheet({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  late MacroTargets _value = MacroTargets(
    calories: widget.profile.calorieTarget,
    proteinG: widget.profile.proteinTarget,
    carbsG: widget.profile.carbsTarget,
    fatG: widget.profile.fatTarget,
  );

  void _recalculate() {
    final p = widget.profile;
    Haptics.tap();
    setState(() {
      _value = CalorieCalculator.targets(
        goal: p.goal,
        sex: p.sex,
        age: p.age,
        heightCm: p.heightCm,
        weightKg: p.weightKg,
        activity: p.activity,
      );
    });
  }

  Future<void> _save() async {
    final p = widget.profile;
    await ref.read(databaseProvider).saveProfile(UserProfilesCompanion.insert(
          goal: p.goal,
          sex: p.sex,
          age: p.age,
          heightCm: p.heightCm,
          weightKg: p.weightKg,
          activity: p.activity,
          calorieTarget: _value.calories,
          proteinTarget: _value.proteinG,
          carbsTarget: _value.carbsG,
          fatTarget: _value.fatG,
        ));
    Haptics.success();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Daily target',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TargetEditor(
            value: _value,
            goal: widget.profile.goal,
            weightKg: widget.profile.weightKg,
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Recalculate from my stats',
            style: AppButtonStyle.outline,
            onPressed: _recalculate,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Save', onPressed: _save),
        ],
      ),
    );
  }
}

class _BodySheet extends ConsumerStatefulWidget {
  const _BodySheet({required this.profile, required this.prefs});
  final UserProfile profile;
  final AppPrefs prefs;

  @override
  ConsumerState<_BodySheet> createState() => _BodySheetState();
}

class _BodySheetState extends ConsumerState<_BodySheet> {
  late Goal _goal = widget.profile.goal;
  late Sex _sex = widget.profile.sex;
  late int _age = widget.profile.age;
  late double _heightCm = widget.profile.heightCm;
  late double _weightKg = widget.profile.weightKg;
  late ActivityLevel _activity = widget.profile.activity;

  bool get _unchanged {
    final p = widget.profile;
    return _goal == p.goal &&
        _sex == p.sex &&
        _age == p.age &&
        _heightCm == p.heightCm &&
        _weightKg == p.weightKg &&
        _activity == p.activity;
  }

  Future<void> _save() async {
    // Nothing changed: keep any hand-tuned targets instead of recalculating.
    if (_unchanged) {
      Navigator.of(context).pop();
      return;
    }
    final t = CalorieCalculator.targets(
      goal: _goal,
      sex: _sex,
      age: _age,
      heightCm: _heightCm,
      weightKg: _weightKg,
      activity: _activity,
    );
    await ref.read(databaseProvider).saveProfile(UserProfilesCompanion.insert(
          id: const Value(AppDatabase.profileId),
          goal: _goal,
          sex: _sex,
          age: _age,
          heightCm: _heightCm,
          weightKg: _weightKg,
          activity: _activity,
          calorieTarget: t.calories,
          proteinTarget: t.proteinG,
          carbsTarget: t.carbsG,
          fatTarget: t.fatG,
        ));
    Haptics.success();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return SheetScaffold(
      title: 'Body & goal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Goal', style: t.label),
          const SizedBox(height: AppSpacing.sm),
          SegmentedPills<Goal>(
            compact: true,
            options: Goal.values,
            labelOf: (g) => g.name[0].toUpperCase() + g.name.substring(1),
            selected: _goal,
            onChanged: (g) => setState(() => _goal = g),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Sex', style: t.label),
          const SizedBox(height: AppSpacing.sm),
          SegmentedPills<Sex>(
            compact: true,
            options: Sex.values,
            labelOf: (s) => s.label,
            selected: _sex,
            onChanged: (s) => setState(() => _sex = s),
          ),
          const SizedBox(height: AppSpacing.lg),
          BodyStatsPicker(
            age: _age,
            heightCm: _heightCm,
            weightKg: _weightKg,
            heightUnit: widget.prefs.heightUnit,
            weightUnit: widget.prefs.weightUnit,
            onAge: (v) => _age = v,
            onHeightCm: (v) => _heightCm = v,
            onWeightKg: (v) => _weightKg = v,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Activity', style: t.label),
          const SizedBox(height: AppSpacing.sm),
          for (final level in ActivityLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ChoiceCard(
                title: level.label,
                hint: level.hint,
                selected: _activity == level,
                onTap: () => setState(() => _activity = level),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text('Saving recalculates your daily target.', style: t.caption, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Save', onPressed: _save),
        ],
      ),
    );
  }
}
