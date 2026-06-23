import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/app_dependencies.dart';

/// First screen the app shows. Resolves any saved session before deciding
/// whether to land on the home tab or the login screen, so a valid session
/// doesn't force the user through login on every app restart.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final restored = await AppDependencies.authRepository.tryRestoreSession();
    if (!mounted) return;
    context.go(restored ? '/' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
