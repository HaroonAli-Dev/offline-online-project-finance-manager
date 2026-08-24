import 'dart:typed_data';

import 'attachment_file_helper_stub.dart'
    if (dart.library.io) 'attachment_file_helper_io.dart'
    as impl;

/// Helper for reading local attachment file bytes across platforms safely.
class AttachmentFileHelper {
  /// Reads bytes of a local file path (native) or returns null (web / non-existent).
  static Future<Uint8List?> readFileBytes(String? filePath) =>
      impl.readFileBytes(filePath);

  /// Checks if a local file exists at the given path.
  static Future<bool> fileExists(String? filePath) =>
      impl.fileExists(filePath);
}
