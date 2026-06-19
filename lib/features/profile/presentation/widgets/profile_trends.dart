import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/premium_widgets.dart';

/// Profile analytics: real weight-history and nutrition-trend charts backed by
///   GET /accounts/profile/weight-history/
///   GET /reports/nutrition/trends/
class ProfileTrends extends StatefulWidget {
  const ProfileTrends({super.key});

  @override
  State<ProfileTrends> createState() => _ProfileTrendsState();
}

class _ProfileTrendsState extends State<ProfileTrends> {
  static const _rangeDays = 30;

  var _loading = true;
  // Weight history and nutrition trends load independently so a failure in one
  // does not blank out the other.
  var _weightFailed = false;
  var _trendFailed = false;
  String? _weightErrorDetail;
  String? _trendErrorDetail;
  List<_WeightPoint> _weights = const [];
  List<_TrendPoint> _trends = const [];
  _TrendMetric _metric = _TrendMetric.calories;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _weightFailed = false;
        _trendFailed = false;
        _weightErrorDetail = null;
        _trendErrorDetail = null;
      });
    }
    final today = DateTime.now();
    final from = today.subtract(const Duration(days: _rangeDays - 1));
    final params = {'from': _dateValue(from), 'to': _dateValue(today)};

    var weights = const <_WeightPoint>[];
    var trends = const <_TrendPoint>[];
    String? weightError;
    String? trendError;

    await Future.wait([
      () async {
        try {
          final res = await AppDependencies.dioClient.get<Map<String, dynamic>>(
            ApiEndpoints.weightHistory,
            queryParameters: params,
          );
          weights = _WeightPoint.listFrom(res.data?['data']);
        } catch (error, stackTrace) {
          weightError = _describeError(
            'weight-history',
            ApiEndpoints.weightHistory,
            params,
            error,
            stackTrace,
          );
        }
      }(),
      () async {
        try {
          final res = await AppDependencies.dioClient.get<Map<String, dynamic>>(
            ApiEndpoints.nutritionTrends,
            queryParameters: params,
          );
          trends = _TrendPoint.listFrom(res.data?['data']);
        } catch (error, stackTrace) {
          trendError = _describeError(
            'nutrition-trends',
            ApiEndpoints.nutritionTrends,
            params,
            error,
            stackTrace,
          );
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _weights = weights;
      _trends = trends;
      _weightFailed = weightError != null;
      _trendFailed = trendError != null;
      _weightErrorDetail = weightError;
      _trendErrorDetail = trendError;
      _loading = false;
    });
  }

  /// Logs the full failure and returns a short human-readable detail
  /// (HTTP status + server message) for display in debug builds.
  String _describeError(
    String label,
    String path,
    Map<String, dynamic> params,
    Object error,
    StackTrace stackTrace,
  ) {
    String detail;
    if (error is ApiException) {
      final status = error.statusCode ?? '—';
      detail = 'HTTP $status · ${error.message}';
      debugPrint(
        '[ProfileTrends] $label failed: GET $path $params '
        '→ status=$status, message="${error.message}", body=${error.data}',
      );
    } else {
      detail = error.toString();
      debugPrint('[ProfileTrends] $label failed: GET $path $params → $error');
    }
    debugPrintStack(stackTrace: stackTrace, maxFrames: 4);
    return detail;
  }

  String _dateValue(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PremiumCard(child: SkeletonBlock(height: 150));
    }
    return Column(
      children: [
        if (_weightFailed)
          _TrendErrorCard(
            message: 'Không thể tải lịch sử cân nặng.',
            detail: _weightErrorDetail,
            onRetry: _load,
          )
        else
          _WeightTrendCard(points: _weights),
        const SizedBox(height: 12),
        if (_trendFailed)
          _TrendErrorCard(
            message: 'Không thể tải xu hướng dinh dưỡng.',
            detail: _trendErrorDetail,
            onRetry: _load,
          )
        else
          _NutritionTrendCard(
            points: _trends,
            metric: _metric,
            onMetricChanged: (metric) => setState(() => _metric = metric),
          ),
      ],
    );
  }
}

class _TrendErrorCard extends StatelessWidget {
  const _TrendErrorCard({
    required this.message,
    required this.onRetry,
    this.detail,
  });

