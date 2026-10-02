import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

void main() {
  group('Canvas geometry', () {
    test('starts blank and renders one line per row', () {
      final c = Canvas(4, 3);
      expect(c.renderLines(), ['', '', '']);
    });

    test('renders the glyphs written into it', () {
      final c = Canvas(5, 2)
        ..drawText(0, 0, 'ab')
        ..set(4, 1, 'Z');
      expect(c.renderLines(), ['ab', '    Z']);
    });

    test('clips writes outside the grid instead of throwing', () {
      // Deliberate: a chart computing a position from data cannot always prove the
      // result is in range, and throwing on real data is worse than dropping a
      // cell. Exact-dimension tests are what catch a position that is actually
      // wrong.
      final c = Canvas(3, 2);
      expect(
        () => c
          ..set(-1, 0, 'x')
          ..set(99, 0, 'x')
          ..set(0, -5, 'x')
          ..set(0, 99, 'x')
          ..drawText(-10, 0, 'hello')
          ..hLine(-5, 0, 100, '#')
          ..vLine(0, -5, 100, '#'),
        returnsNormally,
      );
      expect(c.renderLines().length, 2);
      for (final line in c.renderLines()) {
        expect(measureWidth(line), lessThanOrEqualTo(3));
      }
    });

    test('a zero or negative size yields an empty canvas, not an error', () {
      expect(Canvas(0, 5).renderLines(), hasLength(5));
      expect(Canvas(5, 0).renderLines(), isEmpty);
      expect(Canvas(-3, -3).renderLines(), isEmpty);
    });

    test('untrimmed rows are all exactly the canvas width', () {
      // The invariant every composed layout depends on.
      final c = Canvas(7, 3)..drawText(0, 1, 'hi');
      for (final line in c.renderLines(trimRight: false)) {
        expect(measureWidth(line), 7);
      }
    });

    test(
      'trimming removes trailing blanks so goldens have no invisible tail',
      () {
        final c = Canvas(10, 1)..drawText(0, 0, 'ab');
        expect(c.renderLines(), ['ab']);
        expect(c.renderLines(trimRight: false), ['ab        ']);
      },
    );
  });

  group('Canvas text advance', () {
    test('advances by display width so following text stays aligned', () {
      // A CJK character occupies two columns. Advancing by one would overlap it.
      final c = Canvas(8, 1)..drawText(0, 0, '日本x');
      final line = c.renderLines().single;
      expect(line, '日本x');
      expect(measureWidth(line), 5);
    });

    test('advances past a zero-width mark without consuming a column', () {
      final c = Canvas(6, 1)..drawText(0, 0, 'éf');
      expect(c.renderLines().single, 'éf');
    });
  });

  group('Canvas blit', () {
    test('copies a child canvas at an offset', () {
      final child = Canvas(2, 2)
        ..drawText(0, 0, 'ab')
        ..drawText(0, 1, 'cd');
      final parent = Canvas(6, 4)..blit(child, 2, 1);
      expect(parent.renderLines(), ['', '  ab', '  cd', '']);
    });

    test('clips a child that overhangs', () {
      final child = Canvas(4, 1)..drawText(0, 0, 'abcd');
      final parent = Canvas(3, 1)..blit(child, 1, 0);
      expect(parent.renderLines().single, ' ab');
    });
  });

  group('Canvas drawBox', () {
    test('frames the canvas', () {
      final c = Canvas(5, 3)..drawBox(CharSets.unicode);
      expect(c.renderLines(), ['┌───┐', '│   │', '└───┘']);
    });

    test('inlays a title into the top edge', () {
      final c = Canvas(14, 3)..drawBox(CharSets.unicode, title: 'Train');
      expect(c.renderLines().first, '┌─ Train ────┐');
      expect(measureWidth(c.renderLines().first), 14);
    });

    test('truncates a title rather than widening the frame', () {
      // A frame that grew to fit its title would break every enclosing layout.
      final c = Canvas(12, 3)
        ..drawBox(CharSets.unicode, title: 'a very long title indeed');
      final top = c.renderLines().first;
      expect(measureWidth(top), 12);
      expect(top, startsWith('┌─ '));
      expect(top, endsWith('┐'));
      expect(top, contains('…'));
    });

    test('draws nothing when there is no room for a frame', () {
      expect(() => Canvas(1, 1).drawBox(CharSets.unicode), returnsNormally);
      expect(Canvas(1, 1).renderLines().single, '');
    });

    test('uses the charset, so ASCII frames are pure ASCII', () {
      final c = Canvas(5, 3)..drawBox(CharSets.ascii);
      expect(c.renderLines(), ['+---+', '|   |', '+---+']);
      expect(c.render().codeUnits.every((u) => u < 128 || u == 10), isTrue);
    });
  });

  group('colour', () {
    test('is absent unless asked for', () {
      final c = Canvas(4, 1)
        ..drawText(0, 0, 'ab', style: const AnsiStyle.of(AnsiColor.red));
      expect(c.renderLines(), ['ab']);
      expect(c.render(), isNot(contains('\x1b')));
    });

    test('stripping a coloured render reproduces the plain one', () {
      // The single strongest colour test: it proves colour changed no geometry.
      Canvas build() => Canvas(12, 2)
        ..drawText(0, 0, 'hello', style: const AnsiStyle.of(AnsiColor.green))
        ..drawText(0, 1, 'world', style: const AnsiStyle(bold: true))
        ..set(11, 0, 'X', style: const AnsiStyle.of(AnsiColor.cyan));
      expect(
        stripAnsi(build().render(color: true)),
        build().render(color: false),
      );
    });

    test('coalesces a run into one escape pair, not one per cell', () {
      final c = Canvas(20, 1)
        ..hLine(0, 0, 20, '█', style: const AnsiStyle.of(AnsiColor.blue));
      final out = c.render(color: true);
      // One opening sequence and one reset for twenty cells.
      expect(RegExp(r'\x1b\[').allMatches(out).length, 2);
    });

    test('resets at the end of a styled row so nothing leaks', () {
      final c = Canvas(3, 1)
        ..hLine(0, 0, 3, '#', style: const AnsiStyle.of(AnsiColor.red));
      expect(c.render(color: true), endsWith(reset));
    });

    test('emits a new escape only when the style changes', () {
      final c = Canvas(4, 1)
        ..set(0, 0, 'a', style: const AnsiStyle.of(AnsiColor.red))
        ..set(1, 0, 'b', style: const AnsiStyle.of(AnsiColor.red))
        ..set(2, 0, 'c', style: const AnsiStyle.of(AnsiColor.blue))
        ..set(3, 0, 'd', style: const AnsiStyle.of(AnsiColor.blue));
      // red open, blue open, final reset — plus the reset before switching.
      final out = c.render(color: true);
      expect(RegExp(r'\x1b\[').allMatches(out).length, 4);
    });

    test('an empty style costs nothing', () {
      final c = Canvas(3, 1)..drawText(0, 0, 'abc', style: AnsiStyle.none);
      expect(c.hasStyles, isFalse);
      expect(c.render(color: true), 'abc');
    });
  });

  group('stripAnsi', () {
    test('removes SGR sequences', () {
      expect(stripAnsi('\x1b[31mred\x1b[0m'), 'red');
    });

    test('leaves plain text untouched', () {
      expect(stripAnsi('plain'), 'plain');
      expect(stripAnsi(''), '');
    });

    test('removes sequences this library would never emit', () {
      expect(stripAnsi('\x1b[2Jclear\x1b[1;1H'), 'clear');
    });
  });

  group('glyph ramps', () {
    test('an empty bar tip draws nothing', () {
      // partialGlyph vs levelGlyph: a tip at zero must be absent, or every bar
      // reads one cell too long.
      expect(partialGlyph(CharSets.unicode.horizontalRamp, 0), isNull);
      expect(partialGlyph(CharSets.unicode.horizontalRamp, -1), isNull);
      expect(partialGlyph(CharSets.unicode.horizontalRamp, double.nan), isNull);
    });

    test('a full bar tip is the full block', () {
      expect(partialGlyph(CharSets.unicode.horizontalRamp, 1), '█');
      expect(partialGlyph(CharSets.unicode.horizontalRamp, 1.5), '█');
    });

    test('a partial tip picks a proportional glyph', () {
      expect(partialGlyph(CharSets.unicode.horizontalRamp, 0.5), '▌');
      expect(partialGlyph(CharSets.unicode.horizontalRamp, 0.01), '▏');
    });

    test('the lowest level still draws, unlike an empty tip', () {
      expect(levelGlyph(CharSets.unicode.verticalRamp, 0), '▁');
      expect(levelGlyph(CharSets.unicode.verticalRamp, 1), '█');
      expect(levelGlyph(CharSets.unicode.verticalRamp, double.nan), '▁');
    });

    test('levels are clamped, not wrapped', () {
      expect(levelGlyph(CharSets.unicode.shades, -5), '░');
      expect(levelGlyph(CharSets.unicode.shades, 5), '█');
    });

    test('every built-in set has non-empty ramps', () {
      for (final set in CharSets.all) {
        expect(set.verticalRamp, isNotEmpty, reason: set.name);
        expect(set.horizontalRamp, isNotEmpty, reason: set.name);
        expect(set.shades, isNotEmpty, reason: set.name);
      }
    });

    test('the ascii set is entirely ascii', () {
      // The killer one-liner for the fallback's whole purpose.
      final glyphs = [
        CharSets.ascii.horizontal,
        CharSets.ascii.vertical,
        CharSets.ascii.topLeft,
        CharSets.ascii.cross,
        CharSets.ascii.full,
        CharSets.ascii.point,
        ...CharSets.ascii.verticalRamp,
        ...CharSets.ascii.horizontalRamp,
        ...CharSets.ascii.shades,
      ];
      for (final g in glyphs) {
        expect(g.codeUnits.every((u) => u < 128), isTrue, reason: g);
      }
    });
  });

  group('number formatting', () {
    test('never emits accumulated float noise', () {
      expect(formatAuto(0.1 + 0.2), '0.3');
      expect(formatAuto(1 / 3), isNot(contains('33333')));
    });

    test('drops the decimal point from a whole number', () {
      expect(formatAuto(5.0), '5');
      expect(formatAuto(0), '0');
      expect(formatAuto(-12.0), '-12');
    });

    test('labels non-finite values briefly', () {
      // A y-axis has no room for '-Infinity'.
      expect(formatAuto(double.nan), 'NaN');
      expect(formatAuto(double.infinity), '∞');
      expect(formatAuto(double.negativeInfinity), '-∞');
    });

    test('uses exponential only at extreme magnitudes', () {
      expect(formatAuto(12345.6), isNot(contains('e')));
      expect(formatAuto(1.2e9), contains('e'));
      expect(formatAuto(1.2e-9), contains('e'));
    });

    test('compact form keeps labels narrow', () {
      expect(formatCompact(1234), '1.2k');
      expect(formatCompact(123456), '123k');
      expect(formatCompact(1500000), '1.5M');
      expect(formatCompact(-2500), '-2.5k');
      expect(formatCompact(999), '999');
    });

    test('percent takes a fraction, which is what a gauge has', () {
      expect(formatPercent()(0.82), '82%');
      expect(formatPercent(digits: 1)(0.825), '82.5%');
    });

    test('fixed keeps trailing zeros so columns line up', () {
      expect(formatFixed(2)(1.5), '1.50');
      expect(formatFixed(0)(1.5), '2');
    });
  });
}
