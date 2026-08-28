import 'dart:typed_data';

Future<String?> saveAttachmentLocally(Uint8List bytes, String fileName) async =>
    null;

Future<Uint8List?> readAttachmentLocally(String? key) async => null;

Future<void> deleteAttachmentLocally(String? key) async {}

Future<bool> attachmentExistsLocally(String? key) async => false;

Future<String?> createAttachmentObjectUrl(String? key) async => null;
