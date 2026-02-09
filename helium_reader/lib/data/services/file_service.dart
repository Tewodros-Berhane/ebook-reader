import "dart:io";

import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

class FileService {
  const FileService();

  Future<Directory> libraryDirectory() async {
    late Directory baseDirectory;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      baseDirectory = await getApplicationSupportDirectory();
    } else {
      baseDirectory = await getApplicationDocumentsDirectory();
      final Directory? external = await getExternalStorageDirectory();
      if (external != null) {
        baseDirectory = external;
      }
    }

    final Directory dir = Directory(p.join(baseDirectory.path, "library"));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<String> bookPath(String fileId) async {
    final Directory dir = await libraryDirectory();
    return p.join(dir.path, "$fileId.epub");
  }
}
