import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';
import '../widgets/profile_trends.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  var _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProfileCubit>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final profile = state.profile;
          return RefreshIndicator(
            onRefresh: () => context.read<ProfileCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.loading) const LinearProgressIndicator(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _EditableAvatar(
                          name: profile.name,
                          imageUrl: profile.avatarUrl,
                          uploading: _uploadingAvatar,
                          onTap: _changeAvatar,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile.name.isEmpty
                              ? 'Người dùng NutriLens'
                              : profile.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  PremiumCard(
                    borderColor: AppTheme.danger.withValues(alpha: 0.35),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: AppTheme.danger),
                        const SizedBox(width: 12),
                        Expanded(child: Text(state.errorMessage!)),
                        TextButton(
                          onPressed: () => context.read<ProfileCubit>().load(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.18,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    MetricBadge(
                      label: 'Chiều cao',
                      value: '${profile.heightCm.toStringAsFixed(0)} cm',
                      icon: Icons.straighten,
                      color: AppTheme.primary,
                    ),
                    MetricBadge(
                      label: 'Cân nặng',
                      value: '${profile.weightKg.toStringAsFixed(1)} kg',
                      icon: Icons.scale,
                      color: AppTheme.secondary,
                    ),
                    MetricBadge(
                      label: _bmiLabel(profile.bmi),
                      value: profile.bmi.toStringAsFixed(1),
                      icon: Icons.monitor_heart_outlined,
                      color: _bmiColor(profile.bmi),
                    ),
                    MetricBadge(
                      label: 'TDEE',
                      value: '${profile.tdee.toStringAsFixed(0)} kcal',
                      icon: Icons.local_fire_department_outlined,
                      color: AppTheme.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PremiumCard(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppTheme.primaryContainer,
                        child:
                            Icon(Icons.directions_run, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vận động',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              profile.activityLevel.isEmpty
                                  ? 'Chưa cập nhật'
                                  : profile.activityLevel,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const ProfileTrends(),
                const SizedBox(height: 12),
                PremiumCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.person_outline,
                        title: 'Cập nhật hồ sơ',
                        onTap: () => context.push('/profile/edit'),
                      ),
                      _ActionTile(
                        icon: Icons.lock_outline,
                        title: 'Đổi mật khẩu',
                        onTap: () => context.push('/password-change'),
                      ),
                      _ActionTile(
                        icon: Icons.menu_book_outlined,
                        title: 'Xem nhật ký ăn uống',
                        onTap: () => context.go('/diary'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AuthBloc>().add(const AuthLogoutRequested());
                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _bmiLabel(double bmi) {
    if (bmi <= 0) return 'BMI';
    if (bmi < 18.5) return 'BMI thấp';
    if (bmi < 25) return 'BMI tốt';
    if (bmi < 30) return 'BMI cao';
    return 'BMI nguy cơ';
  }

  Color _bmiColor(double bmi) {
    if (bmi <= 0) return AppTheme.outline;
    if (bmi < 18.5) return AppTheme.accent;
    if (bmi < 25) return AppTheme.secondary;
    if (bmi < 30) return AppTheme.accent;
    return AppTheme.danger;
  }

  Future<void> _changeAvatar() async {
    final profileCubit = context.read<ProfileCubit>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Chụp ảnh mới'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Chọn từ thư viện'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (image == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      await profileCubit.uploadAvatar(image.path);
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Đã cập nhật ảnh đại diện.',
        type: AppAlertType.success,
      );
    } catch (_) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Không thể cập nhật ảnh đại diện.',
        type: AppAlertType.critical,
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.name,
    required this.imageUrl,
    required this.uploading,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  UserAvatar(name: name, imageUrl: imageUrl, radius: 51),
                  if (uploading)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 4,
            child: IconButton.filled(
              onPressed: uploading ? null : onTap,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: const Color(0xFF2B1B00),
                side: const BorderSide(color: Colors.white, width: 3),
              ),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
