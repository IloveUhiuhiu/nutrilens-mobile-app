import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../../../../shared/widgets/premium_widgets.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../data/models/activity_level.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _initialized = false;
  bool _uploadingAvatar = false;
  int? _selectedActivityLevelId;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _fill(ProfileState state) {
    if (_initialized) return;
    final profile = state.profile;
    _nameController.text = profile.name;
    _phoneController.text = profile.phoneNumber ?? '';
    _heightController.text =
        profile.heightCm == 0 ? '' : profile.heightCm.toStringAsFixed(0);
    _weightController.text =
        profile.weightKg == 0 ? '' : profile.weightKg.toStringAsFixed(1);
    _selectedActivityLevelId ??= profile.activityLevelId;
    _initialized = true;
  }

  Future<void> _save() async {
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        height == null ||
        weight == null) {
      AppAlerts.showToast(
        context,
        message: 'Vui lòng nhập đầy đủ họ tên, chiều cao và cân nặng.',
        type: AppAlertType.warning,
      );
      return;
    }

    final profileCubit = context.read<ProfileCubit>();
    await profileCubit.updateProfile(
      name: _nameController.text.trim(),
      heightCm: height,
      weightKg: weight,
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      activityLevelId: _selectedActivityLevelId,
    );
    if (!mounted) return;
    if (profileCubit.state.updateSucceeded) {
      AppAlerts.showToast(
        context,
        message: 'Cập nhật thông tin thành công.',
        type: AppAlertType.success,
      );
      context.pop();
    } else {
      AppAlerts.showToast(
        context,
        message: profileCubit.state.errorMessage ?? 'Không thể cập nhật hồ sơ.',
        type: AppAlertType.critical,
      );
    }
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
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (image == null) return;
    setState(() => _uploadingAvatar = true);
    await profileCubit.uploadAvatar(image.path);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    if (profileCubit.state.updateSucceeded) {
      AppAlerts.showToast(
        context,
        message: 'Đã cập nhật ảnh đại diện.',
        type: AppAlertType.success,
      );
    } else {
      AppAlerts.showToast(
        context,
        message: profileCubit.state.errorMessage ?? 'Không thể cập nhật ảnh đại diện.',
        type: AppAlertType.critical,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          _fill(state);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Thông tin cá nhân',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cập nhật chỉ số cơ thể để tính TDEE chính xác hơn.',
                style: TextStyle(color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 18),
              PremiumCard(
                child: Column(
                  children: [
                    _EditableProfileAvatar(
                      name: state.profile.name,
                      imageUrl: state.profile.avatarUrl,
                      uploading: _uploadingAvatar,
                      onTap: _changeAvatar,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Họ và tên'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: state.profile.email,
                      enabled: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 16),
                    RulerMetricInput(
                      label: 'Chiều cao',
                      value: double.tryParse(_heightController.text.trim()) ??
                          (state.profile.heightCm > 0
                              ? state.profile.heightCm
                              : 170),
                      min: 120,
                      max: 220,
                      step: 1,
                      unit: 'cm',
                      icon: Icons.straighten,
                      color: AppTheme.primary,
                      onChanged: (value) {
                        setState(() {
                          _heightController.text = value.toStringAsFixed(0);
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    RulerMetricInput(
                      label: 'Cân nặng',
                      value: double.tryParse(_weightController.text.trim()) ??
                          (state.profile.weightKg > 0
                              ? state.profile.weightKg
                              : 60),
                      min: 30,
                      max: 180,
                      step: 0.5,
                      unit: 'kg',
                      icon: Icons.scale,
                      color: AppTheme.secondary,
                      onChanged: (value) {
                        setState(() {
                          _weightController.text = value.toStringAsFixed(1);
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      decoration:
                          const InputDecoration(labelText: 'Số điện thoại'),
                      keyboardType: TextInputType.phone,
                    ),
                    if (state.activityLevels.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ActivityLevelSelector(
                        levels: state.activityLevels,
                        selectedId: _selectedActivityLevelId,
                        onChanged: (id) =>
                            setState(() => _selectedActivityLevelId = id),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: state.loading ? null : _save,
                child: state.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu thay đổi'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityLevelSelector extends StatelessWidget {
  const _ActivityLevelSelector({
    required this.levels,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ActivityLevel> levels;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.directions_run, size: 16, color: AppTheme.textSecondary),
            SizedBox(width: 6),
            Text(
              'Mức độ vận động',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...levels.map(
          (level) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActivityLevelCard(
              level: level,
              selected: level.id == selectedId,
              onTap: () => onChanged(level.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityLevelCard extends StatelessWidget {
  const _ActivityLevelCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final ActivityLevel level;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    final r = level.ratio;
    if (r < 1.3) return Icons.weekend_outlined;
    if (r < 1.5) return Icons.directions_walk;
    if (r < 1.7) return Icons.directions_run;
    if (r < 1.9) return Icons.fitness_center;
    return Icons.bolt;
  }

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppTheme.primary : AppTheme.outline;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryContainer.withValues(alpha: 0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          level.levelName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '×${level.ratio.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (level.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      level.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableProfileAvatar extends StatelessWidget {
  const _EditableProfileAvatar({
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
      width: 104,
      height: 104,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppTheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  UserAvatar(name: name, imageUrl: imageUrl, radius: 52),
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
