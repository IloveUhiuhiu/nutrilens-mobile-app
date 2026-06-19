import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/image_url_utils.dart';

/// Renders a remote image strictly from an absolute network URL.
class AbsoluteNetworkImage extends StatelessWidget {
  const AbsoluteNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final absoluteUrl = ImageUrlUtils.resolveAbsolute(imageUrl);
    if (absoluteUrl == null) {
      return errorWidget ?? const _AbsoluteImageFallback();
    }

    Widget image = CachedNetworkImage(
      imageUrl: absoluteUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) =>
          placeholder ?? const _AbsoluteImagePlaceholder(),
      errorWidget: (_, __, ___) =>
          errorWidget ?? const _AbsoluteImageFallback(),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

class _AbsoluteImagePlaceholder extends StatelessWidget {
  const _AbsoluteImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE2E8F0),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _AbsoluteImageFallback extends StatelessWidget {
  const _AbsoluteImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE9F5EE),
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF6B7280)),
      ),
    );
  }
}
