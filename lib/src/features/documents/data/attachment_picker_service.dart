import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Result of a file-pick operation, platform-agnostic.
class PickedFile {
  const PickedFile({
    required this.fileName,
    required this.mimeType,
    this.filePath,
  });

  /// Original filename including extension.
  final String fileName;

  /// Detected MIME type (best-effort).
  final String? mimeType;

  /// Absolute local path — null on Web (bytes are in memory only).
  final String? filePath;
}

/// Wraps [FilePicker] to provide a single cross-platform pick method.
class AttachmentPickerService {
  /// Pick any file (image, PDF, etc.).
  /// Returns null if the user cancels.
  static Future<PickedFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: kIsWeb, // load bytes on Web; use path on native
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final name = file.name;
    final path = kIsWeb ? null : file.path;
    final mime = _mimeFromExtension(name);

    return PickedFile(fileName: name, mimeType: mime, filePath: path);
  }

  /// Pick image files only.
  static Future<PickedFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final name = file.name;
    final path = kIsWeb ? null : file.path;

    return PickedFile(
      fileName: name,
      mimeType: _mimeFromExtension(name),
      filePath: path,
    );
  }

  static String? _mimeFromExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt' => 'text/plain',
      _ => null,
    };
  }
}
