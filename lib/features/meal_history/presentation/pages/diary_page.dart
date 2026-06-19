import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../nutrition/presentation/bloc/nutrition_cubit.dart';
import '../../../nutrition/presentation/bloc/nutrition_state.dart';
import '../../data/models/meal_entry.dart';
import '../bloc/meal_history_cubit.dart';
import '../bloc/meal_history_state.dart';

enum _DiaryPhase { loading, success, error }

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  late DateTime _selectedDate;
  // Calorie chart is driven by a user-selectable date range (defaults to the
  // latest 7 days).
  late DateTimeRange _chartRange;
  var _caloriePoints = const <_CaloriePoint>[];
  var _chartLoading = true;
  int? _activeChartIndex;

  @override
  void initState() {
    super.initState();
    final today = _normalizeDate(DateTime.now());
    _selectedDate = today;
    _chartRange = DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  _DiaryPhase _resolvePhase(
    NutritionState nutritionState,
    MealHistoryState mealState,
  ) {
    if (nutritionState.loading || mealState.loading || _chartLoading) {
      return _DiaryPhase.loading;
    }
    if (nutritionState.errorMessage != null || mealState.errorMessage != null) {
      return _DiaryPhase.error;
    }
    return _DiaryPhase.success;
  }

  double _safeCalorieGoal(NutritionState state) {
    final goal = state.dailyNutrition.calorieGoal;
    return goal > 0 ? goal : 2000;
  }

  Future<void> _load() async {
    await Future.wait([
      context.read<NutritionCubit>().load(date: _selectedDate),
      context.read<MealHistoryCubit>().load(date: _selectedDate),
      _loadCalorieChart(),
    ]);
  }

  /// Loads daily calories for every day in [_chartRange] (inclusive).
  Future<void> _loadCalorieChart() async {
    if (mounted) setState(() => _chartLoading = true);
    final start = _chartRange.start;
    final end = _chartRange.end;
    final dayCount = end.difference(start).inDays + 1;
    final dates = List.generate(
      dayCount,
      (index) => DateTime(start.year, start.month, start.day + index),
    );
    try {
      final response =
          await AppDependencies.dioClient.get<Map<String, dynamic>>(
        ApiEndpoints.nutritionTrends,
        queryParameters: {
          'from': _dateValue(start),
          'to': _dateValue(end),
        },
      );
      final byDate = _trendCaloriesByDate(response.data?['data']);
      final points = dates
          .map((date) =>
              _CaloriePoint(date: date, calories: byDate[_dateValue(date)] ?? 0))
          .toList();
      if (!mounted) return;
      setState(() {
        _caloriePoints = points;
        _activeChartIndex = points.isEmpty ? null : points.length - 1;
        _chartLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[DiaryPage] calorie chart load failed: $error');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 4);
      if (!mounted) return;
      setState(() {
        _caloriePoints = dates
            .map((date) => _CaloriePoint(date: date, calories: 0))
            .toList();
        _activeChartIndex = dates.isEmpty ? null : dates.length - 1;
        _chartLoading = false;
      });
    }
  }

  Future<void> _pickChartStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chartRange.start,
      firstDate: DateTime(2000),
      lastDate: _chartRange.end,
      helpText: 'Chọn ngày bắt đầu',
      confirmText: 'Chọn',
      cancelText: 'Hủy',
    );
    if (picked == null) return;
    setState(() {
      _chartRange = DateTimeRange(
        start: _normalizeDate(picked),
        end: _chartRange.end,
      );
    });
    await _loadCalorieChart();
  }

  Future<void> _pickChartEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chartRange.end,
      firstDate: _chartRange.start,
      lastDate: _normalizeDate(DateTime.now()),
      helpText: 'Chọn ngày kết thúc',
      confirmText: 'Chọn',
      cancelText: 'Hủy',
    );
    if (picked == null) return;
    setState(() {
      _chartRange = DateTimeRange(
        start: _chartRange.start,
        end: _normalizeDate(picked),
      );
    });
    await _loadCalorieChart();
  }

  Map<String, double> _trendCaloriesByDate(Object? payload) {
    final records = _extractTrendRecords(payload);
    final byDate = <String, double>{};
    for (final record in records) {
      if (record is! Map) continue;
      final map = Map<String, dynamic>.from(record);
      final dateText = _trendDate(map);
      if (dateText == null) continue;
      byDate[dateText] = _toDouble(
        map['total_calories'] ??
            map['calories'] ??
            map['intake_calories'] ??
            map['consumed_calories'],
      );
    }
    return byDate;
  }

  List _extractTrendRecords(Object? payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in const [
        'records',
        'results',
        'items',
        'logs',
        'range_logs',
        'daily',
        'data',
      ]) {
        final value = map[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = _extractTrendRecords(value);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return const [];
  }

  String? _trendDate(Map<String, dynamic> map) {
    final raw = map['date'] ?? map['day'] ?? map['logged_date'];
    if (raw == null) return null;
    final parsed = DateTime.tryParse('$raw');
    if (parsed == null) return '$raw'.split('T').first;
    return _dateValue(parsed);
  }

  String _dateValue(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Nhật ký dinh dưỡng',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, dd MMMM').format(_selectedDate),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _DiaryCalendarHeader(
              selectedDate: _selectedDate,
              onSelected: _selectDate,
              onOpenPicker: _openDatePicker,
            ),
            const SizedBox(height: 14),
            BlocBuilder<NutritionCubit, NutritionState>(
              builder: (context, nutritionState) {
                return BlocBuilder<MealHistoryCubit, MealHistoryState>(
                  builder: (context, mealState) {
                    final phase = _resolvePhase(nutritionState, mealState);
                    if (phase == _DiaryPhase.loading) {
                      return const PremiumCard(
                        child: SkeletonBlock(height: 220),
                      );
                    }
                    if (phase == _DiaryPhase.error) {
                      final message = nutritionState.errorMessage ??
                          mealState.errorMessage ??
                          'Không thể tải nhật ký dinh dưỡng.';
                      return _MessageTile(
                        icon: Icons.wifi_off,
                        message: message,
                        actionLabel: 'Thử lại',
                        onTap: _load,
                        color: AppTheme.danger,
                      );
                    }
                    final calorieGoal = _safeCalorieGoal(nutritionState);
                    return _CalorieChart(
                      points: _caloriePoints,
                      calorieGoal: calorieGoal,
                      rangeStart: _chartRange.start,
                      rangeEnd: _chartRange.end,
                      activeIndex: _activeChartIndex,
                      onActiveIndexChanged: (index) {
                        setState(() => _activeChartIndex = index);
                      },
                      onPickStart: _pickChartStart,
                      onPickEnd: _pickChartEnd,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),
            BlocBuilder<NutritionCubit, NutritionState>(
              builder: (context, nutritionState) {
                return BlocBuilder<MealHistoryCubit, MealHistoryState>(
                  builder: (context, mealState) {
                    final phase = _resolvePhase(nutritionState, mealState);
                    if (phase == _DiaryPhase.loading) {
                      return const PremiumCard(
                        child: SkeletonBlock(height: 78),
                      );
                    }
                    if (phase == _DiaryPhase.error) {
                      return const SizedBox.shrink();
                    }
                    final nutrition = nutritionState.dailyNutrition;
                    final goal = _safeCalorieGoal(nutritionState);
                    final remaining = goal - nutrition.calories;
                    final over = remaining < 0;
                    final progress =
                        goal > 0 ? (nutrition.calories / goal).clamp(0.0, 1.0) : 0.0;
                    return PremiumCard(
                      borderColor: over
                          ? AppTheme.danger.withValues(alpha: 0.35)
                          : AppTheme.secondary.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: AnimatedNutritionRing(
                              value: progress,
                              color: over ? AppTheme.danger : AppTheme.secondary,
                              size: 64,
                              strokeWidth: 7,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Năng lượng',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  over
                                      ? 'Vượt ${remaining.abs().toStringAsFixed(0)} kcal'
                                      : 'Còn lại ${remaining.toStringAsFixed(0)} kcal',
                                  style: TextStyle(
                                    color: over
                                        ? AppTheme.danger
                                        : AppTheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${nutrition.calories.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)}',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                '${goal > 0 ? (nutrition.calories / goal * 100).round() : 0}%',
                                style: TextStyle(
                                  color:
                                      over ? AppTheme.danger : AppTheme.secondary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            BlocBuilder<MealHistoryCubit, MealHistoryState>(
              builder: (context, mealState) {
                return BlocBuilder<NutritionCubit, NutritionState>(
                  builder: (context, nutritionState) {
                    final phase = _resolvePhase(nutritionState, mealState);
                    if (phase == _DiaryPhase.loading) {
                      return const Column(
                        children: [
                          SkeletonBlock(height: 92),
                          SizedBox(height: 10),
                          SkeletonBlock(height: 92),
                          SizedBox(height: 10),
                          SkeletonBlock(height: 92),
                        ],
                      );
                    }
                    if (phase == _DiaryPhase.error) {
                      return const SizedBox.shrink();
                    }
                    if (mealState.entries.isEmpty) {
                      return _MessageTile(
                        icon: Icons.center_focus_strong,
                        message:
                            'Chưa có bữa ăn nào được ghi nhận. Quét món ăn ngay!',
                        actionLabel: 'Quét AI',
                        onTap: () => context.go('/scan'),
                        color: AppTheme.accent,
                      );
                    }
                    return Column(
                      children: _sections(mealState.entries)
                          .map(
                            (section) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MealSection(section: section),
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(DateTime date) async {
    final normalized = _normalizeDate(date);
    setState(() => _selectedDate = normalized);
    await _load();
  }

  Future<void> _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Chọn ngày nhật ký',
      confirmText: 'Chọn',
      cancelText: 'Hủy',
    );
    if (picked == null) return;
    await _selectDate(picked);
  }

  List<_MealSectionData> _sections(List<MealEntry> entries) {
    final sections = [
      _MealSectionData(
        title: 'Bữa sáng',
        icon: Icons.bakery_dining_outlined,
        color: AppTheme.accent,
      ),
      _MealSectionData(
        title: 'Bữa trưa',
        icon: Icons.lunch_dining_outlined,
        color: AppTheme.primary,
      ),
      _MealSectionData(
        title: 'Bữa tối',
        icon: Icons.dinner_dining_outlined,
        color: const Color(0xFF6366F1),
      ),
      _MealSectionData(
        title: 'Ăn nhẹ',
        icon: Icons.icecream_outlined,
        color: AppTheme.secondary,
      ),
    ];

    for (final entry in entries) {
      final target = _sectionFor(entry.mealType, sections);
      target.entries.add(entry);
    }

    return sections.where((section) => section.entries.isNotEmpty).toList();
  }

  _MealSectionData _sectionFor(
      String mealType, List<_MealSectionData> sections) {
    final normalized = mealType.toLowerCase();
    if (normalized.contains('breakfast') || normalized.contains('sáng')) {
      return sections[0];
    }
    if (normalized.contains('dinner') || normalized.contains('tối')) {
      return sections[2];
    }
    if (normalized.contains('snack') ||
        normalized.contains('nhẹ') ||
        normalized.contains('phụ') ||
        normalized.contains('ăn vặt')) {
      return sections[3];
    }
    return sections[1];
  }
}

class _DiaryCalendarHeader extends StatelessWidget {
  const _DiaryCalendarHeader({
    required this.selectedDate,
    required this.onSelected,
    required this.onOpenPicker,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfiniteCalendarRibbon(
            selectedDate: selectedDate,
            onSelected: onSelected,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 54,
          height: 54,
          child: IconButton.filledTonal(
            onPressed: onOpenPicker,
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Chọn ngày',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfiniteCalendarRibbon extends StatefulWidget {
  const _InfiniteCalendarRibbon({
    required this.selectedDate,
    required this.onSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_InfiniteCalendarRibbon> createState() =>
      _InfiniteCalendarRibbonState();
}

class _InfiniteCalendarRibbonState extends State<_InfiniteCalendarRibbon> {
  static const _anchorIndex = 10000;
  static const _itemExtent = 66.0;
  static const _itemCount = _anchorIndex * 2 + 1;
  late final ScrollController _controller;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = _normalize(DateTime.now());
    _controller = ScrollController(
      initialScrollOffset: (_anchorIndex - 2) * _itemExtent,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _InfiniteCalendarRibbon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      return;
    }
    if (!_controller.hasClients) return;
    _controller.animateTo(
      _offsetForDate(widget.selectedDate),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: _itemCount,
        itemExtent: _itemExtent,
        itemBuilder: (context, index) {
          final date = _today.add(Duration(days: index - _anchorIndex));
          final selected = DateUtils.isSameDay(date, widget.selectedDate);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PressableScale(
              onTap: () => widget.onSelected(date),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        selected ? AppTheme.primary : const Color(0xFFE5E7EB),
                  ),
                ),
                child: SizedBox(
                  width: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.E().format(date),
                        style: TextStyle(
                          color: selected
                              ? Colors.white70
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  double _offsetForDate(DateTime date) {
    final diff = _normalize(date).difference(_today).inDays;
    final index = (_anchorIndex + diff - 2).clamp(0, _itemCount - 1);
    return index * _itemExtent;
  }
}

class _CalorieChart extends StatelessWidget {
  const _CalorieChart({
    required this.points,
    required this.calorieGoal,
    required this.rangeStart,
    required this.rangeEnd,
    required this.activeIndex,
    required this.onActiveIndexChanged,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final List<_CaloriePoint> points;
  final double calorieGoal;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int? activeIndex;
  final ValueChanged<int> onActiveIndexChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const PremiumCard(child: SkeletonBlock(height: 220));
    }
    final safeIndex = activeIndex == null ||
            activeIndex! < 0 ||
            activeIndex! >= points.length
        ? points.length - 1
        : activeIndex!;
    final selectedPoint = points[safeIndex];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.primaryContainer,
                child: Icon(Icons.bar_chart, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Theo dõi calories',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${DateFormat('dd/MM').format(selectedPoint.date)}: '
                      '${selectedPoint.calories.toStringAsFixed(0)} / ${calorieGoal.toStringAsFixed(0)} kcal · ${points.length} ngày',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DateChip(
                  label: 'Từ ngày',
                  date: rangeStart,
                  onTap: onPickStart,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward,
                    size: 16, color: AppTheme.textSecondary),
              ),
              Expanded(
                child: _DateChip(
                  label: 'Đến ngày',
                  date: rangeEnd,
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: _CalorieBarChart(
              points: points,
              calorieGoal: calorieGoal,
              activeIndex: safeIndex,
              onSelected: onActiveIndexChanged,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              SourceBadge(
                label: 'TDEE',
                icon: Icons.flag_outlined,
                color: AppTheme.fat,
              ),
              SizedBox(width: 8),
              SourceBadge(
                label: 'Cột calories',
                icon: Icons.bar_chart,
                color: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more,
                size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _CalorieBarChart extends StatelessWidget {
  const _CalorieBarChart({
    required this.points,
    required this.calorieGoal,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<_CaloriePoint> points;
  final double calorieGoal;
  final int? activeIndex;
  final ValueChanged<int> onSelected;

  static const double _minSlot = 40.0;

  double get _maxCalories => [
        calorieGoal,
        ...points.map((point) => point.calories),
        1.0,
      ].reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    // Compact (day-of-month) labels once the range is too dense for weekday
    // labels; otherwise show the weekday abbreviation.
    final compact = points.length > 9;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final slot = available / points.length;
        if (slot >= _minSlot) {
          // Everything fits: stretch bars to fill the available width.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              points.length,
              (index) => Expanded(child: _bar(index, compact)),
            ),
          );
        }
        // Too many days to fit: scroll horizontally with a fixed slot width.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _minSlot * points.length,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                points.length,
                (index) => SizedBox(width: _minSlot, child: _bar(index, compact)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bar(int index, bool compact) {
    final point = points[index];
    final ratio = (point.calories / _maxCalories).clamp(0.04, 1.0);
    final selected = activeIndex == index;
    return PressableScale(
      onTap: () => onSelected(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (selected)
              Text(
                point.calories.toStringAsFixed(0),
                maxLines: 1,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              )
            else
              const SizedBox(height: 14),
            const SizedBox(height: 4),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return FractionallySizedBox(
                      heightFactor: value,
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _barColor(point.calories, calorieGoal),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _barColor(point.calories, calorieGoal)
                                  .withValues(alpha: 0.24),
                              blurRadius: selected ? 14 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const SizedBox(width: double.infinity),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              compact ? '${point.date.day}' : DateFormat.E().format(point.date),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _barColor(double calories, double goal) {
    if (goal <= 0) return AppTheme.mint;
    final ratio = calories / goal;
    if (ratio > 1.08) return AppTheme.danger;
    if (ratio > 0.92) return AppTheme.accent;
    return AppTheme.mint;
  }
}

class _CaloriePoint {
  const _CaloriePoint({required this.date, required this.calories});

  final DateTime date;
  final double calories;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.section});

  final _MealSectionData section;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: CircleAvatar(
            backgroundColor: section.color.withValues(alpha: 0.14),
            child: Icon(section.icon, color: section.color),
          ),
          title: Text(
            section.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text('${section.entries.length} món'),
          children: section.entries
              .map(
                (entry) => ListTile(
                  onTap: entry.id.isEmpty
                      ? null
                      : () => context.go('/meals/detail/${entry.id}'),
                  title: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      SourceBadge(
                        label: _sourceLabel(entry.sourceType),
                        icon: _iconForSource(entry.sourceType),
                        color: _sourceColor(entry.sourceType),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            DateTimeUtils.formatTime(entry.loggedAt),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _NutrientBadge(
                            label: 'P',
                            value: entry.proteinGrams,
                            color: AppTheme.protein,
                          ),
                          const SizedBox(width: 4),
                          _NutrientBadge(
                            label: 'C',
                            value: entry.carbsGrams,
                            color: AppTheme.accent,
                          ),
                          const SizedBox(width: 4),
                          _NutrientBadge(
                            label: 'F',
                            value: entry.fatGrams,
                            color: AppTheme.mint,
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${entry.calories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MealSectionData {
  _MealSectionData({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
  final entries = <MealEntry>[];
}

class _NutrientBadge extends StatelessWidget {
  const _NutrientBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          '$label ${value.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

String _sourceLabel(String sourceType) {
  switch (sourceType) {
    case 'image':
      return 'Quét AI';
    case 'barcode':
      return 'Mã vạch';
    case 'text':
      return 'USDA';
    default:
      return 'Nhập tay';
  }
}

IconData _iconForSource(String sourceType) {
  switch (sourceType) {
    case 'image':
      return Icons.auto_awesome;
    case 'barcode':
      return Icons.qr_code_scanner;
    case 'text':
      return Icons.search;
    default:
      return Icons.edit_note;
  }
}

Color _sourceColor(String sourceType) {
  switch (sourceType) {
    case 'image':
      return AppTheme.accent;
    case 'barcode':
      return AppTheme.secondary;
    case 'text':
      return AppTheme.primary;
    default:
      return AppTheme.outline;
  }
}
