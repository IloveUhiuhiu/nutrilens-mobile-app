import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_alerts.dart';
import '../../../../shared/widgets/app_chrome.dart';
import '../bloc/change_password_cubit.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<ChangePasswordCubit>();
    await cubit.changePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;
    final state = cubit.state;
    if (state.succeeded) {
      AppAlerts.showToast(
        context,
        message: 'Đổi mật khẩu thành công.',
        type: AppAlertType.success,
      );
      context.pop();
    } else {
      final oldError = state.fieldErrors['old_password'];
      final newError = state.fieldErrors['new_password'];
      final detailError = state.fieldErrors['detail'];
      final displayMessage = oldError ?? newError ?? detailError ?? state.errorMessage ?? 'Không thể đổi mật khẩu.';
      AppAlerts.showToast(
        context,
        message: displayMessage,
        type: AppAlertType.critical,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: BlocBuilder<ChangePasswordCubit, ChangePasswordState>(
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Đổi mật khẩu',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nhập mật khẩu hiện tại và mật khẩu mới để cập nhật.',
                  style: TextStyle(color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: !_showOld,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    errorText: state.fieldErrors['old_password'],
                    suffixIcon: IconButton(
                      icon: Icon(_showOld ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showOld = !_showOld),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu hiện tại.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_showNew,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
                    errorText: state.fieldErrors['new_password'],
                    suffixIcon: IconButton(
                      icon: Icon(_showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showNew = !_showNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới.';
                    if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_showConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    suffixIcon: IconButton(
                      icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu mới.';
                    if (v != _newPasswordController.text) return 'Mật khẩu xác nhận không khớp.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isLoading ? null : _submit,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Đổi mật khẩu'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
