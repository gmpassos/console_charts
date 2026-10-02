import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

void main() {
  group('sparkline', () {
    test('renders one glyph per value', () {
      expect(sparkline([1, 2, 3, 4, 5, 6, 7, 8]).length, 8);
    });

    test(
      'maps the lowest value to the lightest glyph and the highest to full',
      () {
        final out = sparkline([0, 100]);
        expect(out, '▁█');
      },
    );

    test('a rising series rises monotonically through the ramp', () {
      // The generic correctness test: whatever the ramp, a climbing series must
      // never step down.
      final ramp = CharSets.unicode.verticalRamp;
      final out = sparkline(List.generate(40, (i) => i));
      var previous = -1;
      for (final glyph in out.runes.map(String.fromCharCode)) {
        final level = ramp.indexOf(glyph);
        expect(level, greaterThanOrEqualTo(previous));
        previous = level;
      }
    });

    test('a flat series is flat, not noise', () {
      final out = sparkline([5, 5, 5, 5]);
      expect(out.runes.toSet(), hasLength(1));
    });

    test('is empty for no data rather than throwing', () {
      expect(sparkline([]), '');
      expect(sparkline([], width: 10), '');
    });

    test('survives a series of only gaps', () {
      final out = sparkline([null, null, null]);
      expect(out, '   ');
    });

    test('draws a gap as a blank, never as a zero', () {
      // A null plotted at the baseline would read as a real measurement of zero,
      // which in an error count or a latency series is actively misleading.
      final out = sparkline([5, null, 5]);
      expect(out[1], ' ');
      expect(out[0], isNot(' '));
    });

    test('treats NaN and infinities as gaps', () {
      final out = sparkline([1, double.nan, double.infinity, 2]);
      expect(out[1], ' ');
      expect(out[2], ' ');
      // And a single NaN has not poisoned the scale for the real values.
      expect(out[0], isNot(' '));
      expect(out[3], isNot(' '));
    });

    test('a single value renders one glyph', () {
      expect(sparkline([7]).length, 1);
    });

    test('resamples to an explicit width', () {
      expect(sparkline(List.generate(500, (i) => i), width: 20).length, 20);
      expect(sparkline([1, 2, 3], width: 12).length, 12);
    });

    test('max mode keeps a spike that mean mode dilutes', () {
      // The reason the mode is exposed. Against a PINNED scale the difference is
      // plain: averaging ten samples of which one is 100 gives 10.9, near the
      // bottom of a 0..100 ramp, where the spike itself is at the top.
      //
      // Against an automatic scale both modes show a full block, because the
      // diluted spike is still the largest of the resampled values and the ramp
      // stretches to it. Worth stating: resampling mode and scaling interact, and
      // a test that ignored the scale would be testing nothing.
      final data = List<num>.filled(50, 1)..[25] = 100;
      final averaged = sparkline(
        data,
        width: 5,
        min: 0,
        max: 100,
        mode: ResampleMode.mean,
      );
      final peaked = sparkline(
        data,
        width: 5,
        min: 0,
        max: 100,
        mode: ResampleMode.max,
      );
      expect(peaked, contains('█'));
      expect(averaged, isNot(contains('█')));
    });

    test('extremes mode keeps a spike in either direction', () {
      final up = List<num>.filled(30, 10)..[15] = 99;
      final down = List<num>.filled(30, 10)..[15] = 1;
      expect(
        sparkline(up, width: 3, min: 0, max: 100, mode: ResampleMode.extremes),
        contains('█'),
      );
      // The dip is the furthest-from-mean sample, so it is what gets drawn.
      final dipped = sparkline(
        down,
        width: 3,
        min: 0,
        max: 100,
        mode: ResampleMode.extremes,
      );
      final flat = sparkline(
        down,
        width: 3,
        min: 0,
        max: 100,
        mode: ResampleMode.max,
      );
      expect(dipped, isNot(flat));
    });

    test('shared bounds make two sparklines comparable', () {
      // Without pinned bounds each series fills the ramp and a small one looks
      // identical to a large one.
      final small = sparkline([0, 1, 2], min: 0, max: 100);
      final large = sparkline([0, 50, 100], min: 0, max: 100);
      expect(small, isNot(large));
      expect(sparkline([0, 1, 2]), sparkline([0, 50, 100]));
    });

    test('uses the charset, so ascii stays ascii', () {
      final out = sparkline([1, 2, 3, 4], theme: ChartTheme.ascii);
      expect(out.codeUnits.every((u) => u < 128), isTrue);
      expect(out.length, 4);
    });

    test('is plain text unless the theme enables colour', () {
      expect(sparkline([1, 2, 3]), isNot(contains('\x1b')));
      final coloured = sparkline(
        [1, 2, 3],
        theme: ChartTheme.colorful,
        style: const AnsiStyle.of(AnsiColor.red),
      );
      expect(coloured, contains('\x1b'));
      expect(stripAnsi(coloured), sparkline([1, 2, 3]));
    });
  });

  group('SparklineGroup', () {
    const series = [
      Series([1, 2, 3, 4, 5], label: 'loss'),
      Series([5, 4, 3, 2, 1], label: 'acc'),
    ];

    test('renders one line per series', () {
      expect(
        const SparklineGroup(series, width: 30).renderLines(),
        hasLength(2),
      );
    });

    test('aligns the sparklines into a column', () {
      // Labels of different lengths must not shift the charts relative to one
      // another, or the rows cannot be read against each other.
      final lines = const SparklineGroup([
        Series([1, 2, 3], label: 'a'),
        Series([1, 2, 3], label: 'longer'),
      ], width: 30).renderLines();
      final firstSpark = lines[0].indexOf('▁');
      final secondSpark = lines[1].indexOf('▁');
      expect(firstSpark, secondSpark);
    });

    test('never exceeds the requested width', () {
      for (final width in [12, 20, 40, 80]) {
        for (final line in SparklineGroup(series, width: width).renderLines()) {
          expect(
            measureWidth(line),
            lessThanOrEqualTo(width),
            reason: '$width',
          );
        }
      }
    });

    test('is empty for no series', () {
      expect(const SparklineGroup([]).renderLines(), isEmpty);
    });

    test('degrades to labels and values when too narrow for a chart', () {
      // Better than returning nothing: the numbers still arrive.
      final lines = const SparklineGroup(series, width: 6).renderLines();
      expect(lines, hasLength(2));
      expect(lines.first, contains('loss'));
    });

    test('prints the latest plottable value, skipping trailing gaps', () {
      final lines = const SparklineGroup([
        Series([1, 2, 42, null], label: 'x'),
      ], width: 30).renderLines();
      expect(lines.single, contains('42'));
    });

    test('shared scale makes rows comparable', () {
      const rows = [
        Series([0, 1, 2], label: 'a'),
        Series([0, 50, 100], label: 'b'),
      ];
      // Values off, so the comparison is of the charts alone — the trailing
      // numbers differ by construction and would mask the point.
      final independent = const SparklineGroup(
        rows,
        width: 24,
        showValues: false,
      ).renderLines();
      final shared = const SparklineGroup(
        rows,
        width: 24,
        showValues: false,
        sharedScale: true,
      ).renderLines();

      String chartOnly(String line) => line.substring(2);

      // Independently scaled, a 0..2 series and a 0..100 series draw the *same*
      // shape — which is exactly why sharedScale exists.
      expect(chartOnly(independent[0]), chartOnly(independent[1]));
      expect(chartOnly(shared[0]), isNot(chartOnly(shared[1])));
    });

    test('stripping colour reproduces the plain render', () {
      const plain = SparklineGroup(series, width: 30);
      const colourful = SparklineGroup(
        series,
        width: 30,
        theme: ChartTheme.colorful,
      );
      expect(stripAnsi(colourful.render()), plain.render());
    });

    test('no line ends in trailing whitespace', () {
      for (final line in const SparklineGroup(
        series,
        width: 40,
      ).renderLines()) {
        expect(line, line.trimRight());
      }
    });
  });
}
