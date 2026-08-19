/// Domain model for a locally-stored file attachment.
///
/// Covers photos, documents, receipts, and any other file linked to a
/// business record (scheme, site, bill, expense, progress update, etc.).
class AttachmentModel {
  const AttachmentModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.filePath,
    required this.fileName,
    this.mimeType,
    required this.category,
    this.description,
    required this.capturedAt,
    this.latitude,
    this.longitude,
  });

  final String id;

  /// e.g. 'scheme', 'site', 'bill', 'expense', 'progress_update'
  final String entityType;
  final String entityId;

  /// Local filesystem path (Windows/Android) or null on Web.
  final String? filePath;

  /// Original filename including extension.
  final String fileName;

  /// MIME type, e.g. 'image/jpeg', 'application/pdf'.
  final String? mimeType;

  /// 'photo', 'document', 'receipt', 'other'
  final String category;

  final String? description;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;

  bool get isPhoto =>
      category == 'photo' || (mimeType?.startsWith('image/') ?? false);

  bool get hasGps => latitude != null && longitude != null;

  String get categoryDisplay => switch (category) {
    'photo' => 'Photo',
    'document' => 'Document',
    'receipt' => 'Receipt',
    _ => 'File',
  };
}

/// Valid attachment category codes in display order.
const kAttachmentCategories = [
  ('photo', 'Photo'),
  ('document', 'Document'),
  ('receipt', 'Receipt'),
  ('other', 'Other File'),
];
