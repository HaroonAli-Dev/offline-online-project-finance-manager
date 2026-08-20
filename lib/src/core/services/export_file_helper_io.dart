import 'dart:io';

Future<bool> fileExists(String path) async {
  return await File(path).exists();
}

Future<void> writeStringToFile(String path, String content) async {
  await File(path).writeAsString(content);
}

Future<List<int>> readFileAsBytes(String path) => File(path).readAsBytes();

Future<void> copyFileTo(String sourcePath, String targetPath) async {
  await File(sourcePath).copy(targetPath);
}
