import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;

class PathUtils {
  static String? _packageDir;

  static Future<String> getAssetsPath(String assetPath) =>
      getPathRelativePackage('assets/$assetPath');
  static Future<String> getPathRelativePackage(String path) async {
    final packageUri = Uri.parse('package:alex/$path');
    final resolvedUri = await Isolate.resolvePackageUri(packageUri);

    String filePath;
    if (resolvedUri == null) {
      // trying to get relative path
      final packageDir = _getPackageDirPath();
      filePath = p.join(packageDir, path);
    } else {
      filePath = resolvedUri.path;
    }

    // TODO: windows fix
    if (Platform.isWindows && filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    return filePath;
  }

  static String _getPackageDirPath() {
    return _packageDir ??=
        Directory.fromUri(Platform.script).parent.parent.path;
  }

  const PathUtils._();
}
