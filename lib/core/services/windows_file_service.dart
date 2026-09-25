import 'dart:io';
import 'package:flutter/services.dart';

/// Windows file association / open-with channel (native runner).
class WindowsFileService {
  static const _channel = MethodChannel('com.psuedotube.app/file_open');

  static Future<List<String>> getInitialFiles() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await _channel.invokeMethod<List>('getInitialFiles');
      if (result == null) return [];
      return result.cast<String>();
    } catch (_) {
      return [];
    }
  }
}
