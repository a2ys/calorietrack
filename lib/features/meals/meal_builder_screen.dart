import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/food.dart';
import '../../core/db/database.dart';
import '../../core/db/models.dart';
import '../../core/db/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/macro_icons.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/rounded_dismissible.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../add_food/add_food_sheet.dart';
import '../../core/widgets/app_icon.dart';

/// Create or edit a saved meal. Pass [meal] to edit.
class MealBuilderScreen extends ConsumerStatefulWidget {
  const MealBuilderScreen({super.key, this.meal});

  final SavedMeal? meal;

  @override
  ConsumerState<MealBuilderScreen> createState() => _MealBuilderScreenState();
}

class _MealBuilderScreenState extends ConsumerState<MealBuilderScreen> {
  late final _name = TextEditingController(text: widget.meal?.name);
  late String _emoji = widget.meal?.emoji ?? '🍛';
  late final List<MealItem> _items = [...?widget.meal?.items];
  bool _saving = false;

  bool get _editing => widget.meal != null;

  /// Anything the user would lose by leaving now.
  bool get _dirty {
    final m = widget.meal;
    if (m == null) return _name.text.trim().isNotEmpty || _items.isNotEmpty;
    return _name.text.trim() != m.name ||
        _emoji != m.emoji ||
        _items.length != m.items.length ||
        Iterable.generate(_items.length)
            .any((i) => _items[i].name != m.items[i].name || _items[i].qty != m.items[i].qty);
  }

