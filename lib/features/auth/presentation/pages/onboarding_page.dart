import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  var _loading = true;
  var _levels = const <_ActivityLevel>[];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response =
          await AppDependencies.dioClient.get<Map<String, dynamic>>(
        ApiEndpoints.activityLevels,
      );
      final data = response.data?['data'];
      final levels = data is List
          ? data
              .map(
                (item) => _ActivityLevel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
          : const <_ActivityLevel>[];
      setState(() {
        _levels = levels;
        _selectedId = levels.isEmpty ? null : levels.first.id;
      });
    } catch (_) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Không thể tải mức độ vận động.',
        type: AppAlertType.critical,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Mức độ vận động',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text('Chọn mức độ hoạt động thể chất hàng ngày.'),
              const SizedBox(height: 28),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_levels.isEmpty)
                Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.wifi_off, color: AppTheme.danger),
                    title: const Text('Chưa có dữ liệu'),
                    trailing: TextButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ),
                )
              else
                ..._levels.map(
                  (item) {
                    final selected = item.id == _selectedId;
                    return Card(
                      color: selected ? Colors.white : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color:
                              selected ? item.color : const Color(0xFFE5E7EB),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => setState(() => _selectedId = item.id),
                        leading: CircleAvatar(
                          backgroundColor: selected
                              ? item.color
                              : item.color.withValues(alpha: 0.14),
                          child: Icon(
                            item.icon,
                            color: selected ? Colors.white : item.color,
                          ),
                        ),
                        title: Text(item.name),
                        subtitle: Text(item.description),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle,
                                color: item.color,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Tiếp tục'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityLevel {
  const _ActivityLevel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  factory _ActivityLevel.fromJson(Map<String, dynamic> json) {
    final name = '${json['level_name'] ?? json['name'] ?? ''}';
    final visual = _visualFor(name);
    return _ActivityLevel(
      id: '${json['id'] ?? ''}',
      name: name,
      description: '${json['description'] ?? ''}',
      icon: visual.icon,
      color: visual.color,
    );
  }

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  static _ActivityVisual _visualFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rất') ||
        lower.contains('nặng') ||
        lower.contains('heavy') ||
        lower.contains('very') ||
        lower.contains('athlete')) {
      return const _ActivityVisual(
        icon: Icons.fitness_center,
        color: AppTheme.protein,
      );
    }
    if (lower.contains('cao') ||
        lower.contains('active') ||
        lower.contains('mạnh')) {
      return const _ActivityVisual(
        icon: Icons.directions_run,
        color: AppTheme.accent,
      );
    }
    if (lower.contains('vừa') ||
        lower.contains('moderate') ||
        lower.contains('trung bình')) {
      return const _ActivityVisual(
        icon: Icons.directions_walk,
        color: AppTheme.primary,
      );
    }
    if (lower.contains('nhẹ') ||
        lower.contains('light') ||
        lower.contains('ít')) {
      return const _ActivityVisual(
        icon: Icons.nordic_walking,
        color: AppTheme.secondary,
      );
    }
    return const _ActivityVisual(
      icon: Icons.self_improvement,
      color: AppTheme.outline,
    );
  }
}

class _ActivityVisual {
  const _ActivityVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}
