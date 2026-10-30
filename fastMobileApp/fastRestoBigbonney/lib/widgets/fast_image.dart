import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Image widget that accepts either an http(s) URL or a
/// `data:image/...;base64,...` data URI (restaurant-uploaded photos
/// are stored as base64 in the backend).
class FastImage extends StatelessWidget {
  const FastImage(
    this.src, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.cacheWidth,
  });

  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final int? cacheWidth;

  static bool isBase64(String s) => s.startsWith('data:image');

  Widget _fallback() => placeholder ?? const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return _fallback();
    if (isBase64(src)) {
      try {
        return Image.memory(
          base64Decode(src.split(',').last),
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } catch (_) {
        return _fallback();
      }
    }
    // Disk-cached: a flaky remote URL only has to succeed once, and
    // repeat renders don't re-hit the network on every screen open.
    return CachedNetworkImage(
      imageUrl: src,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      filterQuality: FilterQuality.low,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => placeholder ?? const SizedBox.shrink(),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }
}
