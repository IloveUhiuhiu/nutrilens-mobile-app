import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/image_url_utils.dart';
import 'absolute_network_image.dart';

class IngredientImage extends StatelessWidget {
  const IngredientImage({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.label,
  });

  final String? imageUrl;
  final double size;
  // Food name used for category icon when no image URL is available.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final absoluteUrl = ImageUrlUtils.resolveAbsolute(imageUrl);
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: absoluteUrl != null
            ? AbsoluteNetworkImage(
                imageUrl: absoluteUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: _ImageShimmer(size: size),
                errorWidget: _FoodFallback(size: size, label: label),
              )
            : _FoodFallback(size: size, label: label),
      ),
    );
  }
}

class _FoodFallback extends StatelessWidget {
  const _FoodFallback({required this.size, this.label});

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        _iconForFoodName(label),
        color: AppTheme.primary,
        size: size * 0.5,
      ),
    );
  }
}

/// Maps food name keywords (English + Vietnamese) to appropriate Material icons.
IconData _iconForFoodName(String? name) {
  if (name == null || name.isEmpty) return Icons.eco_outlined;
  final s = name.toLowerCase();

  if (_matchesAny(s, ['rice', 'cơm', 'gạo', 'bread', 'bánh mì', 'noodle', 'bún', 'phở', 'mì', 'pasta', 'oat', 'yến mạch', 'ngũ cốc', 'cereal', 'wheat', 'lúa mì', 'corn', 'ngô'])) {
    return Icons.grain;
  }
  if (_matchesAny(s, ['egg', 'trứng'])) {
    return Icons.egg_outlined;
  }
  if (_matchesAny(s, ['milk', 'sữa', 'cheese', 'phô mai', 'yogurt', 'butter', 'bơ', 'cream', 'kem', 'dairy'])) {
    return Icons.water_drop_outlined;
  }
  if (_matchesAny(s, ['chicken', 'gà', 'beef', 'bò', 'pork', 'heo', 'lợn', 'duck', 'vịt', 'fish', 'cá', 'shrimp', 'tôm', 'seafood', 'hải sản', 'meat', 'thịt', 'salmon', 'tuna', 'cua', 'crab', 'squid', 'mực'])) {
    return Icons.set_meal_outlined;
  }
  if (_matchesAny(s, ['apple', 'táo', 'banana', 'chuối', 'orange', 'cam', 'grape', 'nho', 'mango', 'xoài', 'fruit', 'trái', 'quả', 'berry', 'dâu', 'melon', 'dưa', 'pineapple', 'dứa', 'papaya', 'đu đủ', 'lychee', 'vải', 'longan', 'nhãn', 'avocado', 'bơ'])) {
    return Icons.apple_outlined;
  }
  if (_matchesAny(s, ['vegetable', 'rau', 'spinach', 'cải', 'broccoli', 'súp lơ', 'carrot', 'cà rốt', 'cabbage', 'bắp cải', 'tomato', 'cà chua', 'potato', 'khoai tây', 'cucumber', 'dưa leo', 'onion', 'hành', 'garlic', 'tỏi', 'mushroom', 'nấm', 'bean', 'đậu', 'corn', 'bắp', 'celery', 'cần tây'])) {
    return Icons.local_florist_outlined;
  }
  if (_matchesAny(s, ['oil', 'dầu', 'fat', 'mỡ', 'margarine'])) {
    return Icons.opacity_outlined;
  }
  if (_matchesAny(s, ['sugar', 'đường', 'cake', 'bánh ngọt', 'sweet', 'candy', 'kẹo', 'chocolate', 'dessert', 'tráng miệng', 'cookie', 'biscuit', 'jam', 'mứt'])) {
    return Icons.cake_outlined;
  }
  if (_matchesAny(s, ['soup', 'canh', 'broth', 'nước dùng', 'stew'])) {
    return Icons.soup_kitchen_outlined;
  }
  if (_matchesAny(s, ['nut', 'hạt', 'almond', 'hạnh nhân', 'peanut', 'đậu phộng', 'walnut', 'óc chó', 'seed', 'hạt giống'])) {
    return Icons.spa_outlined;
  }
  if (_matchesAny(s, ['tofu', 'đậu hũ', 'tempeh', 'soy', 'đậu nành', 'bean curd'])) {
    return Icons.blur_circular_outlined;
  }
  return Icons.eco_outlined;
}

bool _matchesAny(String source, List<String> keywords) {
  for (final kw in keywords) {
    if (source.contains(kw)) return true;
  }
  return false;
}

class _ImageShimmer extends StatefulWidget {
  const _ImageShimmer({required this.size});

  final double size;

  @override
  State<_ImageShimmer> createState() => _ImageShimmerState();
}

class _ImageShimmerState extends State<_ImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, -1),
              end: Alignment(_controller.value * 2, 1),
              colors: const [
                Color(0xFFE9F5EE),
                Color(0xFFF8F9FA),
                Color(0xFFE9F5EE),
              ],
            ),
          ),
        );
      },
    );
  }
}
