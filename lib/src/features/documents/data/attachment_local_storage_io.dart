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
