@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/features/documents/data/attachment_local_storage.dart';

void main() {
  test('saves and reads identical bytes from IndexedDB', () async {
    final bytes = Uint8List.fromList([0, 1, 2, 3, 254, 255]);
    final key = await saveAttachmentLocally(bytes, 'photo.jpg');

    try {
      expect(key, startsWith('attachment_'));
      expect(await attachmentExistsLocally(key), isTrue);
      expect(await readAttachmentLocally(key), orderedEquals(bytes));
    } finally {
      await deleteAttachmentLocally(key);
    }
  });

  test('keeps multiple IndexedDB attachments independent', () async {
    final first = Uint8List.fromList([1, 2, 3]);
    final second = Uint8List.fromList([4, 5, 6, 7]);
    final firstKey = await saveAttachmentLocally(first, 'one.pdf');
    final secondKey = await saveAttachmentLocally(second, 'two.pdf');

    try {
      expect(firstKey, isNot(secondKey));
      expect(await readAttachmentLocally(firstKey), orderedEquals(first));
      expect(await readAttachmentLocally(secondKey), orderedEquals(second));
    } finally {
      await deleteAttachmentLocally(firstKey);
      await deleteAttachmentLocally(secondKey);
    }
  });

  test('deletes an IndexedDB attachment and clears exists', () async {
    final key = await saveAttachmentLocally(
      Uint8List.fromList([9, 8, 7]),
      'remove.pdf',
    );

    expect(await attachmentExistsLocally(key), isTrue);
    await deleteAttachmentLocally(key);
    expect(await attachmentExistsLocally(key), isFalse);
    expect(await readAttachmentLocally(key), isNull);
  });
}
