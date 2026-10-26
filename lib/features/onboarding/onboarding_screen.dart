import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/body_stats_picker.dart';
import '../../core/widgets/choice_card.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/segmented_pills.dart';
import '../../core/widgets/staggered_entrance.dart';
import '../../core/widgets/target_editor.dart';
import '../../core/widgets/app_icon.dart';

enum _Step { welcome, name, goal, sex, body, activity, result }

enum _UnitSystem {
  metric('Metric'),
  imperial('Imperial');

  const _UnitSystem(this.label);
  final String label;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _defaultAge = 25;
  static const double _defaultHeightCm = 170;
  static const double _defaultWeightKg = 70;

  final _pages = PageController();
  final _nameCtl = TextEditingController();
  _Step _step = _Step.welcome;
  String _avatar = AppPrefs.defaultAvatar;

  Goal? _goal;
  Sex? _sex;
  int _age = _defaultAge;
  double _heightCm = _defaultHeightCm;
  double _weightKg = _defaultWeightKg;
  ActivityLevel _activity = ActivityLevel.moderate;
  _UnitSystem _units = _UnitSystem.metric;
  MacroTargets? _targets;

  @override
  void initState() {
    super.initState();
    _nameCtl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _pages.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        _Step.goal => _goal != null,
        _Step.sex => _sex != null,
        _ => true,
      };

  Future<void> _go(_Step step) async {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    await _pages.animateToPage(
      step.index,
      duration: AppMotion.sheetIn,
      curve: AppMotion.drawer,
    );
  }

  void _next() {
    if (_step == _Step.result) {
      _finish();
      return;
    }
    final next = _Step.values[_step.index + 1];
    if (next == _Step.result) {
      _targets = CalorieCalculator.targets(
        goal: _goal!,
        sex: _sex!,
        age: _age,
        heightCm: _heightCm,
        weightKg: _weightKg,
        activity: _activity,
      );
    }
    _go(next);
  }

  void _back() {
    if (_step.index > 0) _go(_Step.values[_step.index - 1]);
  }

  Future<void> _setUnits(_UnitSystem system) async {
    setState(() => _units = system);
    final db = ref.read(databaseProvider);
    await db.setPref(
      PrefKeys.weightUnit,
      (system == _UnitSystem.metric ? WeightUnit.kg : WeightUnit.lb).name,
    );
    await db.setPref(
      PrefKeys.heightUnit,
      (system == _UnitSystem.metric ? HeightUnit.cm : HeightUnit.ft).name,
    );
  }

