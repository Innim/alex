import 'package:alex/src/fs/path_utils.dart';
import 'package:hive/hive.dart';

class LocalStore {
  static Future<LocalStore>? _instance;

  static Future<LocalStore> get i => _instance ??= _init();

  static Future<Box<String>> get settingsBox async =>
      (await i).openBox('alex_settings');

  static Future<Box<String>> get localDataBox async =>
      (await i).openBox('alex_local_data');

  static Future<LocalStore> _init() async {
    final path = await PathUtils.getAppDataPath('hive');
    return LocalStore._(path);
  }

  final String path;

  LocalStore._(this.path) {
    Hive.init(path);
  }

  Future<Box<E>> openBox<E>(String name) => Hive.openBox(name);
}
