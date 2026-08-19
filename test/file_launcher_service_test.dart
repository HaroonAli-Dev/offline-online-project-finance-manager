import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/services/file_launcher_service.dart';

void main() {
  group('FileLauncherService safety checks', () {
    test('accepts safe local paths and URLs', () {
      expect(
        FileLauncherService.isSafeReference('C:\\Users\\demo\\file.pdf'),
        isTrue,
      );
      expect(FileLauncherService.isSafeReference('D:/demo/report.csv'), isTrue);
      expect(
        FileLauncherService.isSafeReference('https://example.com/file.pdf'),
        isTrue,
      );
      expect(
        FileLauncherService.isSafeReference('blob:https://example.com/abc'),
        isTrue,
      );
    });

    test('rejects empty or unsafe references', () {
      expect(FileLauncherService.isSafeReference(''), isFalse);
      expect(FileLauncherService.isSafeReference('   '), isFalse);
      expect(FileLauncherService.isSafeReference('../outside.txt'), isFalse);
      expect(FileLauncherService.isSafeReference('..\\outside.txt'), isFalse);
      expect(
        FileLauncherService.isSafeReference('file:///etc/passwd'),
        isFalse,
      );
    });
  });
}
