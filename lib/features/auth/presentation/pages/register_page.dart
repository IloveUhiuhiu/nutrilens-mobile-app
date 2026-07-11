import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  var _step = 0;
  var _obscurePassword = true;
  var _loadingLevels = false;
  var _levels = const <_ActivityLevel>[];
  String? _selectedLevelId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadActivityLevels() async {
    if (_levels.isNotEmpty || _loadingLevels) return;
    setState(() => _loadingLevels = true);
    try {
      final response =
          await AppDependencies.dioClient.get<Map<String, dynamic>>(
        ApiEndpoints.activityLevels,
      );
      final data = response.data?['data'];
      final levels = data is List
          ? data
              .whereType<Map>()
              .map((item) => _ActivityLevel.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const <_ActivityLevel>[];
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _selectedLevelId = levels.isEmpty ? null : levels.first.id;
      });
    } catch (_) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Không thể tải mức độ vận động.',
        type: AppAlertType.warning,
      );
    } finally {
      if (mounted) setState(() => _loadingLevels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            AppAlerts.showToast(
              context,
              message: 'Mã OTP đã được gửi đến email của bạn.',
              type: AppAlertType.success,
            );
            context.push('/otp', extra: state.session.user.email);
          }
          if (state is AuthError) {
            AppAlerts.showToast(
              context,
              message: state.message,
              type: AppAlertType.warning,
            );
          }
        },
        builder: (context, state) {
          final loading = state is Authenticating;
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 460,
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          _RegisterHeader(step: _step),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: switch (_step) {
                              0 => _CredentialsStep(
                                  key: const ValueKey('credentials'),
                                  nameController: _nameController,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  obscurePassword: _obscurePassword,
                                  onTogglePassword: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              1 => _MetricsStep(
                                  key: const ValueKey('metrics'),
                                  weightController: _weightController,
                                  heightController: _heightController,
                                  onChanged: () => setState(() {}),
                                ),
                              _ => _ActivityStep(
                                  key: const ValueKey('activity'),
                                  loading: _loadingLevels,
                                  levels: _levels,
                                  selectedId: _selectedLevelId,
                                  onSelected: (id) =>
                                      setState(() => _selectedLevelId = id),
                                  onRetry: _loadActivityLevels,
                                ),
                            },
                          ),
                          const SizedBox(height: 24),
                          _WizardActions(
                            step: _step,
                            loading: loading,
                            onBack: _step == 0
                                ? () => context.go('/login')
                                : () => setState(() => _step--),
                            onNext: loading ? null : _next,
                          ),
                          TextButton(
                            onPressed:
                                loading ? null : () => context.go('/login'),
                            child: const Text('Đã có tài khoản? Đăng nhập'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _next() {
    if (_step == 0) {
      if (!_validateCredentials()) return;
      _ensureMetricDefaults();
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!_validateMetrics()) return;
      setState(() => _step = 2);
      _loadActivityLevels();
      return;
    }
    _submit();
  }

  bool _validateCredentials() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (name.isEmpty) {
      _warn('Vui lòng nhập họ và tên.');
      return false;
    }
    if (!emailRegex.hasMatch(email)) {
      _warn('Email không đúng định dạng.');
      return false;
    }
    if (password.length < 6) {
      _warn('Mật khẩu cần tối thiểu 6 ký tự.');
      return false;
    }
    return true;
  }

  bool _validateMetrics() {
    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    if (weight == null || weight <= 0) {
      _warn('Cân nặng phải là số lớn hơn 0.');
      return false;
    }
    if (height == null || height <= 0) {
      _warn('Chiều cao phải là số lớn hơn 0.');
      return false;
    }
    return true;
  }

  void _ensureMetricDefaults() {
    if (_weightController.text.trim().isEmpty) {
      _weightController.text = '60.0';
    }
    if (_heightController.text.trim().isEmpty) {
      _heightController.text = '170';
    }
  }

  void _submit() {
    final weight = double.parse(_weightController.text.trim());
    final height = double.parse(_heightController.text.trim());
    context.read<AuthBloc>().add(
          AuthRegisterRequested(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            weightKg: weight,
            heightCm: height,
            activityLevelId: _selectedLevelId,
          ),
        );
  }

  void _warn(String message) {
    AppAlerts.showToast(
      context,
      message: message,
      type: AppAlertType.warning,
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandMark(size: 92, borderRadius: 24, showShadow: true),
        const SizedBox(height: 16),
        const Text(
          'Tạo tài khoản NutriLens',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        _ProgressBar(step: step),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final active = index <= step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              height: 8,
              decoration: BoxDecoration(
                color: active ? AppTheme.primary : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CredentialsStep extends StatelessWidget {
  const _CredentialsStep({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            icon: Icons.person_add_alt_1,
            title: 'Bước 1: Tài khoản',
            subtitle:
                'Nhập thông tin đăng nhập bằng tiếng Việt hoặc tiếng Anh.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsStep extends StatelessWidget {
  const _MetricsStep({
    super.key,
    required this.weightController,
    required this.heightController,
    required this.onChanged,
  });

  final TextEditingController weightController;
  final TextEditingController heightController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            icon: Icons.monitor_heart_outlined,
            title: 'Bước 2: Chỉ số cơ thể',
            subtitle: 'Các chỉ số này dùng để tính nhu cầu năng lượng.',
          ),
          const SizedBox(height: 18),
          RulerMetricInput(
            label: 'Cân nặng',
            value: double.tryParse(weightController.text.trim()) ?? 60,
            min: 30,
            max: 180,
            step: 0.5,
            unit: 'kg',
            icon: Icons.scale,
            color: AppTheme.secondary,
            onChanged: (value) {
              weightController.text = value.toStringAsFixed(1);
              onChanged();
            },
          ),
          const SizedBox(height: 14),
          RulerMetricInput(
            label: 'Chiều cao',
            value: double.tryParse(heightController.text.trim()) ?? 170,
            min: 120,
            max: 220,
            step: 1,
            unit: 'cm',
            icon: Icons.straighten,
            color: AppTheme.primary,
            onChanged: (value) {
              heightController.text = value.toStringAsFixed(0);
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityStep extends StatelessWidget {
  const _ActivityStep({
    super.key,
    required this.loading,
    required this.levels,
    required this.selectedId,
    required this.onSelected,
    required this.onRetry,
  });

  final bool loading;
  final List<_ActivityLevel> levels;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            icon: Icons.directions_run,
            title: 'Bước 3: Mức độ vận động',
            subtitle: 'Chọn mức phù hợp nhất với nhịp sinh hoạt của bạn.',
          ),
          const SizedBox(height: 18),
          if (loading)
            const SkeletonBlock(height: 220)
          else if (levels.isEmpty)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại mức độ vận động'),
            )
          else
            ...levels.map(
              (level) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PressableScale(
                  onTap: () => onSelected(level.id),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: level.id == selectedId
                            ? level.color
                            : const Color(0xFFE5E7EB),
                        width: level.id == selectedId ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: level.color.withValues(alpha: 0.14),
                        child: Icon(level.icon, color: level.color),
                      ),
                      title: Text(
                        level.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(level.description),
                      trailing: level.id == selectedId
                          ? Icon(
                              Icons.check_circle,
                              color: level.color,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppTheme.primaryContainer,
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.step,
    required this.loading,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: loading ? null : onBack,
            icon: const Icon(Icons.arrow_back),
            label: Text(step == 0 ? 'Đăng nhập' : 'Quay lại'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNext,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(step == 2 ? Icons.check : Icons.arrow_forward),
            label: Text(step == 2 ? 'Hoàn tất' : 'Tiếp theo'),
          ),
        ),
      ],
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
