import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:offline_finance_management_app/src/features/documents/data/image_compression_service.dart';

void main() {
  test('resizes large images and preserves JPEG metadata', () {
    final source = image.Image(width: 3000, height: 1500);
    final input = Uint8List.fromList(image.encodePng(source));

    final processed = ImageCompressionService.process(input);

    expect(processed.mimeType, 'image/jpeg');
    expect(processed.width, 1920);
    expect(processed.height, 960);
    expect(processed.bytes, isNotEmpty);
  });

  test('rejects invalid image bytes', () {
    expect(
      () => ImageCompressionService.process(Uint8List.fromList([1, 2, 3])),
      throwsArgumentError,
    );
  });
}
