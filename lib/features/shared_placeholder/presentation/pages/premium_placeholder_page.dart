import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/premium_widgets.dart';

class PremiumPlaceholderPage extends StatelessWidget {
  const PremiumPlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.items,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            const SizedBox(height: 8),
            PremiumCard(
              backgroundColor: accentColor.withValues(alpha: 0.1),
              borderColor: accentColor.withValues(alpha: 0.32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: accentColor,
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PremiumCard(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: accentColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
