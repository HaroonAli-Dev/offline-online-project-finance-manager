import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

/// Contract for uploading, downloading, and managing binary attachment files in Supabase Storage.
abstract class AttachmentStorageClient {
  /// Uploads binary data to Supabase Storage at [storagePath] in the given [bucket].
  Future<String> uploadBytes({
    required String bucket,
    required String storagePath,
    required Uint8List bytes,
    String? mimeType,
  });

  /// Downloads binary data from Supabase Storage given [bucket] and [storagePath].
  Future<Uint8List> downloadBytes({
    required String bucket,
    required String storagePath,
  });

  /// Deletes a file from Supabase Storage.
  Future<void> deleteFile({
    required String bucket,
    required String storagePath,
  });

  /// Creates a signed download URL valid for [expiresInSeconds].
  Future<String?> createSignedUrl({
    required String bucket,
    required String storagePath,
    int expiresInSeconds = 3600,
  });
}

/// Production implementation of [AttachmentStorageClient] using `supabase_flutter`.
class SupabaseAttachmentStorageClient implements AttachmentStorageClient {
  const SupabaseAttachmentStorageClient(this._client);

  final SupabaseClient _client;

  @override
  Future<String> uploadBytes({
    required String bucket,
    required String storagePath,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final response = await _client.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
    return response;
  }

  @override
  Future<Uint8List> downloadBytes({
    required String bucket,
    required String storagePath,
  }) async {
    final bytes = await _client.storage.from(bucket).download(storagePath);
    return bytes;
  }

  @override
  Future<void> deleteFile({
    required String bucket,
    required String storagePath,
  }) async {
    await _client.storage.from(bucket).remove([storagePath]);
  }

  @override
  Future<String?> createSignedUrl({
    required String bucket,
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    try {
      final url = await _client.storage
          .from(bucket)
          .createSignedUrl(storagePath, expiresInSeconds);
      return url;
    } catch (e) {
      debugPrint('SupabaseAttachmentStorageClient: Failed to create signed URL: $e');
      return null;
    }
  }
}

/// Helper service for deterministic storage path resolution and storage operations.
class AttachmentStorageService {
  AttachmentStorageService({
    AttachmentStorageClient? storageClient,
  }) : _explicitStorageClient = storageClient;

  static const String defaultBucket = 'attachments';

  AttachmentStorageClient? _explicitStorageClient;

  AttachmentStorageClient? get storageClient {
    if (_explicitStorageClient != null) return _explicitStorageClient;
    if (SupabaseConfig.isInitialized) {
      return SupabaseAttachmentStorageClient(SupabaseConfig.client);
    }
    return null;
  }

  void setStorageClient(AttachmentStorageClient? client) {
    _explicitStorageClient = client;
  }

  /// Generates a deterministic user-scoped cloud storage path:
  /// `{userId}/{entityType}/{attachmentId}/{fileName}`
  static String buildStoragePath({
    required String userId,
    required String entityType,
    required String attachmentId,
    required String fileName,
  }) {
    final safeFileName = fileName.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final safeEntityType = entityType.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$userId/$safeEntityType/$attachmentId/$safeFileName';
  }

  /// Uploads binary data for an attachment to Supabase Storage.
  Future<String> uploadAttachment({
    required String userId,
    required String entityType,
    required String attachmentId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String bucket = defaultBucket,
  }) async {
    final client = storageClient;
    if (client == null) {
      throw StateError('Storage client is not available or offline.');
    }

    final storagePath = buildStoragePath(
      userId: userId,
      entityType: entityType,
      attachmentId: attachmentId,
      fileName: fileName,
    );

    await client.uploadBytes(
      bucket: bucket,
      storagePath: storagePath,
      bytes: bytes,
      mimeType: mimeType,
    );

    return storagePath;
  }

  /// Downloads binary data for an attachment from Supabase Storage.
  Future<Uint8List> downloadAttachment({
    required String storagePath,
    String bucket = defaultBucket,
  }) async {
    final client = storageClient;
    if (client == null) {
      throw StateError('Storage client is not available or offline.');
    }

    return client.downloadBytes(
      bucket: bucket,
      storagePath: storagePath,
    );
  }

  /// Deletes a file from Supabase Storage.
  Future<void> deleteAttachment({
    required String storagePath,
    String bucket = defaultBucket,
  }) async {
    final client = storageClient;
    if (client == null) return;

    await client.deleteFile(
      bucket: bucket,
      storagePath: storagePath,
    );
  }
}