  /// Back button, edge swipe or the close button: ask before throwing work
  /// away, never on a clean screen.
  Future<void> _leave() async {
    if (_dirty && !_saving) {
      final discard = await showAppDialog<bool>(
        context,
        builder: (_) => ConfirmDialog(
          title: _editing ? 'Discard changes?' : 'Discard this meal?',
          message: _editing ? 'Your edits to this meal won’t be saved.' : 'What you’ve added so far won’t be saved.',
          confirmLabel: 'Discard',
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    // Rebuild with canPop: true first, or PopScope would block this pop too.
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  bool _leaving = false;
  bool get _valid => _name.text.trim().isNotEmpty && _items.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _addItem(Food food, double qty) {
    setState(() {
      final i = _items.indexWhere((m) => m.name == food.name && m.serving == food.serving);
      if (i >= 0) {
        _items[i] = _items[i].withQty(_items[i].qty + qty);
      } else {
        _items.add(food.toMealItem(qty));
      }
    });
  }

  /// The picker's "−": takes [qty] servings of [food] back out.
  void _unpick(Food food, double qty) {
    final i = _items.indexWhere((m) => m.name == food.name && m.serving == food.serving);
    if (i < 0) return;
    setState(() {
      final left = _items[i].qty - qty;
      if (left <= 0) {
        _items.removeAt(i);
      } else {
        _items[i] = _items[i].withQty(left);
      }
    });
  }

  void _setQty(int i, double qty) {
    final next = qty.clamp(0.5, 30.0);
    if (next == _items[i].qty) return;
    Haptics.tap();
    setState(() => _items[i] = _items[i].withQty(next));
  }

  void _remove(int i) {
    final removed = _items[i];
    setState(() => _items.removeAt(i));
    Haptics.medium();
    final p = context.palette;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        clipBehavior: Clip.none, // see snackBarTheme
        content: Text('Removed ${removed.name}'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: p.onInk,
          onPressed: () => setState(() => _items.insert(i.clamp(0, _items.length), removed)),
        ),
      ));
  }

  Future<void> _pickEmoji() async {
    final picked = await showAppSheet<String>(
      context,
      initialSize: 0.52,
      builder: (_) => const _EmojiPickerSheet(),
    );
    if (picked != null && picked != _emoji) setState(() => _emoji = picked);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final name = _name.text.trim();
    final existing = widget.meal;
    if (existing == null) {
      await db.addSavedMeal(name: name, emoji: _emoji, items: _items);
    } else {
      await db.updateSavedMeal(existing, name: name, emoji: _emoji, items: _items);
    }
    Haptics.success();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final total = sumMealItems(_items);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: !_dirty || _saving || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
      body: SafeArea(
        bottom: false,
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
                    PressScale(
                      semanticLabel: 'Close',
                      onTap: _leave,
                      child: Container(
                        width: AppSizes.iconTile,
                        height: AppSizes.iconTile,
                        decoration: BoxDecoration(
                          color: p.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.border),
                        ),
                        child: AppIcon(AppIcons.close, size: 16, color: p.textPrimary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _editing ? 'Edit meal' : 'New meal',
                        textAlign: TextAlign.center,
                        style: t.bodyStrong,
                      ),
                    ),
                    const SizedBox(width: AppSizes.iconTile),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.xl,
                  AppSpacing.screen,
                  AppSpacing.xxl,
                ),
                children: [
                  Row(
                    children: [
                      PressScale(
                        scale: 0.92,
                        onTap: _pickEmoji,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            PopIn(
                              key: ValueKey(_emoji),
                              from: 0.7,
                              child: EmojiTile(_emoji, size: 76, radius: 24),
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: p.ink,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: p.background, width: 2),
                                ),
                                child: AppIcon(AppIcons.pencil, size: 12, color: p.onInk),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          style: t.heading,
                          decoration: const InputDecoration(hintText: 'Name your meal'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    children: [
                      Expanded(child: Text('Ingredients', style: t.heading)),
                      if (_items.isNotEmpty)
                        Text('${_items.length}', style: t.label),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AnimatedSize(
                    duration: AppMotion.normal,
                    curve: AppMotion.spring,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          _AppearOnce(
                            key: ValueKey('appear-${_items[i].name}-${_items[i].serving}'),
                            child: _IngredientRow(
                              key: ValueKey('${_items[i].name}-${_items[i].serving}'),
                              item: _items[i],
                              onQty: (q) => _setQty(i, q),
                              onRemove: () => _remove(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_items.isEmpty) const _EmptyIngredients(),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: _items.isEmpty ? 'Add your first food' : 'Add ingredient',
                    icon: AppIcons.plus,
                    style: _items.isEmpty ? AppButtonStyle.primary : AppButtonStyle.outline,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      showFoodPickerSheet(context, onPick: _addItem, onUnpick: _unpick);
                    },
                  ),
                ],
              ),
            ),
            // Totals + save
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                AppSpacing.md + bottomInset,
              ),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Emoji(AppEmoji.calories, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      CountUpText(value: total.kcal, duration: AppMotion.normal, style: t.numeralM),
                      const SizedBox(width: AppSpacing.xs),
                      Text('kcal', style: t.label),
                      const Spacer(),
                      for (final (kind, grams) in [
                        (MacroKind.protein, total.protein),
                        (MacroKind.carbs, total.carbs),
                        (MacroKind.fat, total.fat),
                      ]) ...[
                        Emoji(kind.emoji, size: 14),
                        const SizedBox(width: 2),
                        Text('${grams.round()}g', style: t.label),
                        const SizedBox(width: AppSpacing.md),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: _editing ? 'Save changes' : 'Save meal',
                    onPressed: _valid && !_saving ? _save : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Fades and grows a row in the first time it is built.
class _AppearOnce extends StatefulWidget {
  const _AppearOnce({super.key, required this.child});
  final Widget child;

  @override
  State<_AppearOnce> createState() => _AppearOnceState();
}

class _AppearOnceState extends State<_AppearOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: AppMotion.spring);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.5, curve: Curves.easeOut));
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
        child: widget.child,
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    super.key,
    required this.item,
    required this.onQty,
    required this.onRemove,
  });

  final MealItem item;
  final ValueChanged<double> onQty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;

    return RoundedDismissible(
      key: ValueKey('dismiss-${item.name}-${item.serving}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: AppGestures.deleteThreshold},
      onDismissed: (_) => onRemove(),
      borderRadius: AppRadii.tile,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        color: p.accent,
        child: const AppIcon(AppIcons.trash, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.tile,
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            EmojiTile(item.emoji, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${item.total.kcal} kcal · ${item.serving}',
                    style: t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // At the smallest amount "−" becomes remove, so deleting never
            // depends on discovering the swipe.
            item.qty > 0.5
                ? _Step(icon: AppIcons.minus, onTap: () => onQty(item.qty - 0.5), enabled: true)
                : _Step(icon: AppIcons.trash, onTap: onRemove, enabled: true, destructive: true),
            SizedBox(
              width: 32,
              child: Text(formatQty(item.qty), textAlign: TextAlign.center, style: t.numeralS),
            ),
            _Step(icon: AppIcons.plus, onTap: () => onQty(item.qty + 0.5), enabled: true),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap, required this.enabled, this.destructive = false});
  final AppIconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      scale: 0.88,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: enabled ? 1 : 0.3,
        // 40px hit area around a 32px visual.
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: destructive ? p.accent.withValues(alpha: 0.12) : p.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: AppIcon(icon, size: 14, color: destructive ? p.accent : p.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyIngredients extends StatelessWidget {
  const _EmptyIngredients();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const PopIn(child: Emoji('🥘', size: 44)),
          const SizedBox(height: AppSpacing.sm),
          Text('Nothing in this meal yet', style: t.bodyStrong),
          const SizedBox(height: AppSpacing.xxs),
          Text('Search any food — roti, dal, eggs, rice…', style: t.label),
        ],
      ),
    );
  }
}

class _EmojiPickerSheet extends StatelessWidget {
  const _EmojiPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Pick a cover',
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (var i = 0; i < AppEmoji.mealCovers.length; i++)
            PopIn(
              delay: Duration(milliseconds: 18 * i),
              from: 0.5,
              child: PressScale(
                scale: 0.9,
                onTap: () {
                  Haptics.tap();
                  Navigator.of(context).pop(AppEmoji.mealCovers[i]);
                },
                child: EmojiTile(AppEmoji.mealCovers[i], size: 60, radius: 18),
              ),
            ),
        ],
      ),
    );
  }
}