  Future<void> _finish() async {
    final t = _targets!;
    final db = ref.read(databaseProvider);
    await db.setPref(PrefKeys.name, _nameCtl.text.trim());
    await db.setPref(PrefKeys.avatar, _avatar);
    await db.saveProfile(UserProfilesCompanion.insert(
          id: const Value(AppDatabase.profileId),
          goal: _goal!,
          sex: _sex!,
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
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = _step == _Step.welcome;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                0,
              ),
              child: SizedBox(
                height: AppSizes.iconTile,
                child: Row(
                  children: [
                    AnimatedOpacity(
                      duration: AppMotion.fast,
                      opacity: first ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: first,
                        child: PressScale(
                          onTap: _back,
                          child: Container(
                            width: AppSizes.iconTile,
                            height: AppSizes.iconTile,
                            decoration: BoxDecoration(
                              color: p.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.border),
                            ),
                            child: AppIcon(AppIcons.caretLeft, size: 16, color: p.textPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: _ProgressBar(value: _step.index / (_Step.values.length - 1))),
                    const SizedBox(width: AppSizes.iconTile + AppSpacing.lg),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _welcome(context),
                  _nameStep(),
                  _goalStep(),
                  _sexStep(),
                  _bodyStep(),
                  _activityStep(),
                  _resultStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: switch (_step) {
                  _Step.welcome => 'Get started',
                  _Step.name => _nameCtl.text.trim().isEmpty ? 'Skip for now' : 'Continue',
                  _Step.result => 'Start tracking',
                  _ => 'Continue',
                },
                onPressed: _canContinue ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- steps

  Widget _welcome(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return _StepBody(
      centered: true,
      children: [
        PopIn(
          delay: const Duration(milliseconds: 80),
          from: 0.4,
          child: _Floating(
            child: Container(
              width: AppSizes.heroRing + 16,
              height: AppSizes.heroRing + 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: p.border),
                boxShadow: p.shadows,
              ),
              child: const Emoji(AppEmoji.welcome, size: 64),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Text('Calorie tracking,\nmade simple.', textAlign: TextAlign.center, style: t.title.copyWith(fontSize: 34)),
        const SizedBox(height: AppSpacing.md),
        Text(
          'A few quick questions and we will set your daily target.',
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            PopIn(delay: Duration(milliseconds: 420), child: Emoji('🍛', size: 24)),
            PopIn(delay: Duration(milliseconds: 480), child: Emoji('🥗', size: 24)),
            PopIn(delay: Duration(milliseconds: 540), child: Emoji('🍳', size: 24)),
            PopIn(delay: Duration(milliseconds: 600), child: Emoji('🍎', size: 24)),
            PopIn(delay: Duration(milliseconds: 660), child: Emoji('🥤', size: 24)),
          ],
        ),
      ],
    );
  }

  Widget _nameStep() {
    final p = context.palette;
    final t = context.type;
    return _StepBody(
      title: 'What should we call you?',
      subtitle: 'Just a first name. It stays on this device.',
      children: [
        Center(
          child: PopIn(
            key: ValueKey(_avatar),
            from: 0.7,
            child: EmojiTile(_avatar, size: 96, radius: 48),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _nameCtl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          style: t.heading,
          decoration: const InputDecoration(hintText: 'Your name'),
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Pick an avatar', style: t.label, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
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
                  child: EmojiTile(e, size: 44, radius: 22),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _goalStep() => _StepBody(
        title: 'What is your goal?',
        subtitle: 'We will tune your daily calories to match.',
        children: [
          for (final (goal, emoji) in [
            (Goal.lose, '🔥'),
            (Goal.maintain, '⚖️'),
            (Goal.gain, '💪'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ChoiceCard(
                emoji: emoji,
                title: goal.label,
                hint: goal.hint,
                selected: _goal == goal,
                onTap: () => setState(() => _goal = goal),
              ),
            ),
        ],
      );

  Widget _sexStep() => _StepBody(
        title: 'What is your sex?',
        subtitle: 'Used only in the calorie formula (Mifflin-St Jeor).',
        children: [
          for (final (sex, emoji) in [(Sex.male, '🙋‍♂️'), (Sex.female, '🙋‍♀️')])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ChoiceCard(
                emoji: emoji,
                title: sex.label,
                selected: _sex == sex,
                onTap: () => setState(() => _sex = sex),
              ),
            ),
        ],
      );

  Widget _bodyStep() => _StepBody(
        title: 'About you',
        subtitle: 'Scroll each wheel to set your numbers.',
        children: [
          SegmentedPills<_UnitSystem>(
            compact: true,
            options: _UnitSystem.values,
            labelOf: (u) => u.label,
            selected: _units,
            onChanged: _setUnits,
          ),
          const SizedBox(height: AppSpacing.xl),
          BodyStatsPicker(
            age: _age,
            heightCm: _heightCm,
            weightKg: _weightKg,
            heightUnit: _units == _UnitSystem.metric ? HeightUnit.cm : HeightUnit.ft,
            weightUnit: _units == _UnitSystem.metric ? WeightUnit.kg : WeightUnit.lb,
            onAge: (v) => _age = v,
            onHeightCm: (v) => _heightCm = v,
            onWeightKg: (v) => _weightKg = v,
          ),
        ],
      );

  Widget _activityStep() => _StepBody(
        title: 'How active are you?',
        subtitle: 'Think of a typical week.',
        children: [
          for (final level in ActivityLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: ChoiceCard(
                title: level.label,
                hint: level.hint,
                selected: _activity == level,
                onTap: () => setState(() => _activity = level),
              ),
            ),
        ],
      );

  Widget _resultStep() => _StepBody(
        title: _nameCtl.text.trim().isEmpty ? 'Your daily target' : 'Your target, ${_nameCtl.text.trim().split(' ').first}',
        subtitle: 'Fine-tune it any time. You can change it later in Settings.',
        children: [
          if (_targets != null)
            TargetEditor(
              value: _targets!,
              goal: _goal ?? Goal.maintain,
              weightKg: _weightKg,
              onChanged: (v) => setState(() => _targets = v),
            ),
        ],
      );
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    this.title,
    this.subtitle,
    required this.children,
    this.centered = false,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final content = Column(
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          StaggeredEntrance(
            index: 0,
            child: Column(
              crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Text(title!, style: t.title),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: t.label),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        for (var i = 0; i < children.length; i++)
          StaggeredEntrance(index: i + 1, child: children[i]),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.xxl,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - AppSpacing.xxl - AppSpacing.lg,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  static const double _height = 6;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: AppRadii.chip,
      child: SizedBox(
        height: _height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: AppMotion.slow,
          curve: AppMotion.easeOut,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            backgroundColor: p.track,
            valueColor: AlwaysStoppedAnimation(p.ink),
            minHeight: _height,
          ),
        ),
      ),
    );
  }
}


/// Gentle idle bob (3 px, ~2.6 s) so the welcome screen feels alive.
class _Floating extends StatefulWidget {
  const _Floating({required this.child});
  final Widget child;

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -3 + 6 * curved.value),
        child: child,
      ),
    );
  }
}
