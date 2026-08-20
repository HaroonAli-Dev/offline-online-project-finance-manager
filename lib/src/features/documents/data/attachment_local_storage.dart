import 'dart:typed_data';

import 'attachment_local_storage_stub.dart'
    if (dart.library.io) 'attachment_local_storage_io.dart'
    as impl;

/// Persists user-selected bytes in app-controlled storage on native platforms.
/// Web retains the browser-managed selection and therefore has no local path.
Future<String?> saveAttachmentLocally(Uint8List bytes, String fileName) =>
    impl.saveAttachmentLocally(bytes, fileName);
