import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/profile/presentation/bloc/profile_state.dart';
import 'premium_widgets.dart';
import 'user_avatar.dart';

class NutriTopBar extends StatelessWidget {
  const NutriTopBar({
    super.key,
    this.title = 'NutriLens',
    this.showAvatar = true,
  });

  final String title;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          PressableScale(
            onTap: () => context.go('/'),
            child: Row(
              children: [
                const _BrandLogo(),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: () => context.go('/notifications'),
            icon: const Icon(Icons.notifications_none),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          if (showAvatar)
            PressableScale(
              onTap: () => context.go('/profile'),
              child: BlocBuilder<ProfileCubit, ProfileState>(
                builder: (context, state) {
                  return UserAvatar(
                    name: state.profile.name,
                    imageUrl: state.profile.avatarUrl,
                    radius: 18,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class NutriBottomNav extends StatelessWidget {
  const NutriBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 96,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavButton(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Trang chủ',
                        color: AppTheme.primary,
                        active: _indexFromPath(path) == 0,
                        onTap: () => context.go('/'),
                      ),
                      _NavButton(
                        icon: Icons.menu_book_outlined,
                        activeIcon: Icons.menu_book_rounded,
                        label: 'Nhật ký',
                        color: AppTheme.secondary,
                        active: _indexFromPath(path) == 1,
                        onTap: () => context.go('/diary'),
                      ),
                      const SizedBox(width: 74),
                      _NavButton(
                        icon: Icons.search,
                        activeIcon: Icons.search_rounded,
                        label: 'Tìm kiếm',
                        color: AppTheme.carb,
                        active: _indexFromPath(path) == 3,
                        onTap: () => context.go('/search'),
                      ),
                      _NavButton(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person_rounded,
                        label: 'Hồ sơ',
                        color: AppTheme.protein,
                        active: _indexFromPath(path) == 4,
                        onTap: () => context.go('/profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.42),
                          blurRadius: 22,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: () => context.go('/scan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: const Color(0xFF2B1B00),
                        shape: const CircleBorder(),
                        minimumSize: const Size(66, 66),
                        side: const BorderSide(color: Colors.white, width: 5),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.center_focus_strong, size: 31),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Quét AI',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _indexFromPath(String path) {
    if (path.startsWith('/diary')) return 1;
    if (path.startsWith('/scan')) return 2;
    if (path.startsWith('/search')) return 3;
    if (path.startsWith('/profile')) return 4;
    return 0;
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = active ? color : AppTheme.outline;
    return PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(active ? activeIcon : icon, color: tint, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tint,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return const BrandMark(size: 30, borderRadius: 9);
  }
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.showTopBar = true,
    this.showBottomNav = true,
  });

  final Widget child;
  final bool showTopBar;
  final bool showBottomNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: showBottomNav ? const NutriBottomNav() : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                if (showTopBar) const NutriTopBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
