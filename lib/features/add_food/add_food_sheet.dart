import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/common_foods.dart';
import '../../core/data/food.dart';
import '../../core/data/food_catalog.dart';
import '../../core/data/preset_meals.dart';
import '../../core/db/database.dart';
import '../../core/db/models.dart';
import '../../core/db/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/add_circle.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/macro_icons.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/segmented_pills.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../meals/meal_detail_sheet.dart';
import '../../core/widgets/app_icon.dart';

/// Opens the add-food sheet. Pass [editing] to edit an existing entry, or
/// [day] to log onto a day other than today.
Future<void> showAddFoodSheet(
  BuildContext context, {
  FoodEntry? editing,
  DateTime? day,
}) {
  return showAppSheet<void>(
    context,
    initialSize: 0.9,
    maxSize: 0.96,
    builder: (_) => AddFoodSheet(editing: editing, day: day),
  );
}

/// Opens the same food browser, but hands each pick to [onPick] instead of
/// logging it (used when building a meal).
/// [onUnpick] takes a pick back (the "−" on a row that was just added).
Future<void> showFoodPickerSheet(
  BuildContext context, {
  required void Function(Food food, double qty) onPick,
  void Function(Food food, double qty)? onUnpick,
  String title = 'Add ingredient',
}) {
  return showAppSheet<void>(
    context,
    initialSize: 0.9,
    maxSize: 0.96,
    builder: (_) => AddFoodSheet(
      picker: FoodPicker(title: title, onPick: onPick, onUnpick: onUnpick),
    ),
  );
}

class FoodPicker {
  const FoodPicker({required this.title, required this.onPick, this.onUnpick});
  final String title;
  final void Function(Food food, double qty) onPick;
  final void Function(Food food, double qty)? onUnpick;
}

/// One add made during this visit, kept so it can be taken back: the logged
/// entry's id, or (when picking) the food handed to the meal builder.
class _Added {
  const _Added({required this.kcal, this.entryId, this.food, this.qty = 1});
  final int kcal;
  final int? entryId;
  final Food? food;
  final double qty;
}

enum _Kind { recent, popular, meals, mine, group }

class _Chip {
  const _Chip(this.kind, this.label, this.emoji, [this.group]);
  final _Kind kind;
  final String label;
  final String emoji;
  final FoodGroup? group;

  @override
  bool operator ==(Object other) =>
      other is _Chip && other.kind == kind && other.group == group;

  @override
  int get hashCode => Object.hash(kind, group);
}

enum _Page { browse, detail, custom }

class AddFoodSheet extends ConsumerStatefulWidget {
  const AddFoodSheet({super.key, this.editing, this.day, this.picker});

  final FoodEntry? editing;
  final DateTime? day;
  final FoodPicker? picker;

  @override
  ConsumerState<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<AddFoodSheet>
    with SingleTickerProviderStateMixin {
  static const double _searchHeaderHeight = 116;

  late MealType _meal = widget.editing?.mealType ?? MealType.forTime(DateTime.now());
  late _Page _page = widget.editing != null ? _Page.custom : _Page.browse;
  final _search = TextEditingController();
  _Chip? _chip;
  bool _mealPickerOpen = false;
  Food? _detail;
  String _customName = '';

  /// What was added during this visit, per food name, plus totals.
  final Map<String, List<_Added>> _added = {};
  int _addedCount = 0;
  int _addedKcal = 0;

  /// Horizontal offset of the list while swiping between chips. Driven 1:1
  /// by the finger, then by a spring ([_swipe]) when let go.
  final _shift = ValueNotifier<double>(0);
  late final AnimationController _swipe = AnimationController.unbounded(vsync: this)
    ..addListener(() => _shift.value = _swipe.value);
  final _chipsScroll = ScrollController();
  final Map<_Chip, GlobalKey> _chipKeys = {};

  bool get _picking => widget.picker != null;
  bool get _editing => widget.editing != null;
  String get _query => _search.text.trim();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _swipe.dispose();
    _shift.dispose();
    _chipsScroll.dispose();
    super.dispose();
  }

  /// "Now", but on the day the user is looking at.
  DateTime _loggedAt() {
    final now = DateTime.now();
    final d = widget.day;
    if (d == null) return now;
    return DateTime(d.year, d.month, d.day, now.hour, now.minute);
  }

  // ------------------------------------------------------------ logging

  void _countAdded(String name, _Added a) {
    setState(() {
      (_added[name] ??= []).add(a);
      _addedCount++;
      _addedKcal += a.kcal;
    });
  }

  int _countOf(String name) => _added[name]?.length ?? 0;

  /// Whether the latest add of [name] can be taken back from the row.
  bool _canRemove(String name) {
    final last = _added[name]?.lastOrNull;
    if (last == null) return false;
    return last.entryId != null || (last.food != null && widget.picker?.onUnpick != null);
  }

  /// Takes back the latest add of [name]: deletes the logged entry, or hands
  /// the food back out of the meal being built.
  Future<void> _removeLast(String name) async {
    final list = _added[name];
    if (list == null || list.isEmpty || !_canRemove(name)) return;
    final last = list.removeLast();
    if (list.isEmpty) _added.remove(name);
    setState(() {
      _addedCount--;
      _addedKcal -= last.kcal;
    });
    if (last.entryId != null) {
      await ref.read(databaseProvider).deleteEntry(last.entryId!);
    } else {
      widget.picker!.onUnpick!(last.food!, last.qty);
    }
  }

