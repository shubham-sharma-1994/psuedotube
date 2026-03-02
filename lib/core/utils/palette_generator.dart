import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ColorPaletteService {
  static Future<Color> generatePalette(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) {
        return _getDefaultColor();
      }

      ImageProvider imageProvider;

      if (imageUrl.startsWith('file://') ||
          imageUrl.startsWith('/') ||
          imageUrl.contains('\\')) {
        String filePath = imageUrl;
        if (imageUrl.startsWith('file://')) {
          filePath = imageUrl.substring(7);
        }

        final file = File(filePath);
        if (await file.exists()) {
          imageProvider = FileImage(file);
        } else {
          return _getDefaultColor();
        }
      } else if (imageUrl.startsWith('http://') ||
          imageUrl.startsWith('https://')) {
        imageProvider = CachedNetworkImageProvider(imageUrl);
      } else {
        return _getDefaultColor();
      }

      final PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
            imageProvider,
            size: const Size(200, 200),
          );

      return paletteGenerator.dominantColor?.color ??
          paletteGenerator.vibrantColor?.color ??
          paletteGenerator.darkVibrantColor?.color ??
          paletteGenerator.darkMutedColor?.color ??
          _getDefaultColor();
    } catch (e) {
      debugPrint('Error generating color palette: $e');
      return _getDefaultColor();
    }
  }

  static Color _getDefaultColor() {
    return const Color(0xFF1E1E1E);
  }
}
