import 'dart:async';
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

    final changeLog = await getChangeLog();

    print('Change log: ' + changeLog);

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

  Future<String> getChangeLog() async {
    final port = 4024;
    final host = 'http://localhost:$port';

    final data = getRawChangeLog(host, port);

    runBrowser(host);

    return await data;
  }

  Future<String> getRawChangeLog(String host, int port) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print('Listening on $host');

    final completer = Completer<String>();

    final changeLogTemplatePath = 'lib/assets/commands/release/change_log.html';
    final file = File(changeLogTemplatePath);
    final changeLogTemplate = await file.readAsString();

//    final uri = await Isolate.resolvePackageUri(
//        Uri(path: 'package:alex/commands/release/templates/change_log.html'));
//
//    print('cd: ' + Directory.current.toString());
//
//    print('Uri: $uri');
//    print('Uri: ${uri.toFilePath()}');

    var text = changeLogTemplate.replaceAll('%action%', host);

    await for (HttpRequest request in server) {
      try {
        final response = request.response;

        print("Request [${request.uri.toString()}]");

        var changeLog = request.uri.queryParameters['changelog'];

        if (changeLog != null && changeLog.isNotEmpty) {
          completer.complete(changeLog);
          response.writeln("Succeed");
          await response.close();
          break;
        } else {
          response.headers.contentType = ContentType.html;
          response.statusCode = HttpStatus.ok;
          response.writeln(text);
          await response.close();
        }
      } catch (e) {
        print('Handle request error: $e');
      }
    }

    return completer.future;
  }
}