  Future<int> _insert(String name, String emoji, Totals t) {
    return ref.read(databaseProvider).addEntry(
          FoodEntriesCompanion.insert(
            name: name,
            kcal: t.kcal,
            protein: Value(t.protein),
            carbs: Value(t.carbs),
            fat: Value(t.fat),
            mealType: _meal,
            loggedAt: _loggedAt(),
            emoji: Value(emoji),
          ),
        );
  }

  /// Logs [qty] servings of [food] (or hands them to the meal builder).
  /// [note] replaces the "× 2" suffix, e.g. "50 g" for a weighed portion.
  Future<void> _add(Food food, double qty, {String? note}) async {
    final t = food.scaled(qty);
    int? id;
    if (_picking) {
      widget.picker!.onPick(food, qty);
    } else {
      final name = note != null
          ? '${food.name} · $note'
          : qty == 1
              ? food.name
              : '${food.name} × ${formatQty(qty)}';
      id = await _insert(name, food.emoji, t);
    }
    Haptics.success();
    _countAdded(food.name, _Added(kcal: t.kcal, entryId: id, food: food, qty: qty));
  }

  Future<void> _addMeal(String name, String emoji, List<MealItem> items) async {
    final t = sumMealItems(items);
    final id = await _insert(name, emoji, t);
    Haptics.success();
    _countAdded(name, _Added(kcal: t.kcal, entryId: id));
  }

  Future<void> _openMeal(String name, String emoji, List<MealItem> items,
      {SavedMeal? saved}) async {
    final logged = await showMealDetailSheet(
      context,
      name: name,
      emoji: emoji,
      items: items,
      saved: saved,
      day: widget.day,
      mealType: _meal,
    );
    // Logged from the detail sheet: counted, but its entry id isn't known
    // here, so the row shows the count without a "−".
    if (logged == true) _countAdded(name, _Added(kcal: sumMealItems(items).kcal));
  }

