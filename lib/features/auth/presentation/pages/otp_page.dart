import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/app_dependencies.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_alerts.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key, this.email});

  final String? email;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _otpController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final email = widget.email?.trim();
    final otp = _otpController.text.trim();
    if (email == null || email.isEmpty) {
      AppAlerts.showToast(
        context,
        message: 'Không tìm thấy email cần xác thực.',
        type: AppAlertType.warning,
      );
      return;
    }
    if (otp.length != 6) {
      AppAlerts.showToast(
        context,
        message: 'Vui lòng nhập mã OTP gồm 6 số.',
        type: AppAlertType.warning,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AppDependencies.authRepository.verifyOtp(
        email: email,
        otpCode: otp,
      );
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Xác thực tài khoản thành công.',
        type: AppAlertType.success,
      );
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: _messageFromError(error),
        type: AppAlertType.warning,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final email = widget.email?.trim();
    if (email == null || email.isEmpty) return;
    setState(() => _loading = true);
    try {
      await AppDependencies.authRepository.requestOtp(email);
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: 'Đã gửi lại mã OTP.',
        type: AppAlertType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AppAlerts.showToast(
        context,
        message: _messageFromError(error),
        type: AppAlertType.warning,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFromError(Object error) {
    if (error is ApiException) return error.message;
    return 'Không thể xác thực OTP. Vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/register'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFE4F7EC),
                    child: Icon(
                      Icons.mark_email_read,
                      color: AppTheme.primary,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Xác thực OTP',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email == null
                        ? 'Nhập mã 6 số đã gửi đến email của bạn.'
                        : 'Nhập mã 6 số đã gửi đến ${widget.email}.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _otpController,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      counterText: '',
                      labelText: 'Mã OTP',
                      prefixIcon: Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Xác thực'),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _resend,
                    child: const Text('Gửi lại mã'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
