import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Result of a file-pick operation, platform-agnostic.
class PickedFile {
  const PickedFile({
    required this.fileName,
    required this.mimeType,
    this.filePath,
    this.bytes,
  });

  /// Original filename including extension.
  final String fileName;

  /// Detected MIME type (best-effort).
  final String? mimeType;

  /// Absolute local path — null on Web (bytes are in memory only).
  final String? filePath;
  final Uint8List? bytes;

  int? get size => bytes?.length;
}

/// Wraps [FilePicker] to provide a single cross-platform pick method.
class AttachmentPickerService {
  /// Pick any file (image, PDF, etc.).
  /// Returns null if the user cancels.
  static Future<PickedFile?> pickFile() async {
    final files = await FilePicker.pickFiles(type: FileType.any);

    if (files.isEmpty) return null;

    final file = files.first;
    final name = file.name;
    final path = kIsWeb ? null : file.path;
    final mime = _mimeFromExtension(name);

    return PickedFile(
      fileName: name,
      mimeType: mime,
      filePath: path,
      bytes: await file.readAsBytes(),
    );
  }

  /// Pick image files only.
  static Future<PickedFile?> pickImage() async {
    final files = await FilePicker.pickFiles(type: FileType.image);

    if (files.isEmpty) return null;

    final file = files.first;
    final name = file.name;
    final path = kIsWeb ? null : file.path;

    return PickedFile(
      fileName: name,
      mimeType: _mimeFromExtension(name),
      filePath: path,
      bytes: await file.readAsBytes(),
    );
  }

  /// Captures a photo with the device camera when available.
  static Future<PickedFile?> takePhoto() =>
      _pickFromImageSource(ImageSource.camera);

  /// Selects a photo from the device gallery.
  static Future<PickedFile?> selectPhoto() =>
      _pickFromImageSource(ImageSource.gallery);

  static Future<PickedFile?> _pickFromImageSource(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.isEmpty ? 'photo.jpg' : file.name;
    return PickedFile(
      fileName: name,
      mimeType: _mimeFromExtension(name) ?? 'image/jpeg',
      filePath: kIsWeb ? null : file.path,
      bytes: bytes,
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
