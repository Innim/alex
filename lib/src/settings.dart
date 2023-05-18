import 'package:alex/src/local_store/local_store.dart';
import 'package:hive/hive.dart';

class AlexSettings {
  static final _instance = AlexSettings._();

  final Future<Box<String>> _box = LocalStore.settingsBox;

  factory AlexSettings() => _instance;

  AlexSettings._();

  Future<String?> get openAIApiKey => _get(_Keys.openAIApiKey);
  Future<void> setOpenAIApiKey(String value) => _set(_Keys.openAIApiKey, value);

  Future<String?> _get(String key) async => (await _box).get(key);
  Future<void> _set(String key, String value) async =>
      (await _box).put(key, value);
}

class _Keys {
  static const openAIApiKey = 'open_ai_api_key';
}
