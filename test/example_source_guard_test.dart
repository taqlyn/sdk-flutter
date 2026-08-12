import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-guard: example Dart must not mention OS referrer / pasteboard kits.
void main() {
  test('example/lib does not contain installreferrer / UIPasteboard strings', () {
    final exampleLib = Directory('example/lib');
    expect(exampleLib.existsSync(), isTrue, reason: 'example/lib missing');

    final banned = [
      'installreferrer',
      'InstallReferrer',
      'com.android.installreferrer',
      'UIPasteboard',
      'UIKit.UIPasteboard',
    ];

    final hits = <String>[];
    for (final entity in exampleLib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final needle in banned) {
        if (text.contains(needle)) {
          hits.add('${entity.path}: $needle');
        }
      }
    }

    expect(hits, isEmpty, reason: 'Banned vendor strings in example:\n${hits.join('\n')}');
  });
}
