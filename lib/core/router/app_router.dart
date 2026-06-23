import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/capture/presentation/pages/ar_capture_page.dart';
import '../../features/capture/presentation/pages/capture_gate.dart';
import '../../features/food_scan/presentation/pages/camera_scan_page.dart';
import '../../features/food_scan/presentation/pages/scan_processing_page.dart';
import '../../features/food_scan/presentation/pages/scan_result_page.dart';
import '../../features/meal_entry/presentation/pages/barcode_scan_page.dart';
import '../../features/meal_detail/presentation/pages/meal_detail_page.dart';
import '../../features/meal_entry/presentation/pages/manual_meal_page.dart';
import '../../features/meal_history/presentation/pages/diary_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/nutrition/presentation/pages/home_page.dart';
import '../../features/auth/presentation/bloc/change_password_cubit.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/food_scan/presentation/cubit/scan_feedback_cubit.dart';
import '../../features/food_scan/presentation/pages/scan_feedback_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reports/presentation/pages/nutrition_trends_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/shared_placeholder/presentation/pages/premium_placeholder_page.dart';
import '../di/app_dependencies.dart';
import '../theme/app_theme.dart';

class AppRouter {
  const AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => OtpPage(email: state.extra as String?),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      // `/scan` is the capability gate; it forwards to the AR or plain capture
      // screen. Existing `context.go('/scan')` calls keep working unchanged.
      GoRoute(path: '/scan', builder: (context, state) => const CaptureGate()),
      GoRoute(
        path: '/scan/plain',
        builder: (context, state) => const CameraScanPage(),
      ),
      GoRoute(
        path: '/scan/ar',
        builder: (context, state) => const ArCapturePage(),
      ),
      GoRoute(
        path: '/scan-processing',
        builder: (context, state) => const ScanProcessingPage(),
      ),
      GoRoute(
        path: '/scan-result',
        builder: (context, state) => const ScanResultPage(),
      ),
      GoRoute(path: '/diary', builder: (context, state) => const DiaryPage()),
      GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfilePage()),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/barcode-scan',
        builder: (context, state) => const BarcodeScanPage(),
      ),
      GoRoute(
        path: '/meals/manual',
        builder: (context, state) => const ManualMealPage(),
      ),
      GoRoute(
        path: '/meals/detail/:id',
        builder: (context, state) => MealDetailPage(
          mealId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reports/trends',
        builder: (context, state) => const NutritionTrendsPage(),
      ),
      GoRoute(
        path: '/scan-result/feedback',
        builder: (context, state) {
          final jobId = state.extra as String? ?? '';
          return BlocProvider(
            create: (_) => ScanFeedbackCubit(AppDependencies.foodScanRepository),
            child: ScanFeedbackPage(jobId: jobId),
          );
        },
      ),
      GoRoute(
        path: '/password-change',
        builder: (context, state) => BlocProvider(
          create: (_) => ChangePasswordCubit(AppDependencies.authRepository),
          child: const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: '/password-forgot',
        builder: (context, state) => const PremiumPlaceholderPage(
          title: 'Khôi phục mật khẩu',
          subtitle: 'Gửi OTP khôi phục và đặt lại mật khẩu mới.',
          icon: Icons.key_outlined,
          accentColor: AppTheme.accent,
          items: [
            'Nhập email tài khoản.',
            'Xác thực mã OTP.',
            'Đặt mật khẩu mới qua password reset API.',
          ],
        ),
      ),
    ],
  );
}
