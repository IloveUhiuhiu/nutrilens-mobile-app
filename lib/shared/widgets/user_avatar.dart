import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/image_url_utils.dart';
import 'absolute_network_image.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 20,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = _initial(name);
    final absoluteUrl = ImageUrlUtils.resolveAbsolute(imageUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryContainer,
      child: ClipOval(
        child: absoluteUrl == null
            ? _FallbackAvatar(initial: fallback, radius: radius)
            : AbsoluteNetworkImage(
                imageUrl: absoluteUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: _FallbackAvatar(
                  initial: fallback,
                  radius: radius,
                ),
                errorWidget: _FallbackAvatar(
                  initial: fallback,
                  radius: radius,
                ),
              ),
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({
    required this.initial,
    required this.radius,
  });

  final String initial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: AppTheme.primaryContainer,
      child: initial.isEmpty
          ? Icon(Icons.person, size: radius, color: Colors.white)
          : Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}
