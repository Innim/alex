import 'dart:async';
import 'dart:io';

import 'package:alex/internal/print.dart';
import 'package:alex/src/fs/path_utils.dart';
import 'package:async/async.dart';
import 'package:cancelable_retry/cancelable_retry.dart';
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

  Future<Box<E>> openBox<E>(String name) async {
    final request = CancelableRetry(
      () => _openBox<E>(name),
      retryIf: (result) {
        if (result.isValue) return false;

        final error = result.asError!.error;
        if (error is FileSystemException && error.osError?.errorCode == 35) {
          // probably a lock file issue, maybe some other process is using the box
          // need to retry
          info('Temporary error while opening box "$name": ${error.message}. '
              'Retrying after a delay...');
          return true;
        }

        return false;
      },
      maxAttempts: 5,
      maxDelay: const Duration(seconds: 10),
      delayFactor: const Duration(seconds: 5),
    );

    final res = await request.run();

    if (res.isValue) {
      return res.asValue!.value;
    } else {
      final error = res.asError!.error;
      throw error is Exception ? error : Exception(error.toString());
    }
  }

  Future<Result<Box<E>>> _openBox<E>(String name) async {
    Object? error;
    // run in zone to catch unhandled errors
    final res = await runZonedGuarded(
      () async {
        try {
          return await Hive.openBox<E>(name);
        } catch (e) {
          error = e;
        }
      },
      (e, st) {
        error = e;
      },
    );

    return res != null
        ? Result.value(res)
        : Result.error(error ?? 'Unknown error');
  }
}
