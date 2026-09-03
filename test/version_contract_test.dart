import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release version and native build derivation are 1.0.1+9', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('version: 1.0.1+9'),
    );
    final android = File('android/app/build.gradle').readAsStringSync();
    expect(android, contains('versionCode = flutterVersionCode.toInteger()'));
    expect(android, contains('versionName = flutterVersionName'));
    final ios = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(
      ios,
      contains('CURRENT_PROJECT_VERSION = "\$(FLUTTER_BUILD_NUMBER)"'),
    );
  });
}