  Future<void> _submitCustom(_Draft d) async {
    final db = ref.read(databaseProvider);
    final existing = widget.editing;
    final t = Totals(kcal: d.kcal, protein: d.protein, carbs: d.carbs, fat: d.fat);
    Food? picked;

    if (existing != null) {
      await db.updateEntry(existing.copyWith(
        name: d.name,
        kcal: d.kcal,
        protein: d.protein,
        carbs: d.carbs,
        fat: d.fat,
        mealType: _meal,
      ));
    } else if (_picking) {
      picked = Food(
        name: d.name,
        emoji: AppEmoji.custom,
        group: FoodGroup.other,
        serving: '1 serving',
        kcal: d.kcal,
        protein: d.protein,
        carbs: d.carbs,
        fat: d.fat,
      );
      widget.picker!.onPick(picked, 1);
    } else {
      await _insert(d.name, AppEmoji.custom, t);
    }

    if (d.saveToMine && existing == null) {
      await db.addCustomFood(CustomFoodsCompanion.insert(
        name: d.name,
        kcal: d.kcal,
        protein: Value(d.protein),
        carbs: Value(d.carbs),
        fat: Value(d.fat),
        emoji: const Value(AppEmoji.custom),
        createdAt: DateTime.now(),
      ));
    }

    Haptics.success();
    if (_picking) {
      _countAdded(d.name, _Added(kcal: d.kcal, food: picked));
      _goBrowse();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Deletes the entry being edited. The undo goes on the screen below,
  /// which is visible once the sheet has closed.
  Future<void> _deleteEditing() async {
    final entry = widget.editing!;
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final p = context.palette;
    await db.deleteEntry(entry.id);
    Haptics.medium();
    if (mounted) Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Deleted ${entry.name}'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: p.onInk,
          onPressed: () => db.addEntry(entry.toCompanion(false)),
        ),
      ));
  }

  // --------------------------------------------------------- navigation

  void _goBrowse() => setState(() => _page = _Page.browse);

  void _openDetail(Food f) {
    Haptics.tap();
    FocusScope.of(context).unfocus();
    setState(() {
      _detail = f;
      _page = _Page.detail;
    });
    _scrollToTop();
  }

  void _openCustom({String name = ''}) {
    Haptics.tap();
    FocusScope.of(context).unfocus();
    setState(() {
      _customName = name;
      _page = _Page.custom;
    });
    _scrollToTop();
  }

  Future<void> _deleteCustom(CustomFood f) async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (_) => ConfirmDialog(
        title: 'Remove ${f.name}?',
        message: 'It disappears from My foods. Anything you already logged stays.',
        confirmLabel: 'Remove',
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(databaseProvider).deleteCustomFood(f.id);
    Haptics.medium();
    _goBrowse();
  }

  void _scrollToTop() {
    final c = SheetScope.maybeOf(context);
    if (c != null && c.hasClients) c.jumpTo(0);
  }

  // -------------------------------------------------------------- chips

  List<_Chip> _chips({required bool hasRecents, required bool hasMine}) => [
        if (hasRecents && !_picking) const _Chip(_Kind.recent, 'Recent', AppEmoji.recent),
        const _Chip(_Kind.popular, 'Popular', AppEmoji.calories),
        if (!_picking) const _Chip(_Kind.meals, 'Meals', '🍱'),
        if (hasMine) const _Chip(_Kind.mine, 'Mine', AppEmoji.saved),
        for (final g in FoodGroup.values) _Chip(_Kind.group, g.label, g.emoji, g),
      ];

  /// Selects [next], sliding the list in from the side it lives on.
  /// [velocity] carries a swipe's speed into the landing spring.
  void _selectChip(List<_Chip> chips, _Chip next, {double velocity = 0}) {
    if (next == _chip && _query.isEmpty) return;
    final from = chips.indexOf(_chip!);
    final to = chips.indexOf(next);
    Haptics.tap();
    _search.clear();
    setState(() => _chip = next);
    _scrollToTop();
    _revealChip(next);
    if (MediaQuery.disableAnimationsOf(context)) return;
    // Enter from the side of the new chip, then settle with no overshoot.
    final width = MediaQuery.sizeOf(context).width;
    final dir = to >= from ? 1.0 : -1.0;
    _settle(from: dir * width * 0.28, velocity: velocity);
  }

  void _settle({required double from, double velocity = 0}) {
    _swipe.value = from;
    _swipe.animateWith(SpringSimulation(
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 1),
      from,
      0,
      velocity,
    ));
  }

  /// Keeps the selected chip visible in its strip.
  void _revealChip(_Chip c) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[c]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(ctx, alignment: 0.5, duration: AppMotion.slow, curve: AppMotion.easeOut);
    });
  }

  /// Grabbing mid-settle picks the list up where it is (interruptible).
  void _onSwipeStart(DragStartDetails _) {
    _swipe.stop();
    _rawShift = _shift.value;
    _travel = 0;
  }

  /// Finger travel this drag, before the slop is taken off.
  double _travel = 0;

  void _onSwipeUpdate(DragUpdateDetails d, List<_Chip> chips) {
    if (_query.isNotEmpty) return;
    _travel += d.delta.dx;
    // Small sideways drift (a slightly diagonal scroll) doesn't move the
    // list; past the slop it follows the finger without a jump.
    final over = _travel.abs() - AppGestures.slop;
    if (over <= 0) return;
    _rawShift += over < d.delta.dx.abs() ? over * d.delta.dx.sign : d.delta.dx;
    final i = chips.indexOf(_chip!);
    // Past the first or last chip there is nowhere to go: resist instead.
    final atEdge = (_rawShift > 0 && i == 0) || (_rawShift < 0 && i == chips.length - 1);
    _shift.value = atEdge ? _rubberband(_rawShift, MediaQuery.sizeOf(context).width) : _rawShift;
  }

  double _rawShift = 0;

  static double _rubberband(double x, double dim, [double c = 0.55]) =>
      (x * dim * c) / (dim + c * x.abs());

  void _onSwipeEnd(DragEndDetails d, List<_Chip> chips) {
    if (_query.isNotEmpty) return;
    final width = MediaQuery.sizeOf(context).width;
    final v = d.primaryVelocity ?? 0;
    // Project where the flick is heading (Apple's decay), not where it let go.
    final projected = _shift.value + (v / 1000) * 0.99 / (1 - 0.99);
    final i = chips.indexOf(_chip!);
    final committed = _shift.value.abs() >= AppGestures.minTravel &&
        projected.abs() > width * AppGestures.commitShare;
    _rawShift = 0;
    if (committed && projected < 0 && i < chips.length - 1) {
      _selectChip(chips, chips[i + 1], velocity: v);
    } else if (committed && projected > 0 && i > 0) {
      _selectChip(chips, chips[i - 1], velocity: v);
    } else {
      _settle(from: _shift.value, velocity: v);
    }
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final recents = ref.watch(recentFoodsProvider).value ?? const <FoodEntry>[];
    final mine = ref.watch(customFoodsProvider).value ?? const <CustomFood>[];
    final saved = ref.watch(savedMealsProvider).value ?? const <SavedMeal>[];
    final catalog = catalogOf(ref);
    final chips = _chips(hasRecents: recents.isNotEmpty, hasMine: mine.isNotEmpty);
    _chip ??= chips.first;
    if (!chips.contains(_chip)) _chip = chips.first;
    for (final c in chips) {
      _chipKeys.putIfAbsent(c, GlobalKey.new);
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showFooter = _page == _Page.browse && !_editing;
    final footerHeight = 84.0 + bottomInset;

    final title = _editing
        ? 'Edit food'
        : _picking
            ? widget.picker!.title
            : 'Add food';

    final browsing = _page == _Page.browse;

    return Stack(
      children: [
        // Swipe anywhere on the list to move between chips. The chip strip
        // and text field win their own drags, so this only sees the rest.
        GestureDetector(
          onHorizontalDragStart: browsing ? _onSwipeStart : null,
          onHorizontalDragUpdate: browsing ? (d) => _onSwipeUpdate(d, chips) : null,
          onHorizontalDragEnd: browsing ? (d) => _onSwipeEnd(d, chips) : null,
          child: CustomScrollView(
          controller: SheetScope.maybeOf(context),
          physics: sheetScrollPhysics,
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                title: _page == _Page.browse ? title : _pageTitle(title),
                meal: _picking ? null : _meal,
                pickerOpen: _mealPickerOpen,
                onTogglePicker: () {
                  Haptics.tap();
                  setState(() => _mealPickerOpen = !_mealPickerOpen);
                },
                onMealChanged: (m) => setState(() => _meal = m),
                onBack: _page == _Page.browse || _editing ? null : _goBrowse,
              ),
            ),
            if (_page == _Page.browse) ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedHeader(
                  height: _searchHeaderHeight,
                  color: p.surface,
                  child: _SearchAndChips(
                    controller: _search,
                    chips: chips,
                    chipKeys: _chipKeys,
                    scrollController: _chipsScroll,
                    selected: _query.isEmpty ? _chip : null,
                    onChip: (c) => _selectChip(chips, c),
                  ),
                ),
              ),
              ..._browseSlivers(
                catalog: catalog,
                recents: recents,
                mine: mine,
                saved: saved,
                footerHeight: footerHeight,
              ),
            ] else if (_page == _Page.detail && _detail != null)
              SliverToBoxAdapter(
                child: _SlideIn(
                  key: ValueKey('detail-${_detail!.name}'),
                  child: _FoodDetail(
                    food: _detail!,
                    mealLabel: _picking ? null : _meal.label.toLowerCase(),
                    onAdd: (food, qty, note) async {
                      await _add(food, qty, note: note);
                      _goBrowse();
                    },
                    onDelete: _customFor(_detail!, mine) == null
                        ? null
                        : () => _deleteCustom(_customFor(_detail!, mine)!),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: _SlideIn(
                  key: const ValueKey('custom'),
                  child: _CustomForm(
                    initialName: _customName,
                    editing: widget.editing,
                    submitLabel: _editing
                        ? 'Save changes'
                        : _picking
                            ? 'Add ingredient'
                            : 'Add to ${_meal.label.toLowerCase()}',
                    allowSave: !_editing && !_picking,
                    onSubmit: _submitCustom,
                    onDelete: _editing ? _deleteEditing : null,
                  ),
                ),
              ),
          ],
          ),
        ),
        if (showFooter)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Footer(
              height: footerHeight,
              bottomInset: bottomInset,
              addedCount: _addedCount,
              addedKcal: _addedKcal,
              picking: _picking,
              onCustom: () => _openCustom(name: _query),
              onDone: () => Navigator.of(context).pop(),
            ),
          ),
      ],
    );
  }

  String _pageTitle(String fallback) => switch (_page) {
        _Page.detail => 'Add food',
        _Page.custom => _picking ? 'Custom ingredient' : 'Custom food',
        _Page.browse => fallback,
      };

  // ------------------------------------------------------ browse slivers

  List<Widget> _browseSlivers({
    required FoodCatalog catalog,
    required List<FoodEntry> recents,
    required List<CustomFood> mine,
    required List<SavedMeal> saved,
    required double footerHeight,
  }) {
    final rows = <Widget>[];
    final query = _query;

    Widget foodRow(Food f) => _FoodRow(
          key: ValueKey('food-${f.name}-${f.serving}'),
          food: f,
          count: _countOf(f.name),
          onOpen: () => _openDetail(f),
          onAdd: () => _add(f, 1),
          onRemove: _canRemove(f.name) ? () => _removeLast(f.name) : null,
        );

    if (query.isNotEmpty) {
      final results = catalog.search(query, limit: 60);
      if (results.isEmpty) {
        rows.add(_NoResults(query: query, onCustom: () => _openCustom(name: query)));
      } else {
        rows.addAll(results.map(foodRow));
      }
    } else {
      switch (_chip!.kind) {
        case _Kind.recent:
          rows.addAll(recents.map((e) => foodRow(_foodFromEntry(e))));
        case _Kind.popular:
          for (final name in kPopularFoodNames) {
            final f = catalog.byName(name);
            if (f != null) rows.add(foodRow(f));
          }
        case _Kind.mine:
          // Deleting lives on the food's detail page: a swipe here would
          // fight the swipe between chips.
          rows.addAll(mine.map((f) => foodRow(_foodFromCustom(f))));
        case _Kind.group:
          rows.addAll(catalog.inGroup(_chip!.group!).map(foodRow));
        case _Kind.meals:
          rows.addAll(_mealRows(catalog, saved));
      }
    }

    return [
      SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) => _Shifted(
          shift: _shift,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: rows[i],
          ),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: footerHeight + AppSpacing.lg)),
    ];
  }

  CustomFood? _customFor(Food f, List<CustomFood> mine) {
    if (f.serving != '1 serving' || f.group != FoodGroup.other) return null;
    for (final c in mine) {
      if (c.name == f.name && c.kcal == f.kcal) return c;
    }
    return null;
  }

  List<Widget> _mealRows(FoodCatalog catalog, List<SavedMeal> saved) {
    final out = <Widget>[];
    if (saved.isNotEmpty) {
      out.add(const _SectionLabel('My meals'));
      for (final m in saved) {
        final items = m.items;
        out.add(_MealRow(
          key: ValueKey('saved-${m.id}'),
          emoji: m.emoji,
          name: m.name,
          items: items,
          count: _countOf(m.name),
          onOpen: () => _openMeal(m.name, m.emoji, items, saved: m),
          onAdd: () => _addMeal(m.name, m.emoji, items),
          onRemove: _canRemove(m.name) ? () => _removeLast(m.name) : null,
        ));
      }
    }
    out.add(const _SectionLabel('Quick meals'));
    for (final m in kPresetMeals) {
      final items = m.items(catalog);
      if (items.isEmpty) continue;
      out.add(_MealRow(
        key: ValueKey('preset-${m.name}'),
        emoji: m.emoji,
        name: m.name,
        items: items,
        count: _countOf(m.name),
        onOpen: () => _openMeal(m.name, m.emoji, items),
        onAdd: () => _addMeal(m.name, m.emoji, items),
        onRemove: _canRemove(m.name) ? () => _removeLast(m.name) : null,
      ));
    }
    return out;
  }

  Food _foodFromEntry(FoodEntry e) => Food(
        name: e.name,
        emoji: e.emoji ?? e.mealType.emoji,
        group: FoodGroup.other,
        serving: 'As logged',
        kcal: e.kcal,
        protein: e.protein,
        carbs: e.carbs,
        fat: e.fat,
      );

  Food _foodFromCustom(CustomFood f) => Food(
        name: f.name,
        emoji: f.emoji ?? AppEmoji.saved,
        group: FoodGroup.other,
        serving: '1 serving',
        kcal: f.kcal,
        protein: f.protein,
        carbs: f.carbs,
        fat: f.fat,
      );
}

