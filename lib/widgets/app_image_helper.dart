import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Reusable helper to display images supporting both Firebase Storage HTTP URLs
/// and Base64 Data URIs (used when Cloud Storage is on the free Spark plan without Blaze).
class AppImageHelper {
  /// Returns a Widget to render the image regardless of source (URL or Base64 Data URI).
  static Widget buildImage({
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl.startsWith('data:image') || imageUrl.contains(';base64,')) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        final base64Data = commaIdx != -1 ? imageUrl.substring(commaIdx + 1) : imageUrl;
        final Uint8List bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (ctx, err, stack) =>
              errorWidget ??
              Container(
                color: Colors.grey[100],
                child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
              ),
        );
      } catch (e) {
        return errorWidget ??
            Container(
              color: Colors.grey[100],
              child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
            );
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder != null ? (ctx, url) => placeholder : null,
      errorWidget: (ctx, url, err) =>
          errorWidget ??
          Container(
            color: Colors.grey[100],
            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
    );
  }

  /// Returns an [ImageProvider] for use in [CircleAvatar] or [DecorationImage].
  static ImageProvider getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image') || imageUrl.contains(';base64,')) {
      final commaIdx = imageUrl.indexOf(',');
      final base64Data = commaIdx != -1 ? imageUrl.substring(commaIdx + 1) : imageUrl;
      return MemoryImage(base64Decode(base64Data));
    }
    return CachedNetworkImageProvider(imageUrl);
  }
}
