import 'dart:typed_data';

import 'attachment_local_storage.dart';

Future<Uint8List?> readFileBytes(String? filePath) =>
    readAttachmentLocally(filePath);

Future<bool> fileExists(String? filePath) => attachmentExistsLocally(filePath);
