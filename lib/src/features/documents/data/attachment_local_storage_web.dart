// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

const _databaseName = 'offline_finance_attachments';
const _storeName = 'attachments';
const _databaseVersion = 1;

Future<dynamic> _openDatabase() {
  final indexedDb = html.window.indexedDB;
  if (indexedDb == null) {
    return Future.error(
      StateError('IndexedDB is unavailable in this browser.'),
    );
  }

  return indexedDb.open(
    _databaseName,
    version: _databaseVersion,
    onUpgradeNeeded: (dynamic event) {
      final database = event.target.result;
      if (!database.objectStoreNames!.contains(_storeName)) {
        database.createObjectStore(_storeName);
      }
    },
  );
}

Future<String> saveAttachmentLocally(Uint8List bytes, String fileName) async {
  final database = await _openDatabase();
  final key = 'attachment_${const Uuid().v4()}';
  final transaction = database.transaction(_storeName, 'readwrite');
  await transaction.objectStore(_storeName).put(html.Blob([bytes]), key);
  await transaction.completed;
  database.close();
  return key;
}

Future<Uint8List?> readAttachmentLocally(String? key) async {
  if (key == null || key.trim().isEmpty) return null;
  final database = await _openDatabase();
  final transaction = database.transaction(_storeName, 'readonly');
  final value = await transaction.objectStore(_storeName).getObject(key);
  await transaction.completed;
  database.close();
  if (value is! html.Blob) return null;

  final reader = html.FileReader();
  reader.readAsArrayBuffer(value);
  await reader.onLoad.first;
  final result = reader.result;
  if (result is ByteBuffer) return Uint8List.view(result);
  return null;
}

Future<void> deleteAttachmentLocally(String? key) async {
  if (key == null || key.trim().isEmpty) return;
  final database = await _openDatabase();
  final transaction = database.transaction(_storeName, 'readwrite');
  await transaction.objectStore(_storeName).delete(key);
  await transaction.completed;
  database.close();
}

Future<bool> attachmentExistsLocally(String? key) async {
  if (key == null || key.trim().isEmpty) return false;
  final database = await _openDatabase();
  final transaction = database.transaction(_storeName, 'readonly');
  final value = await transaction.objectStore(_storeName).getObject(key);
  await transaction.completed;
  database.close();
  return value != null;
}

Future<String?> createAttachmentObjectUrl(String? key) async {
  final bytes = await readAttachmentLocally(key);
  if (bytes == null) return null;
  return html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
}
