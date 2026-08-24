import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readFileBytes(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return null;
  try {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {}
  return null;
}

Future<bool> fileExists(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return false;
  try {
    final file = File(filePath);
    return await file.exists();
  } catch (_) {}
  return false;
}
