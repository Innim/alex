import 'dart:io';
import 'package:alex/runner/alex_command.dart';

/// Команда запуска релизной сборки.
class StartReleaseCommand extends AlexCommand {
  StartReleaseCommand() : super('start', 'Start new release');

  @override
  Future<int> run() async {
    final version = _getAppVersion();
    print('Start new release <$version>');
    print('Creating release branch...');
    await _delay();
    print('completed');

    print('Upgrading CHANGELOG.md...');
    await _delay();
    print('completed');
    print('Waiting for change log...');
    runBrowser('http://ya.ru');
    await _delay(15);
    print('completed');
    print('Finishing release branch...');
    await _delay();
    print('completed');
    print('Upgrading version...');
    await _delay();
    print('completed');

    return 0;
  }

  String _getAppVersion() {
    return '1.0.3';
  }

  Future<void> _delay([int timeout = 1]) {
    return Future<void>.delayed(Duration(seconds: timeout));
  }

  void runBrowser(String url) {
    var fail = false;
    switch (Platform.operatingSystem) {
      case 'linux':
        Process.run('x-www-browser', [url]);
        break;
      case 'macos':
        Process.run('open', [url]);
        break;
      case 'windows':
        Process.run('explorer', [url]);
        break;
      default:
        fail = true;
        break;
    }
  }
}
