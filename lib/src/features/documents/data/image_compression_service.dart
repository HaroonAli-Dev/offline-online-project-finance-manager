import 'dart:typed_data';

import 'package:image/image.dart' as image;

class ImageCompressionSettings {
  const ImageCompressionSettings({
    this.maxDimension = 1920,
    this.jpegQuality = 85,
  });

  final int maxDimension;
  final int jpegQuality;
}

class ProcessedImage {
  const ProcessedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.mimeType,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String mimeType;
}

/// Resizes construction photos before local persistence and later sync.
class ImageCompressionService {
  static ProcessedImage process(
    Uint8List input, {
    ImageCompressionSettings settings = const ImageCompressionSettings(),
  }) {
    final decoded = image.decodeImage(input);
    if (decoded == null) {
      throw ArgumentError('The selected file is not a supported image.');
    }
    final largestSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final output = largestSide > settings.maxDimension
        ? image.copyResize(
            decoded,
            width: decoded.width >= decoded.height
                ? settings.maxDimension
                : null,
            height: decoded.height > decoded.width
                ? settings.maxDimension
                : null,
          )
        : decoded;
    return ProcessedImage(
      bytes: Uint8List.fromList(
        image.encodeJpg(output, quality: settings.jpegQuality),
      ),
      width: output.width,
      height: output.height,
      mimeType: 'image/jpeg',
    );
  }
}
