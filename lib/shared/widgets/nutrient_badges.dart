import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Icon for a given nutrient/metadata key, used to give macro rows a quick
/// visual anchor instead of relying on a letter + color alone.
IconData nutrientIcon(String key) {
  switch (key) {
    case 'calories':
      return Icons.local_fire_department;
    case 'protein':
      return Icons.egg_alt_outlined;
    case 'carb':
      return Icons.grain;
    case 'fat':
      return Icons.water_drop_outlined;
    case 'serving':
      return Icons.restaurant_outlined;
    default:
      return Icons.circle;
  }
}

/// Icon for a meal-type label as shown across the app (e.g. from
/// `MealEntrySerializer.get_meal_type` on the backend: 'Bữa sáng', 'Bữa
/// trưa', 'Bữa tối', 'Ăn nhẹ').
IconData mealTypeIcon(String mealType) {
  switch (mealType) {
    case 'Bữa sáng':
      return Icons.wb_twilight;
    case 'Bữa trưa':
      return Icons.lunch_dining;
    case 'Bữa tối':
      return Icons.dinner_dining;
    default:
      return Icons.cookie_outlined;
  }
}

/// A single labeled nutrient value with an icon — the shared building block
/// for macro rows across meal detail, diary, search and barcode screens, so
/// the same info reads the same way everywhere instead of bespoke
/// letter-only chips per screen.
class MacroIconRow extends StatelessWidget {
  const MacroIconRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

/// Compact icon+value badge (pill shape) for tighter spaces — list items,
/// product sheets, search results — where a full row would be too tall.
class MacroIconBadge extends StatelessWidget {
  const MacroIconBadge({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
