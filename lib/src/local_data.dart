import 'package:alex/src/local_store/local_store.dart';
import 'package:hive/hive.dart';

class AlexLocalData {
  static final _instance = AlexLocalData._();

  final Future<Box<String>> _box = LocalStore.localDataBox;

  factory AlexLocalData() => _instance;

  AlexLocalData._();

  Future<DateTime?> get lastUpdateCheck =>
      _getDateTime(_Keys.lastUpdateCheckKey);
  Future<void> setLastUpdateCheck(DateTime value) =>
      _setDateTime(_Keys.lastUpdateCheckKey, value);

  Future<DateTime?> get nextUpdateCheck =>
      _getDateTime(_Keys.nextUpdateCheckKey);
  Future<void> setNextUpdateCheck(DateTime value) =>
      _setDateTime(_Keys.nextUpdateCheckKey, value);

  Future<String?> _get(String key) async => (await _box).get(key);
  Future<void> _set(String key, String? value) async {
    final box = await _box;
    if (value == null) {
      await box.delete(key);
    } else {
      await box.put(key, value);
    }
  }

  Future<DateTime?> _getDateTime(String key) async {
    final strVal = await _get(key);
    return strVal == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(int.parse(strVal));
  }

  Future<void> _setDateTime(String key, DateTime? value) async {
    final strVal = value?.millisecondsSinceEpoch.toString();
    return _set(key, strVal);
  }
}

class _Keys {
  static const lastUpdateCheckKey = 'last_update_check';
  static const nextUpdateCheckKey = 'next_update_check';
}
