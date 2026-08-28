import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> saveAttachmentLocally(Uint8List bytes, String fileName) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}attachments',
  );
  await directory.create(recursive: true);
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final target = File(
    '${directory.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$safeName',
  );
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

Future<Uint8List?> readAttachmentLocally(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return null;
  final file = File(filePath);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> deleteAttachmentLocally(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return;
  final file = File(filePath);
  if (await file.exists()) await file.delete();
}

Future<bool> attachmentExistsLocally(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return false;
  return File(filePath).exists();
}

Future<String?> createAttachmentObjectUrl(String? filePath) async {
  if (filePath == null || filePath.trim().isEmpty) return null;
  return await File(filePath).exists() ? filePath : null;
}
