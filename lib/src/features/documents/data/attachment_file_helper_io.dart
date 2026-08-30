import 'dart:io';

import 'package:flutter/foundation.dart';

Future<Uint8List?> readFileBytes(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return null;
  try {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (error, stackTrace) {
    debugPrint('AttachmentFileHelper: failed to read attachment bytes: $error');
    if (kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }
  return null;
}

Future<bool> fileExists(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return false;
  try {
    final file = File(filePath);
    return await file.exists();
  } catch (error, stackTrace) {
    debugPrint(
      'AttachmentFileHelper: failed to check attachment existence: $error',
    );
    if (kDebugMode) {
      debugPrint(stackTrace.toString());
    }
    return false;
  }
}
