@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Mechanical proof of the package's central constraint.
///
/// `console_charts` must not import `dart:io`, because it has to run on the web and
/// inside isolates with no terminal. That is easy to state and easy to break — one
/// convenience import of `stdout.terminalColumns` would do it, and nothing else in
/// the suite would notice until a user's build failed.
///
/// This test reads the source. It needs `dart:io` itself, which is fine: pub.dev
/// scores platform support from `lib/`, not from `test/`.
void main() {
  group('web safety', () {
    final banned = [
      'dart:io',
      'dart:ffi',
      'dart:isolate',
      'dart:mirrors',
      'dart:html',
      'dart:js',
      'dart:js_interop',
    ];

    test('no library under lib/ imports a platform-specific library', () {
      final offenders = <String>[];
      final root = Directory('lib');
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final library in banned) {
          if (RegExp("""(import|export)\\s+['"]$library""").hasMatch(source)) {
            offenders.add('${entity.path} imports $library');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These would stop the package working on the web:\n'
            '${offenders.join('\n')}',
      );
    });

    test('lib/ has no reference to stdout, stderr or Platform', () {
      // Even without the import, a reference means someone was reaching for the
      // terminal — which is the behaviour the constraint exists to prevent, not just
      // the dependency.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Prose in doc comments legitimately mentions these.
          if (line.trimLeft().startsWith('//')) continue;
          for (final symbol in [
            'stdout.',
            'stderr.',
            'Platform.',
            'terminalColumns',
          ]) {
            if (line.contains(symbol)) {
              offenders.add('${entity.path}:${i + 1} uses $symbol');
            }
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('determinism', () {
    test('no renderer reaches for the clock or a random number', () {
      // Same input, same output, forever — otherwise every golden test in this suite
      // is a time bomb. CalendarHeatmap takes its range as a parameter for exactly
      // this reason.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          for (final symbol in ['DateTime.now', 'Random(', 'Random.secure']) {
            if (line.contains(symbol)) {
              offenders.add('${entity.path}:${i + 1} uses $symbol');
            }
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
