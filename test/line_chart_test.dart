import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

String block(String s) => s
    .split('\n')
    .where((l) => l.trimLeft().startsWith('|'))
    .map((l) => l.substring(l.indexOf('|') + 1))
    .join('\n');

void main() {
  group('lineGlyphs', () {
    const chars = CharSets.unicode;

    test('a flat step is a single horizontal run', () {
      expect(lineGlyphs(2, 2, chars), [(2, '─')]);
    });

    test('a rise turns up at the start and hands off at the top', () {
      // `╯` joins up and left, so it receives the stroke arriving from the previous
      // column and turns it upward; `╭` joins down and right, so it ends the
      // vertical run and hands the stroke to the next column. Every stroke end has
      // a partner, which is what makes the line look continuous.
      expect(lineGlyphs(3, 5, chars), [(3, '╯'), (5, '╭'), (4, '│')]);
    });

    test('a fall is the mirror', () {
      expect(lineGlyphs(5, 3, chars), [(5, '╮'), (3, '╰'), (4, '│')]);
    });

    test('an adjacent step needs no vertical run', () {
      expect(lineGlyphs(0, 1, chars), [(0, '╯'), (1, '╭')]);
      expect(lineGlyphs(1, 0, chars), [(1, '╮'), (0, '╰')]);
    });

    test('a gap on either side yields nothing', () {
      expect(lineGlyphs(-1, 3, chars), isEmpty);
      expect(lineGlyphs(3, -1, chars), isEmpty);
    });

    test('an override replaces every glyph', () {
      expect(lineGlyphs(1, 3, chars, override: '*'), [
        (1, '*'),
        (2, '*'),
        (3, '*'),
      ]);
    });
  });

  group('LineChart shape', () {
    test('a rising series never uses a falling glyph', () {
      // The single best generic test for a line chart: it catches a swapped corner
      // pair and a sign-flipped row conversion at once, without pinning an exact
      // picture.
      final out = LineChart.of(
        List<num>.generate(30, (i) => i * i),
        width: 40,
        height: 12,
      ).render();
      expect(out, contains('╭'));
      expect(out, contains('╯'));
      expect(out, isNot(contains('╮')));
      expect(out, isNot(contains('╰')));
    });

    test('a falling series never uses a rising glyph', () {
      final out = LineChart.of(
        List<num>.generate(30, (i) => 900 - i * i),
        width: 40,
        height: 12,
      ).render();
      expect(out, contains('╮'));
      expect(out, contains('╰'));
      expect(out, isNot(contains('╭')));
    });

    test('a flat series draws one horizontal run and no turns', () {
      final out = LineChart.of(
        List<num>.filled(20, 5),
        width: 30,
        height: 7,
        axes: Axes.none,
      ).render();
      final inked = out.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(inked, hasLength(1));
      expect(inked.single.trim().split('').toSet(), {'─'});
    });

    test('reaches the last column instead of stopping one short', () {
      // asciichart leaves the final column blank, which shows as a notch of dead
      // space on the right of every chart.
      final out = LineChart.of(
        [1, 2, 3, 4, 5],
        width: 20,
        height: 6,
        axes: Axes.none,
      ).renderLines();
      final widest = out.fold<int>(
        0,
        (m, l) => measureWidth(l) > m ? measureWidth(l) : m,
      );
      expect(widest, 20);
    });

    test('a gap breaks the line rather than bridging it', () {
      final out = LineChart.of(
        [10, 20, 30, null, null, 30, 20, 10],
        width: 30,
        height: 8,
        axes: Axes.none,
      ).render();
      // Something must be missing in the middle: the inked cells per row are fewer
      // than a continuous line would give.
      expect(out, contains('─'));
      final rows = out.split('\n');
      final anyRowHasGapInside = rows.any((r) {
        final t = r.trimRight();
        final first = t.indexOf(RegExp(r'[^\s]'));
        return first >= 0 && t.substring(first).contains('  ');
      });
      expect(anyRowHasGapInside, isTrue);
    });
  });

  group('LineChart dimensions', () {
    test('output is exactly the requested height', () {
      for (final height in [3, 5, 8, 12, 20]) {
        for (final labels in [
          null,
          const ['a', 'b', 'c'],
        ]) {
          final lines = LineChart.of(
            [1, 5, 3, 9, 2],
            width: 40,
            height: height,
            xLabels: labels,
          ).renderLines();
          expect(lines, hasLength(height), reason: 'h=$height labels=$labels');
        }
      }
    });

    test('output never exceeds the requested width', () {
      for (final width in [8, 14, 30, 60, 120]) {
        final lines = LineChart.of(
          [1, 500, 3, 9999, 2],
          width: width,
          height: 8,
          title: 'a fairly long title that will not fit narrow charts',
          xLabels: const ['one', 'two', 'three', 'four', 'five'],
        ).renderLines();
        for (final line in lines) {
          expect(
            measureWidth(line),
            lessThanOrEqualTo(width),
            reason: '$width',
          );
        }
      }
    });

    test('x labels never overlap', () {
      final lines = LineChart.of(
        List<num>.generate(12, (i) => i),
        width: 36,
        height: 8,
        xLabels: const [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ],
      ).renderLines();
      final labelRow = lines.last;
      // Thinned, not crammed: some labels are dropped so none collides.
      expect(labelRow, contains('January'));
      expect(measureWidth(labelRow), lessThanOrEqualTo(36));
    });
  });

  group('LineChart axes', () {
    test('labels the axis with round numbers', () {
      final out = LineChart.of(
        [3.7, 41.2, 68.9, 91.4],
        width: 30,
        height: 8,
      ).render();
      // Nice bounds mean a 0..100 domain, so the labels are round.
      expect(out, contains('100'));
      expect(out, contains('0'));
      expect(out, isNot(contains('3.7')));
    });

    test('never emits accumulated float noise in a label', () {
      for (final data in [
        [0.1, 0.2, 0.30000000000000004],
        [0.001, 0.002, 0.003],
        [1 / 3, 2 / 3, 1.0],
      ]) {
        final out = LineChart.of(data, width: 30, height: 8).render();
        expect(out, isNot(contains('000000')), reason: '$data');
        expect(out, isNot(contains('999999')), reason: '$data');
      }
    });

    test('does not label a tick as negative zero', () {
      final out = LineChart.of([-5, 0, 5], width: 30, height: 9).render();
      expect(
        out.split('\n').any((l) => l.trimLeft().startsWith('-0 ')),
        isFalse,
      );
    });

    test('marks the zero row when the domain spans it', () {
      final out = LineChart.of([-50, 0, 50], width: 30, height: 9).render();
      expect(out, contains('┼'));
    });

    test('Axes.none draws a bare plot area', () {
      final out = LineChart.of(
        [1, 2, 3],
        width: 10,
        height: 4,
        axes: Axes.none,
      ).renderLines();
      expect(out, hasLength(4));
      expect(out.join(), isNot(contains('┤')));
      expect(out.join(), isNot(contains('┼')));
    });
  });

  group('LineChart degenerate input', () {
    const sizes = [(1, 1), (3, 2), (5, 3), (12, 6), (80, 24)];
    final inputs = <String, List<num?>>{
      'empty': [],
      'single': [42],
      'all equal': [7, 7, 7, 7],
      'all zero': [0, 0, 0],
      'with nulls': [1, null, 3, null, 5],
      'all null': [null, null],
      'with NaN': [1, double.nan, 3],
      'with infinity': [1, double.infinity, 3],
      'all non-finite': [double.nan, double.infinity],
      'negative': [-5, -10, -3],
      'mixed signs': [-5, 0, 5],
      'huge': [1e300, -1e300],
      'tiny': [1e-300, 2e-300],
    };

    test('never throws, and always respects its bounds', () {
      for (final entry in inputs.entries) {
        for (final (w, h) in sizes) {
          final chart = LineChart.of(entry.value, width: w, height: h);
          late List<String> lines;
          expect(
            () => lines = chart.renderLines(),
            returnsNormally,
            reason: '${entry.key} at ${w}x$h',
          );
          expect(
            lines.length,
            lessThanOrEqualTo(h),
            reason: '${entry.key} at ${w}x$h',
          );
          for (final line in lines) {
            expect(
              measureWidth(line),
              lessThanOrEqualTo(w),
              reason: '${entry.key} at ${w}x$h: "$line"',
            );
          }
        }
      }
    });

    test('emits no control characters and no escapes when plain', () {
      for (final entry in inputs.entries) {
        final out = LineChart.of(entry.value, width: 30, height: 8).render();
        expect(out, isNot(contains('\x1b')), reason: entry.key);
        expect(out, isNot(contains('\t')), reason: entry.key);
        expect(out, isNot(contains('\r')), reason: entry.key);
      }
    });

    test('a single point is placed inside the plot, not on the floor', () {
      // Putting it on the bottom row would read as zero, which it is not.
      final out = LineChart.of(
        [42],
        width: 20,
        height: 7,
        axes: Axes.none,
      ).renderLines();
      final inkedRow = out.indexWhere((l) => l.trim().isNotEmpty);
      expect(inkedRow, greaterThan(0));
      expect(inkedRow, lessThan(out.length - 1));
    });
  });

  group('LineChart themes', () {
    test('ascii output is entirely ascii', () {
      final out = LineChart.of(
        [20, 40, 60, 80, 100, 95, 70],
        width: 32,
        height: 8,
        theme: ChartTheme.ascii,
        xLabels: const ['a', 'b', 'c'],
        title: 'Title',
      ).render();
      expect(out.codeUnits.every((u) => u < 128 || u == 10), isTrue);
    });

    test('ascii and unicode have identical layout and ink', () {
      // The precise meaning of "same chart, different glyphs": every cell is inked
      // in one exactly when it is inked in the other.
      List<String> render(ChartTheme theme) => LineChart.of(
        [20, 40, 60, 80, 100, 95, 70, 45],
        width: 34,
        height: 9,
        theme: theme,
      ).renderLines();
      final uni = render(ChartTheme.plain);
      final asc = render(ChartTheme.ascii);
      expect(asc, hasLength(uni.length));
      for (var i = 0; i < uni.length; i++) {
        final u = uni[i].split('');
        final a = asc[i].split('');
        expect(a, hasLength(u.length), reason: 'row $i');
        for (var c = 0; c < u.length; c++) {
          expect(
            a[c] == ' ',
            u[c] == ' ',
            reason: 'row $i col $c: "${uni[i]}" vs "${asc[i]}"',
          );
        }
      }
    });

    test('stripping colour reproduces the plain render', () {
      String build(ChartTheme theme) => LineChart(
        const [
          Series([4, 9, 13, 11, 18, 22, 19], label: 'reqs'),
          Series([2, 3, 5, 9, 8, 12, 14], label: 'errs'),
        ],
        width: 40,
        height: 10,
        theme: theme,
        title: 'Traffic',
        xLabels: const ['Mon', 'Tue', 'Wed'],
      ).render();
      expect(stripAnsi(build(ChartTheme.colorful)), build(ChartTheme.plain));
    });
  });

  group('AreaChart', () {
    test('fills beneath the line and keeps the line visible', () {
      final out = AreaChart(
        const [
          Series([20, 40, 60, 80, 100, 95, 70, 45]),
        ],
        width: 36,
        height: 9,
      ).render();
      expect(out, contains('█'));
      // The curve itself must still be drawn on top of the fill.
      expect(out, contains('╭'));
      expect(out, contains('╮'));
    });

    test('baselines at zero, because a filled area reads as a quantity', () {
      final out = AreaChart(
        const [
          Series([50, 60, 70]),
        ],
        width: 24,
        height: 8,
      ).render();
      expect(out, contains('0'));
    });

    test('survives degenerate input', () {
      for (final data in <List<num?>>[
        [],
        [5],
        [null],
        [0, 0],
      ]) {
        expect(
          () => AreaChart([Series(data)], width: 20, height: 6).render(),
          returnsNormally,
          reason: '$data',
        );
      }
    });
  });

  group('monotoneResample', () {
    test('never overshoots the input range', () {
      // The reason for Fritsch–Carlson rather than a natural spline. A natural
      // cubic overshoots near a sharp bend, so a loss curve decaying to zero gets
      // drawn dipping below zero — which looks like a rendering bug and, for a
      // quantity that cannot be negative, is one.
      final decay = List<num>.generate(
        12,
        (i) => 100 * (1 - i / 11) * (1 - i / 11),
      );
      final out = monotoneResample(decay, 120);
      for (final v in out) {
        if (v == null) continue;
        expect(v, greaterThanOrEqualTo(-1e-9));
        expect(v, lessThanOrEqualTo(100 + 1e-9));
      }
    });

    test('stays within the bracketing samples on a monotone run', () {
      final data = <num>[0, 1, 10, 11, 50, 51];
      final out = monotoneResample(data, 60);
      for (final v in out) {
        if (v == null) continue;
        expect(v, greaterThanOrEqualTo(-1e-9));
        expect(v, lessThanOrEqualTo(51 + 1e-9));
      }
    });

    test('preserves the endpoints', () {
      final out = monotoneResample([3, 7, 2, 9], 40);
      expect(out.first, closeTo(3, 1e-9));
      expect(out.last, closeTo(9, 1e-9));
    });

    test('does not bridge a gap', () {
      final out = monotoneResample([1, 2, null, null, 5, 6], 40);
      expect(out.any((v) => v == null), isTrue);
    });

    test('handles degenerate input', () {
      expect(monotoneResample([], 10), everyElement(isNull));
      expect(monotoneResample([5], 10), everyElement(closeTo(5, 1e-9)));
      expect(monotoneResample([null, null], 10), everyElement(isNull));
      expect(monotoneResample([1, 2, 3], 0), isEmpty);
    });

    test('returns exactly the requested number of columns', () {
      for (final n in [1, 2, 7, 50]) {
        expect(monotoneResample([1, 4, 2, 8], n), hasLength(n));
      }
    });
  });
}