  final String message;
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off, color: AppTheme.danger),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
          // Surface the real status/message in debug builds so the failure is
          // diagnosable without attaching a debugger.
          if (kDebugMode && detail != null && detail!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 2, right: 8),
              child: Text(
                detail!,
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Weight trend
// ─────────────────────────────────────────────────────────────────────────

class _WeightTrendCard extends StatelessWidget {
  const _WeightTrendCard({required this.points});

  final List<_WeightPoint> points;

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.weight).toList();
    final hasData = values.length >= 2;
    final latest = values.isNotEmpty ? values.last : 0.0;
    final first = values.isNotEmpty ? values.first : 0.0;
    final delta = latest - first;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.primaryContainer,
                child: Icon(Icons.monitor_weight_outlined,
                    color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Xu hướng cân nặng',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (values.isNotEmpty)
                Text(
                  '${latest.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasData)
            const _EmptyTrend(
              message: 'Chưa đủ dữ liệu cân nặng để vẽ biểu đồ.',
            )
          else ...[
            SizedBox(
              height: 96,
              child: _MiniLineChart(
                values: values,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  delta > 0
                      ? Icons.trending_up
                      : delta < 0
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  size: 18,
                  color: delta > 0 ? AppTheme.danger : AppTheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  delta == 0
                      ? 'Ổn định trong kỳ'
                      : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg so với đầu kỳ',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Nutrition trend
// ─────────────────────────────────────────────────────────────────────────

enum _TrendMetric { calories, protein, carbs, fat }

extension on _TrendMetric {
  String get label => switch (this) {
        _TrendMetric.calories => 'Calories',
        _TrendMetric.protein => 'Đạm',
        _TrendMetric.carbs => 'Carb',
        _TrendMetric.fat => 'Béo',
      };

  String get unit => this == _TrendMetric.calories ? 'kcal' : 'g';

  Color get color => switch (this) {
        _TrendMetric.calories => AppTheme.primary,
        _TrendMetric.protein => AppTheme.protein,
        _TrendMetric.carbs => AppTheme.carb,
        _TrendMetric.fat => AppTheme.fat,
      };

  double valueOf(_TrendPoint point) => switch (this) {
        _TrendMetric.calories => point.calories,
        _TrendMetric.protein => point.protein,
        _TrendMetric.carbs => point.carbs,
        _TrendMetric.fat => point.fat,
      };
}

class _NutritionTrendCard extends StatelessWidget {
  const _NutritionTrendCard({
    required this.points,
    required this.metric,
    required this.onMetricChanged,
  });

  final List<_TrendPoint> points;
  final _TrendMetric metric;
  final ValueChanged<_TrendMetric> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final values = points.map(metric.valueOf).toList();
    final hasData = values.length >= 2;
    final average = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.primaryContainer,
                child: Icon(Icons.show_chart, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Xu hướng dinh dưỡng',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (hasData)
                Text(
                  'TB ${average.toStringAsFixed(0)} ${metric.unit}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _TrendMetric.values.map((m) {
              final selected = m == metric;
              return ChoiceChip(
                label: Text(m.label),
                selected: selected,
                onSelected: (_) => onMetricChanged(m),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
                selectedColor: m.color,
                backgroundColor: AppTheme.primaryContainer.withValues(alpha: 0.4),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          if (!hasData)
            const _EmptyTrend(
              message: 'Chưa đủ dữ liệu để vẽ biểu đồ xu hướng.',
            )
          else
            SizedBox(
              height: 96,
              child: _MiniLineChart(values: values, color: metric.color),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared chart + helpers
// ─────────────────────────────────────────────────────────────────────────

class _EmptyTrend extends StatelessWidget {
  const _EmptyTrend({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return CustomPaint(
          painter: _LineChartPainter(
            values: values,
            color: color,
            progress: progress,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.color,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 1e-6 ? 1.0 : maxValue - minValue;
    const padTop = 8.0;
    const padBottom = 8.0;
    final usableHeight = size.height - padTop - padBottom;
    final stepX = size.width / (values.length - 1);

    Offset offsetAt(int index) {
      final normalized = (values[index] - minValue) / span;
      final y = padTop + (1 - normalized) * usableHeight;
      return Offset(stepX * index, y);
    }

    final path = Path()..moveTo(offsetAt(0).dx, offsetAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(offsetAt(i).dx, offsetAt(i).dy);
    }

    // Gradient fill below the line.
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
    canvas.restore();

    // Endpoint marker (drawn once the line has animated past it).
    if (progress > 0.96) {
      final last = offsetAt(values.length - 1);
      canvas.drawCircle(last, 4, Paint()..color = color);
      canvas.drawCircle(
        last,
        4,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.values != values ||
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────

class _WeightPoint {
  const _WeightPoint({required this.date, required this.weight});

  static List<_WeightPoint> listFrom(Object? payload) {
    final list = payload is List ? payload : const [];
    final points = <_WeightPoint>[];
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final weight = _toDouble(map['weight']);
      if (weight <= 0) continue;
      points.add(
        _WeightPoint(
          date: DateTime.tryParse('${map['measured_at']}') ?? DateTime.now(),
          weight: weight,
        ),
      );
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  final DateTime date;
  final double weight;
}

class _TrendPoint {
  const _TrendPoint({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static List<_TrendPoint> listFrom(Object? payload) {
    final list = payload is List ? payload : const [];
    final points = <_TrendPoint>[];
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      points.add(
        _TrendPoint(
          date: DateTime.tryParse('${map['date']}') ?? DateTime.now(),
          calories: _toDouble(map['calories'] ?? map['total_calories']),
          protein: _toDouble(map['protein'] ?? map['total_protein']),
          carbs: _toDouble(map['carbs'] ?? map['total_carbs']),
          fat: _toDouble(map['fat'] ?? map['total_fat']),
        ),
      );
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  final DateTime date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
