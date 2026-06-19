import 'package:flutter/material.dart';

enum AppAlertType { success, warning, critical }

class AppAlerts {
  const AppAlerts._();

  static void showToast(
    BuildContext context, {
    required String message,
    AppAlertType type = AppAlertType.success,
    Duration duration = const Duration(seconds: 4),
  }) {
    final theme = _theme(type);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.background,
          content: Row(
            children: [
              Icon(theme.icon, color: theme.foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  friendlyMessage(message, type: type),
                  style: TextStyle(
                    color: theme.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static Future<void> showCriticalDialog(
    BuildContext context, {
    required String message,
    String confirmLabel = 'Đã hiểu',
    VoidCallback? onRetry,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.error_outline, color: Color(0xFFBA1A1A)),
          title: const Text('Không thể tiếp tục'),
          content: Text(
            friendlyMessage(message, type: AppAlertType.critical),
          ),
          actions: [
            if (onRetry != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  static String friendlyMessage(
    String message, {
    AppAlertType type = AppAlertType.warning,
  }) {
    final lower = message.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('failed host lookup')) {
      return 'Kết nối bị gián đoạn. Vui lòng kiểm tra mạng và thử lại.';
    }
    if (lower.contains('internal server') ||
        lower.contains('error 500') ||
        lower.contains('null pointer') ||
        lower.contains('bad request')) {
      return type == AppAlertType.critical
          ? 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.'
          : 'Yêu cầu chưa được xử lý. Vui lòng kiểm tra lại thông tin.';
    }
    if (lower.contains('invalid credentials')) {
      return 'Email hoặc mật khẩu không đúng.';
    }
    if (lower.contains('account not verified')) {
      return 'Tài khoản chưa được xác thực OTP.';
    }
    if (lower.contains('unauthorized')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (message.trim().isEmpty) {
      return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
    return message;
  }

  static _AlertTheme _theme(AppAlertType type) {
    switch (type) {
      case AppAlertType.success:
        return const _AlertTheme(
          background: Color(0xFFEAF8F0),
          foreground: Color(0xFF2D6A4F),
          icon: Icons.check_circle,
        );
      case AppAlertType.warning:
        return const _AlertTheme(
          background: Color(0xFFFFF3D6),
          foreground: Color(0xFF7A4A00),
          icon: Icons.warning_amber,
        );
      case AppAlertType.critical:
        return const _AlertTheme(
          background: Color(0xFFFFE2E5),
          foreground: Color(0xFFE63946),
          icon: Icons.wifi_off,
        );
    }
  }
}

class _AlertTheme {
  const _AlertTheme({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}