// ------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.meal,
    required this.pickerOpen,
    required this.onTogglePicker,
    required this.onMealChanged,
    required this.onBack,
  });

  final String title;
  final MealType? meal;
  final bool pickerOpen;
  final VoidCallback onTogglePicker;
  final ValueChanged<MealType> onMealChanged;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (onBack != null) ...[
                PressScale(
                  onTap: () {
                    Haptics.tap();
                    onBack!();
                  },
                  child: Container(
                    width: AppSizes.iconTile - 4,
                    height: AppSizes.iconTile - 4,
                    decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
                    child: AppIcon(AppIcons.caretLeft, size: 18, color: p.textPrimary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(child: Text(title, style: t.title)),
              if (meal != null)
                PressScale(
                  onTap: onTogglePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: pickerOpen ? p.ink : p.surfaceAlt,
                      borderRadius: AppRadii.chip,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Emoji(meal!.emoji, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          meal!.label,
                          style: t.label.copyWith(
                            color: pickerOpen ? p.onInk : p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AnimatedRotation(
                          turns: pickerOpen ? 0.5 : 0,
                          duration: AppMotion.normal,
                          curve: AppMotion.spring,
                          child: AppIcon(
                            AppIcons.caretDown,
                            size: 12,
                            color: pickerOpen ? p.onInk : p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.spring,
            alignment: Alignment.topCenter,
            child: (pickerOpen && meal != null)
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: SegmentedPills<MealType>(
                      compact: true,
                      options: MealType.values,
                      labelOf: (m) => m.label,
                      selected: meal!,
                      onChanged: onMealChanged,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------- search + chips

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  _PinnedHeader({required this.height, required this.color, required this.child});

  final double height;
  final Color color;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: child);

  @override
  bool shouldRebuild(_PinnedHeader old) => true;
}

class _SearchAndChips extends StatelessWidget {
  const _SearchAndChips({
    required this.controller,
    required this.chips,
    required this.chipKeys,
    required this.scrollController,
    required this.selected,
    required this.onChip,
  });

  final TextEditingController controller;
  final List<_Chip> chips;
  final Map<_Chip, GlobalKey> chipKeys;
  final ScrollController scrollController;
  final _Chip? selected;
  final ValueChanged<_Chip> onChip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: AppRadii.chip),
            child: Row(
              children: [
                AppIcon(AppIcons.search, size: 18, color: p.textTertiary),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: t.bodyStrong,
                    cursorColor: p.ink,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.none,
                    // The theme's filled/focused border must not leak in here:
                    // the pill around the field is the visual.
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Search roti, dal, egg, pizza…',
                      hintStyle: t.body.copyWith(color: p.textTertiary),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  PressScale(
                    onTap: () {
                      Haptics.tap();
                      controller.clear();
                    },
                    child: AppIcon(AppIcons.clearFill, size: 20, color: p.textTertiary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 40,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) => _ChipPill(
              key: chipKeys[chips[i]],
              chip: chips[i],
              selected: chips[i] == selected,
              onTap: () => onChip(chips[i]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({super.key, required this.chip, required this.selected, required this.onTap});

  final _Chip chip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surfaceAlt,
          borderRadius: AppRadii.chip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Emoji(chip.emoji, size: 15),
            const SizedBox(width: AppSpacing.xs),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: t.label.copyWith(
                color: selected ? p.onInk : p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              child: Text(chip.label),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- rows

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
        child: Text(text.toUpperCase(), style: context.type.caption.copyWith(letterSpacing: 0.8)),
      );
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    super.key,
    required this.food,
    required this.count,
    required this.onOpen,
    required this.onAdd,
    this.onRemove,
  });

  final Food food;
  final int count;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return PressScale(
      scale: 0.985,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
        child: Row(
          children: [
            EmojiTile(food.emoji, size: 48),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(
                    '${food.serving} · ${food.kcal} kcal',
                    style: t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AddCircle(count: count, onTap: onAdd, onRemove: onRemove),
          ],
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    super.key,
    required this.emoji,
    required this.name,
    required this.items,
    required this.count,
    required this.onOpen,
    required this.onAdd,
    this.onRemove,
  });

  final String emoji;
  final String name;
  final List<MealItem> items;
  final int count;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final total = sumMealItems(items);
    return PressScale(
      scale: 0.985,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
        child: Row(
          children: [
            EmojiTile(emoji, size: 48),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(
                    '${total.kcal} kcal · ${items.map((i) => i.name).join(', ')}',
                    style: t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AddCircle(count: count, onTap: onAdd, onRemove: onRemove),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onCustom});
  final String query;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          const PopIn(child: Emoji('🤔', size: 40)),
          const SizedBox(height: AppSpacing.md),
          Text('Nothing for “$query”', style: t.bodyStrong, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text('Try another word, or add it yourself.', style: t.label),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Add “$query” as custom food', onPressed: onCustom, style: AppButtonStyle.outline),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ footer

class _Footer extends StatelessWidget {
  const _Footer({
    required this.height,
    required this.bottomInset,
    required this.addedCount,
    required this.addedKcal,
    required this.picking,
    required this.onCustom,
    required this.onDone,
  });

  final double height;
  final double bottomInset;
  final int addedCount;
  final int addedKcal;
  final bool picking;
  final VoidCallback onCustom;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final anyAdded = addedCount > 0;

    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.md + bottomInset,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.surface.withValues(alpha: 0), p.surface, p.surface],
          stops: const [0, 0.32, 1],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: anyAdded ? 'Custom' : 'Custom food',
              icon: AppIcons.pencil,
              style: AppButtonStyle.outline,
              onPressed: onCustom,
            ),
          ),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.spring,
            alignment: Alignment.centerLeft,
            child: anyAdded
                ? Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.5,
                      child: AppButton(
                        label: picking ? 'Done · $addedCount' : 'Done · $addedKcal kcal',
                        onPressed: onDone,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- page motion

/// A list row offset by the chip swipe, fading as it travels.
class _Shifted extends StatelessWidget {
  const _Shifted({required this.shift, required this.child});
  final ValueNotifier<double> shift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ValueListenableBuilder<double>(
      valueListenable: shift,
      child: child,
      builder: (context, dx, child) => dx == 0
          ? child!
          : Opacity(
              opacity: (1 - dx.abs() / width * 1.6).clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(dx, 0), child: child),
            ),
    );
  }
}

/// New pages inside the sheet slide in from the right like a push.
class _SlideIn extends StatefulWidget {
  const _SlideIn({super.key, required this.child});
  final Widget child;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: AppMotion.drawer);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curved.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset((1 - curved.value) * 36, 0),
          child: child,
        ),
      ),
    );
  }
}

// ------------------------------------------------------- food detail

class _FoodDetail extends StatefulWidget {
  const _FoodDetail({
    required this.food,
    required this.mealLabel,
    required this.onAdd,
    this.onDelete,
  });

  final Food food;
  final String? mealLabel;
  /// Adds [qty] of the given food: the original for servings, or a copy
  /// portioned to the weighed grams (then [note] is e.g. "50 g").
  final Future<void> Function(Food food, double qty, String? note) onAdd;

  /// Set for the user's own foods: removes it from My foods.
  final VoidCallback? onDelete;

  @override
  State<_FoodDetail> createState() => _FoodDetailState();
}

enum _Unit { servings, grams }

class _FoodDetailState extends State<_FoodDetail> {
  static const double _step = 0.5;
  static const double _min = 0.5;
  static const double _max = 30;
  static const int _gramStep = 10;
  static const int _gramMax = 3000;
  static const List<int> _gramPresets = [50, 100, 150, 200];

  double _qty = 1;
  _Unit _unit = _Unit.servings;
  late int _g = widget.food.grams ?? 100;
  late final _gramsField = TextEditingController(text: '$_g');

  /// Weighing needs the serving's weight to scale from.
  bool get _canWeigh => (widget.food.grams ?? 0) > 0;
  bool get _weighing => _unit == _Unit.grams;

  /// What "Add" adds: N servings, or the food re-portioned to [_g] grams.
  Food get _food => _weighing ? widget.food.withGrams(_g) : widget.food;
  double get _amount => _weighing ? 1 : _qty;

  @override
  void dispose() {
    _gramsField.dispose();
    super.dispose();
  }

  void _change(double delta) {
    final next = (_qty + delta).clamp(_min, _max);
    if (next == _qty) return;
    Haptics.tap();
    setState(() => _qty = next);
  }

  /// [typed] skips the haptic and leaves the field alone while the user types.
  void _setGrams(int g, {bool typed = false}) {
    final next = g.clamp(1, _gramMax);
    if (next == _g) return;
    setState(() => _g = next);
    if (!typed) {
      Haptics.tap();
      _gramsField.text = '$next';
    }
  }

  void _setUnit(_Unit u) {
    if (u == _unit) return;
    FocusScope.of(context).unfocus();
    setState(() => _unit = u);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final food = widget.food;
    final total = _food.scaled(_amount);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xxl + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: PopIn(child: EmojiTile(food.emoji, size: 88, radius: 28))),
          const SizedBox(height: AppSpacing.lg),
          Text(food.name, style: t.heading, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            food.grams == null || food.serving.contains('${food.grams} g')
                ? '1 serving = ${food.serving}'
                : '1 serving = ${food.serving} · ${food.grams} g',
            style: t.label,
            textAlign: TextAlign.center,
          ),
          if (_canWeigh) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: SizedBox(
                width: 220,
                child: SegmentedPills<_Unit>(
                  compact: true,
                  options: _Unit.values,
                  labelOf: (u) => u == _Unit.servings ? 'Servings' : 'Grams',
                  selected: _unit,
                  onChanged: _setUnit,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.springSoft,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              switchInCurve: AppMotion.easeOut,
              child: _weighing
                  ? _gramsPicker(t, p)
                  : Row(
                      key: const ValueKey('servings'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundStep(icon: AppIcons.minus, onTap: () => _change(-_step), enabled: _qty > _min),
                        SizedBox(
                          width: 132,
                          child: Column(
                            children: [
                              AnimatedSwitcher(
                                duration: AppMotion.fast,
                                switchInCurve: AppMotion.easeOut,
                                transitionBuilder: (child, a) => FadeTransition(
                                  opacity: a,
                                  child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(a), child: child),
                                ),
                                child: Text(
                                  formatQty(_qty),
                                  key: ValueKey(_qty),
                                  style: t.numeralL,
                                ),
                              ),
                              Text(_qty == 1 ? 'serving' : 'servings', style: t.label),
                            ],
                          ),
                        ),
                        _RoundStep(icon: AppIcons.plus, onTap: () => _change(_step), enabled: _qty < _max),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: AppRadii.tile,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Emoji(AppEmoji.calories, size: 22),
                    const SizedBox(width: AppSpacing.xs),
                    CountUpText(
                      value: total.kcal,
                      duration: AppMotion.normal,
                      style: t.numeralL,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('kcal', style: t.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    for (final (kind, grams) in [
                      (MacroKind.protein, total.protein),
                      (MacroKind.carbs, total.carbs),
                      (MacroKind.fat, total.fat),
                    ])
                      Expanded(
                        child: Column(
                          children: [
                            Emoji(kind.emoji, size: 20),
                            const SizedBox(height: AppSpacing.xs),
                            Text('${grams.toStringAsFixed(grams < 10 ? 1 : 0)}g', style: t.numeralS),
                            Text(kind.label, style: t.caption),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: widget.mealLabel == null
                ? 'Add ingredient'
                : 'Add to ${widget.mealLabel} · ${total.kcal} kcal',
            onPressed: () => widget.onAdd(_food, _amount, _weighing ? '$_g g' : null),
          ),
          if (widget.onDelete != null) ...[
            const SizedBox(height: AppSpacing.sm),
            PressScale(
              onTap: widget.onDelete,
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    'Remove from my foods',
                    style: t.bodyStrong.copyWith(color: p.accent),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on _FoodDetailState {
  /// Big typeable gram count with ±10 g steps and one-tap common weights.
  Widget _gramsPicker(AppTypography t, AppPalette p) {
    final serving = widget.food.grams!;
    final presets = {..._FoodDetailState._gramPresets, serving}.toList()..sort();
    return Column(
      key: const ValueKey('grams'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundStep(
              icon: AppIcons.minus,
              onTap: () => _setGrams(_g - _FoodDetailState._gramStep),
              enabled: _g > _FoodDetailState._gramStep,
            ),
            SizedBox(
              width: 132,
              child: Column(
                children: [
                  TextField(
                    controller: _gramsField,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: t.numeralL,
                    cursorColor: p.ink,
                    onChanged: (v) {
                      final g = int.tryParse(v);
                      if (g != null && g > 0) _setGrams(g, typed: true);
                    },
                    // The theme's filled field would box in the big number.
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                  Text('grams', style: t.label),
                ],
              ),
            ),
            _RoundStep(
              icon: AppIcons.plus,
              onTap: () => _setGrams(_g + _FoodDetailState._gramStep),
              enabled: _g < _FoodDetailState._gramMax,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final g in presets)
              _GramChip(
                label: g == serving ? '1 serving · $g g' : '$g g',
                selected: g == _g,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _setGrams(g);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _GramChip extends StatelessWidget {
  const _GramChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        // No alignment here: an aligned Container stretches to the Wrap's
        // full width instead of hugging its label.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm + 1),
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surfaceAlt,
          borderRadius: AppRadii.chip,
        ),
        child: Text(
          label,
          style: t.label.copyWith(
            color: selected ? p.onInk : p.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoundStep extends StatelessWidget {
  const _RoundStep({required this.icon, required this.onTap, required this.enabled});

  final AppIconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      scale: 0.9,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: enabled ? 1 : 0.3,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
          child: AppIcon(icon, size: 20, color: p.textPrimary),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ custom form

class _Draft {
  const _Draft({
    required this.name,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.saveToMine,
  });

  final String name;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;
  final bool saveToMine;
}

class _CustomForm extends StatefulWidget {
  const _CustomForm({
    required this.initialName,
    required this.editing,
    required this.submitLabel,
    required this.allowSave,
    required this.onSubmit,
    this.onDelete,
  });

  final String initialName;
  final FoodEntry? editing;
  final String submitLabel;
  final bool allowSave;
  final Future<void> Function(_Draft) onSubmit;

  /// Set when editing a logged entry.
  final VoidCallback? onDelete;

  @override
  State<_CustomForm> createState() => _CustomFormState();
}

class _CustomFormState extends State<_CustomForm> {
  late final _name = TextEditingController(text: widget.editing?.name ?? widget.initialName);
  late final _kcal = TextEditingController(text: widget.editing?.kcal.toString());
  late final _protein = TextEditingController(text: _fmt(widget.editing?.protein));
  late final _carbs = TextEditingController(text: _fmt(widget.editing?.carbs));
  late final _fat = TextEditingController(text: _fmt(widget.editing?.fat));
  bool _saveToMine = false;
  bool _busy = false;

  static String _fmt(double? v) =>
      (v == null || v == 0) ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  static double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  /// Calories typed in, or derived from macros when left blank.
  int? get _resolvedKcal {
    final typed = int.tryParse(_kcal.text.trim());
    if (typed != null) return typed;
    final fromMacros = CalorieCalculator.caloriesFromMacros(
      proteinG: _num(_protein),
      carbsG: _num(_carbs),
      fatG: _num(_fat),
    );
    return fromMacros > 0 ? fromMacros : null;
  }

  /// A macro field's value, or null when left blank (blank isn't zero).
  static double? _maybe(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Calories the macros imply when the typed calories disagree with them.
  int? get _mismatch {
    final typed = int.tryParse(_kcal.text.trim());
    if (typed == null) return null; // derived from macros, so consistent
    return CalorieCalculator.macroMismatch(
      kcal: typed,
      proteinG: _maybe(_protein),
      carbsG: _maybe(_carbs),
      fatG: _maybe(_fat),
    );
  }

  bool get _valid => _name.text.trim().isNotEmpty && _resolvedKcal != null && _mismatch == null;

  bool get _macrosComplete => [_protein, _carbs, _fat].every((c) => c.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _kcal, _protein, _carbs, _fat]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final kcal = _resolvedKcal;
    if (!_valid || kcal == null || _busy) return;
    setState(() => _busy = true);
    await widget.onSubmit(_Draft(
      name: _name.text.trim(),
      kcal: kcal,
      protein: _num(_protein),
      carbs: _num(_carbs),
      fat: _num(_fat),
      saveToMine: _saveToMine,
    ));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xxl + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: t.bodyStrong,
            decoration: const InputDecoration(hintText: 'What did you eat?'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _kcal,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: t.numeralM,
            decoration: InputDecoration(
              hintText: 'Calories',
              hintStyle: t.numeralM.copyWith(color: p.textTertiary),
              suffixText: 'kcal',
              suffixStyle: t.label,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _MacroField(kind: MacroKind.protein, controller: _protein, formatters: numeric)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _MacroField(kind: MacroKind.carbs, controller: _carbs, formatters: numeric)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _MacroField(kind: MacroKind.fat, controller: _fat, formatters: numeric)),
            ],
          ),
          // Inline, as you type: why Add is disabled, and a one-tap fix.
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.springSoft,
            alignment: Alignment.topCenter,
            child: _mismatch == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: _MacroMismatch(
                      implied: _mismatch!,
                      complete: _macrosComplete,
                      onUse: () {
                        Haptics.tap();
                        _kcal.text = '${_mismatch!}';
                      },
                    ),
                  ),
          ),
          if (widget.allowSave) ...[
            const SizedBox(height: AppSpacing.md),
            PressScale(
              onTap: () {
                Haptics.tap();
                setState(() => _saveToMine = !_saveToMine);
              },
              child: Row(
                children: [
                  const Emoji(AppEmoji.saved, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Save to my foods', style: t.body)),
                  Switch(
                    value: _saveToMine,
                    onChanged: (v) {
                      Haptics.tap();
                      setState(() => _saveToMine = v);
                    },
                    activeThumbColor: p.onInk,
                    activeTrackColor: p.ink,
                    inactiveTrackColor: p.track,
                    inactiveThumbColor: p.surface,
                    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: widget.submitLabel,
            onPressed: _valid && !_busy ? _submit : null,
          ),
          if (widget.onDelete != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Delete entry',
              icon: AppIcons.trash,
              style: AppButtonStyle.danger,
              onPressed: _busy ? null : widget.onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroMismatch extends StatelessWidget {
  const _MacroMismatch({required this.implied, required this.complete, required this.onUse});

  final int implied;
  final bool complete;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.1),
        borderRadius: AppRadii.tile,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              complete
                  ? 'These macros add up to $implied kcal, so the calories don’t match.'
                  : 'These macros alone are $implied kcal. Calories can’t be lower.',
              style: t.label.copyWith(color: p.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PressScale(
            onTap: onUse,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.ink, borderRadius: AppRadii.chip),
              child: Text(
                'Use $implied',
                style: t.label.copyWith(color: p.onInk, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroField extends StatelessWidget {
  const _MacroField({
    required this.kind,
    required this.controller,
    required this.formatters,
  });

  final MacroKind kind;
  final TextEditingController controller;
  final List<TextInputFormatter> formatters;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: formatters,
      style: t.bodyStrong,
      decoration: InputDecoration(
        hintText: kind.label,
        hintStyle: t.label.copyWith(color: p.textTertiary),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Emoji(kind.emoji, size: 16),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 20),
        suffixText: 'g',
        suffixStyle: t.label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.lg,
        ),
      ),
    );
  }
}
