import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../meal_history/data/models/meal_entry.dart';
import '../../../meal_history/presentation/bloc/meal_history_cubit.dart';
import '../../../meal_history/presentation/bloc/meal_history_state.dart';
import '../../../profile/presentation/bloc/profile_cubit.dart';
import '../../../profile/presentation/bloc/profile_state.dart';
import '../../domain/entities/nutrition_advice.dart';
import '../bloc/nutrition_cubit.dart';
import '../bloc/nutrition_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final today = DateTime.now();
    await Future.wait([
      context.read<ProfileCubit>().load(),
      context.read<NutritionCubit>().load(date: today),
      context.read<MealHistoryCubit>().load(date: today),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final name = state.profile.name.trim();
                final firstName = name.isEmpty ? 'Long' : name.split(' ').last;
                final greeting =
                    _TimeOfDayGreeting.resolve(DateTime.now().toLocal());
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: greeting.iconBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        greeting.icon,
                        size: 30,
                        color: greeting.iconColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${greeting.message}, $firstName!',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            BlocBuilder<NutritionCubit, NutritionState>(
              builder: (context, state) {
                if (state.loading) return const _HomeSkeleton();
                if (state.errorMessage != null) {
                  return _MessageCard(
                    icon: Icons.wifi_off,
                    message: state.errorMessage!,
                    actionLabel: 'Thử lại',
                    onPressed: _load,
                    color: AppTheme.danger,
                  );
                }
                final nutrition = state.dailyNutrition;
                return Column(
                  children: [
                    _NutritionHero(
                      calories: nutrition.calories,
                      goal: nutrition.calorieGoal,
                      protein: nutrition.proteinGrams,
                      carbs: nutrition.carbsGrams,
                      fat: nutrition.fatGrams,
                    ),
                    if (state.advice != null) ...[
                      const SizedBox(height: 14),
                      _AdviceCard(advice: state.advice!),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const _ActionGrid(),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Bữa ăn hôm nay',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/diary'),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Nhật ký'),
                ),
              ],
            ),
            BlocBuilder<MealHistoryCubit, MealHistoryState>(
              builder: (context, state) {
                if (state.loading) {
                  return const Column(
                    children: [
                      SkeletonBlock(height: 76),
                      SizedBox(height: 10),
                      SkeletonBlock(height: 76),
                    ],
                  );
                }
                if (state.entries.isEmpty) {
                  return _MessageCard(
                    icon: Icons.local_fire_department_outlined,
                    message: 'Chưa có bữa ăn nào hôm nay.',
                    actionLabel: 'Quét món ăn',
                    onPressed: () => context.go('/scan'),
                    color: AppTheme.primary,
                  );
                }
                return Column(
                  children: state.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: entry.id.isEmpty
                              ? null
                              : () => context.go('/meals/detail/${entry.id}'),
                          child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _sourceColor(entry.sourceType)
                                  .withValues(alpha: 0.14),
                              child: Icon(
                                _iconForSource(entry.sourceType),
                                color: _sourceColor(entry.sourceType),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    entry.mealType,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${entry.calories.toStringAsFixed(0)} kcal',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                _MacroBadgeRow(entry: entry),
                              ],
                            ),
                          ],
                        ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionHero extends StatelessWidget {
  const _NutritionHero({
    required this.calories,
    required this.goal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double goal;
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 228,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedNutritionRing(
                  value: protein / 120,
                  color: AppTheme.protein,
                  size: 220,
                  strokeWidth: 12,
                ),
                AnimatedNutritionRing(
                  value: carbs / 260,
                  color: AppTheme.carb,
                  size: 176,
                  strokeWidth: 12,
                ),
                AnimatedNutritionRing(
                  value: fat / 80,
                  color: AppTheme.fat,
                  size: 132,
                  strokeWidth: 12,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      calories.toStringAsFixed(0),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '/ ${goal.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _PercentPill(
                      percent: goal > 0 ? calories / goal : 0,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MacroLegend(
                  label: 'Protein',
                  value: protein,
                  goal: 120,
                  color: AppTheme.protein,
                ),
              ),
              Expanded(
                child: _MacroLegend(
                  label: 'Carb',
                  value: carbs,
                  goal: 260,
                  color: AppTheme.carb,
                ),
              ),
              Expanded(
                child: _MacroLegend(
                  label: 'Béo',
                  value: fat,
                  goal: 80,
                  color: AppTheme.fat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});

  final NutritionAdvice advice;

  @override
  Widget build(BuildContext context) {
    // Status, title and message are all evaluated by the backend.
    final color = switch (advice.status) {
      'danger' => AppTheme.danger,
      'warning' => AppTheme.accent,
      _ => AppTheme.secondary,
    };
    final title = advice.title;
    final message = advice.message;

    return PremiumCard(
      borderColor: color.withValues(alpha: 0.45),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(Icons.tips_and_updates_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.35,
      children: [
        _ActionButton(
          icon: Icons.center_focus_strong,
          label: 'Quét AI',
          color: AppTheme.accent,
          onTap: () => context.go('/scan'),
        ),
        _ActionButton(
          icon: Icons.search_rounded,
          label: 'Tìm Kiếm',
          color: AppTheme.primary,
          onTap: () => context.go('/search'),
        ),
        _ActionButton(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Mã Vạch',
          color: AppTheme.secondary,
          onTap: () => context.go('/barcode-scan'),
        ),
        _ActionButton(
          icon: Icons.edit_note_rounded,
          label: 'Nhập Thủ Công',
          color: AppTheme.protein,
          onTap: () => context.go('/meals/manual'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: color.withValues(alpha: 0.25),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  final String label;
  final double value;
  final double goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = goal > 0 ? (value / goal * 100).round() : 0;
    return Column(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(height: 6),
        Text(
          '${value.toStringAsFixed(0)}g',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        Text(
          '$percent%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Small rounded percentage badge used on progress charts (#11).
class _PercentPill extends StatelessWidget {
  const _PercentPill({required this.percent, required this.color});

  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = (percent * 100).round();
    final over = percent >= 1;
    final bg = over ? AppTheme.danger : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$clamped%',
        style: TextStyle(
          color: bg,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MacroBadgeRow extends StatelessWidget {
  const _MacroBadgeRow({required this.entry});

  final MealEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );
  }
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
            color: color.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 4),
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

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonBlock(height: 220, borderRadius: 110),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: SkeletonBlock(height: 44)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBlock(height: 44)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBlock(height: 44)),
            ],
          ),
        ],
      ),
    );
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
      return Icons.analytics_outlined;
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

class _TimeOfDayGreeting {
  const _TimeOfDayGreeting({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final String message;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  static _TimeOfDayGreeting resolve(DateTime now) {
    final localHour = now.toLocal().hour;
    if (localHour >= 5 && localHour < 12) {
      return const _TimeOfDayGreeting(
        message: 'Chào buổi sáng',
        icon: Icons.wb_sunny,
        iconColor: AppTheme.accent,
        iconBackground: Color(0xFFFFF3E0),
      );
    }
    if (localHour >= 12 && localHour < 18) {
      return const _TimeOfDayGreeting(
        message: 'Chào buổi chiều',
        icon: Icons.wb_cloudy,
        iconColor: Color(0xFFD4A017),
        iconBackground: Color(0xFFFFF8E7),
      );
    }
    return const _TimeOfDayGreeting(
      message: 'Chào buổi tối',
      icon: Icons.nightlight_round,
      iconColor: Color(0xFF8B9DC3),
      iconBackground: Color(0x141E2A3A),
    );
  }
}
