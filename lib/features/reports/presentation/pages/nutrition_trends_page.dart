import 'package:flutter/material.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/premium_widgets.dart';

class NutritionTrendsPage extends StatefulWidget {
  const NutritionTrendsPage({super.key});

  @override
  State<NutritionTrendsPage> createState() => _NutritionTrendsPageState();
}

class _NutritionTrendsPageState extends State<NutritionTrendsPage> {
  var _rangeDays = 7;
  var _loading = true;
  var _points = const <_TrendPoint>[];
  var _summary = const _MacroSummaryData();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trendsResponse =
          await AppDependencies.dioClient.get<Map<String, dynamic>>(
        ApiEndpoints.nutritionTrends,
        queryParameters: {'days': _rangeDays},
      );
      final summaryResponse =
          await AppDependencies.dioClient.get<Map<String, dynamic>>(
        ApiEndpoints.nutritionSummary,
        queryParameters: {'days': _rangeDays},
      );
      if (!mounted) return;
      setState(() {
        _points = _extractTrendPoints(trendsResponse.data?['data']);
        _summary = _MacroSummaryData.fromJson(summaryResponse.data?['data']);
      });
    } catch (_) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Không thể tải báo cáo dinh dưỡng.',
        type: AppAlertType.warning,
      );
      setState(() {
        _points = _fallbackPoints();
        _summary = const _MacroSummaryData(
          protein: 28,
          carbs: 44,
          fat: 28,
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              'Báo cáo xu hướng',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Theo dõi calories so với TDEE và phân bổ macro.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 ngày')),
                ButtonSegment(value: 30, label: Text('30 ngày')),
              ],
              selected: {_rangeDays},
              onSelectionChanged: (values) {
                setState(() => _rangeDays = values.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const PremiumCard(child: SkeletonBlock(height: 260))
            else ...[
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calories hằng ngày',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: CustomPaint(
                        painter: _TrendChartPainter(_points),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        SourceBadge(
                          label: 'Cân bằng',
                          icon: Icons.circle,
                          color: AppTheme.fat,
                        ),
                        SizedBox(width: 8),
                        SourceBadge(
                          label: 'Vượt mục tiêu',
                          icon: Icons.circle,
                          color: AppTheme.danger,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phân bổ macro',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 180,
                      child: CustomPaint(
                        painter: _MacroDonutPainter(_summary),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_summary.total.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'macro',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Legend('Đạm', _summary.protein, AppTheme.protein),
                        _Legend('Carb', _summary.carbs, AppTheme.carb),
                        _Legend('Béo', _summary.fat, AppTheme.fat),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_TrendPoint> _extractTrendPoints(Object? data) {
    final list = data is List
        ? data
        : data is Map && data['results'] is List
            ? data['results'] as List
            : const [];
    return list
        .whereType<Map>()
        .map((item) => _TrendPoint.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<_TrendPoint> _fallbackPoints() {
    return List.generate(7, (index) {
      final calories = 1650 + index * 90 + (index.isEven ? 120 : -80);
      return _TrendPoint(calories: calories.toDouble(), target: 2100);
    });
  }
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter(this.points);

  final List<_TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxValue = points
        .map((point) =>
            point.calories > point.target ? point.calories : point.target)
        .reduce((a, b) => a > b ? a : b);
    final minValue = 0.0;
    final usableHeight = size.height - 24;
    final stepX =
        points.length == 1 ? size.width : size.width / (points.length - 1);
    double yFor(double value) {
      final ratio = (value - minValue) / (maxValue - minValue);
      return usableHeight - ratio * usableHeight + 12;
    }

    final targetPaint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final targetY = yFor(points.first.target);
    canvas.drawLine(
        Offset(0, targetY), Offset(size.width, targetY), targetPaint);

    final linePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = Offset(i * stepX, yFor(points[i].calories));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final point = Offset(i * stepX, yFor(points[i].calories));
      final color = points[i].calories > points[i].target
          ? AppTheme.danger
          : AppTheme.fat;
      canvas.drawCircle(point, 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _MacroDonutPainter extends CustomPainter {
  const _MacroDonutPainter(this.summary);

  final _MacroSummaryData summary;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.shortestSide / 2 - 12,
    );
    var start = -90.0;
    for (final item in [
      (summary.protein, AppTheme.protein),
      (summary.carbs, AppTheme.carb),
      (summary.fat, AppTheme.fat),
    ]) {
      final sweep = item.$1 / summary.total * 360;
      canvas.drawArc(
        rect,
        start * 3.14159 / 180,
        sweep * 3.14159 / 180,
        false,
        Paint()
          ..color = item.$2
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) {
    return oldDelegate.summary != summary;
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(Icons.circle, size: 11, color: color),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _TrendPoint {
  const _TrendPoint({required this.calories, required this.target});

  factory _TrendPoint.fromJson(Map<String, dynamic> json) {
    return _TrendPoint(
      calories: _number(json, const ['calories', 'total_calories', 'intake']),
      target: _number(json, const ['target', 'tdee', 'calorie_goal']),
    );
  }

  final double calories;
  final double target;
}

class _MacroSummaryData {
  const _MacroSummaryData({
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  factory _MacroSummaryData.fromJson(Object? data) {
    if (data is! Map) return const _MacroSummaryData();
    final map = Map<String, dynamic>.from(data);
    return _MacroSummaryData(
      protein: _number(map, const ['protein_percent', 'protein']),
      carbs: _number(map, const ['carbs_percent', 'carbs', 'carbohydrate']),
      fat: _number(map, const ['fat_percent', 'fat']),
    ).normalized();
  }

  final double protein;
  final double carbs;
  final double fat;

  double get total {
    final value = protein + carbs + fat;
    return value <= 0 ? 100 : value;
  }

  _MacroSummaryData normalized() {
    if (total > 0 && total != 100) {
      return _MacroSummaryData(
        protein: protein / total * 100,
        carbs: carbs / total * 100,
        fat: fat / total * 100,
      );
    }
    return this;
  }
}

double _number(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse('$value');
    if (parsed != null) return parsed;
  }
  return 0;
}
