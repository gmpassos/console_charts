import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

void main() {
  group('measureWidth', () {
    test('counts ASCII one column each', () {
      expect(measureWidth('hello'), 5);
      expect(measureWidth(''), 0);
    });

    test('counts CJK as two columns', () {
      // The whole point: `'日本語'.length` is 3, but it occupies 6 columns, and a
      // label measured as 3 would leave a chart three columns short.
      expect('日本語'.length, 3);
      expect(measureWidth('日本語'), 6);
    });

    test('counts fullwidth forms as two columns', () {
      expect(measureWidth('ＡＢ'), 4);
    });

    test('ignores combining marks', () {
      // 'e' + U+0301 combining acute. One column on screen, two code units.
      const combining = 'é';
      expect(combining.length, 2);
      expect(measureWidth(combining), 1);
    });

    test('ignores zero-width joiners and variation selectors', () {
      expect(measureWidth('‍'), 0);
      expect(measureWidth('️'), 0);
    });

    test('counts emoji as two columns', () {
      expect(measureWidth('🙂'), 2);
    });

    test('counts control characters as zero', () {
      expect(measureWidth('\u0000\u001f'), 0);
    });

    test('over-measures a ZWJ sequence, which is the documented limitation', () {
      // A family emoji is one grapheme cluster and two columns on screen, but
      // this measures per code point and so reports more. Asserted rather than
      // ignored: if a future change makes it correct, this test should be the
      // thing that notices.
      const family = '👨‍👩‍👧';
      expect(measureWidth(family), greaterThan(2));
      // And the escape hatch genuinely escapes.
      final grapheme = DisplayWidth.custom((_) => 2);
      expect(grapheme(family), 2);
    });
  });

  group('truncateToWidth', () {
    test('leaves text that fits', () {
      expect(truncateToWidth('abc', 5), 'abc');
      expect(truncateToWidth('abc', 3), 'abc');
    });

    test('cuts text that does not fit', () {
      expect(truncateToWidth('abcdef', 3), 'abc');
    });

    test('makes room for the ellipsis rather than overflowing', () {
      // The result must still be 3 columns — an ellipsis that pushed the width to
      // 4 would break the enclosing column.
      final cut = truncateToWidth('abcdef', 3, ellipsis: '…');
      expect(measureWidth(cut), 3);
      expect(cut, 'ab…');
    });

    test('never splits a wide character in half', () {
      // Budget 3 with no ellipsis: two CJK characters are 4 columns, so only one
      // fits and the result is 2 columns, not a half-drawn glyph at 3.
      final cut = truncateToWidth('日本語', 3);
      expect(cut, '日');
      expect(measureWidth(cut), 2);
    });

    test('is empty when the ellipsis alone cannot fit', () {
      expect(truncateToWidth('abcdef', 1, ellipsis: '...'), '');
    });

    test('is empty at non-positive width', () {
      expect(truncateToWidth('abc', 0), '');
      expect(truncateToWidth('abc', -4), '');
    });
  });

  group('padToWidth', () {
    test('pads left-aligned on the right', () {
      expect(padToWidth('ab', 5), 'ab   ');
    });

    test('pads right-aligned on the left', () {
      expect(padToWidth('ab', 5, align: TextAlign.right), '   ab');
    });

    test('splits padding when centred, odd column to the right', () {
      expect(padToWidth('ab', 5, align: TextAlign.center), ' ab  ');
    });

    test('pads by display width, not code units', () {
      // 3 CJK characters are 6 columns, so a target of 8 needs 2 spaces. Padding
      // by `length` would add 5 and misalign the column.
      expect(padToWidth('日本語', 8), '日本語  ');
    });

    test('returns over-long text unchanged', () {
      expect(padToWidth('abcdef', 3), 'abcdef');
    });
  });

  group('runeWidth', () {
    test('classifies the three outcomes', () {
      expect(runeWidth(0x41), 1); // 'A'
      expect(runeWidth(0x4E00), 2); // CJK
      expect(runeWidth(0x0301), 0); // combining acute
    });

    test('treats the glyphs this package draws with as ONE column', () {
      // Load-bearing, not incidental. Box drawing, block elements, geometric
      // shapes and arrows are all East Asian Ambiguous — 1 column in a Western
      // locale, 2 under a CJK one. Every chart here is built from them, so
      // measuring any as wide would double every frame and align nothing.
      for (final glyph in [
        '─', '│', '┌', '┐', '└', '┘', '┼', '├', '┤', '┬', '┴', // box drawing
        '╭', '╮', '╰', '╯', '═', // rounded and heavy
        '█', '▓', '▒', '░', '▁', '▄', '▇', '▏', '▌', '▊', // block elements
        '•', '○', '·', '●', '▪', // points
        '…', '°', '←', '→', '↑', '↓', // ambiguous punctuation and arrows
      ]) {
        expect(
          measureWidth(glyph),
          1,
          reason: 'U+${glyph.runes.first.toRadixString(16)} must measure 1',
        );
      }
    });

    test('treats U+303F as narrow, unlike its neighbours', () {
      // The wide CJK symbols block stops one short of U+303F, which is explicitly
      // Narrow in the Unicode data. Easy to get wrong with a sloppy range.
      expect(runeWidth(0x303E), 2);
      expect(runeWidth(0x303F), 1);
    });
  });
}
