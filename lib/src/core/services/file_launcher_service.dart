import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class FileLauncherService {
  /// Validates that the reference is a safe URL or local file path.
  /// This blocks traversal attempts like ../ and raw file:// URIs.
  static bool isSafeReference(String filePathOrUrl) {
    final trimmed = filePathOrUrl.trim();
    if (trimmed.isEmpty || trimmed.contains('\x00')) {
      return false;
    }

    final normalized = trimmed.replaceAll('\\', '/');
    if (normalized.startsWith('file:///')) {
      return false;
    }

    if (normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('blob:')) {
      try {
        final uri = Uri.parse(trimmed);
        return uri.isAbsolute;
      } on FormatException {
        return false;
      }
    }

    if (normalized.startsWith('//') ||
        normalized.contains('\n') ||
        normalized.contains('\r')) {
      return false;
    }

    final parts = normalized.split('/');
    if (parts.any((part) => part == '..' || part == '.')) {
      return false;
    }

    return true;
  }

  /// Opens a local file path or web URL safely across Windows, Android, and Web.
  static Future<bool> openFile(String filePathOrUrl) async {
    final safeReference = filePathOrUrl.trim();
    if (!isSafeReference(safeReference)) {
      return false;
    }

    try {
      final Uri uri;
      if (safeReference.startsWith('http://') ||
          safeReference.startsWith('https://') ||
          safeReference.startsWith('blob:')) {
        uri = Uri.parse(safeReference);
      } else if (kIsWeb) {
        uri = Uri.parse(safeReference);
      } else {
        uri = Uri.file(safeReference);
      }

      final launched = await canLaunchUrl(uri)
          ? await launchUrl(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
      return launched;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'FileLauncherService',
          context: ErrorSummary('Failed to open a file reference.'),
        ),
      );
      return false;
    }
  }
}
