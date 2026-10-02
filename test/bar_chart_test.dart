import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

/// Expected output written as a leading-pipe block.
///
/// The pipe marks the left edge, so meaningful leading spaces survive and the eye
/// can check alignment down the column — which is most of what is being tested.
String block(String s) => s
    .split('\n')
    .where((l) => l.trimLeft().startsWith('|'))
    .map((l) => l.substring(l.indexOf('|') + 1))
    .join('\n');

void main() {
  group('BarChart plain', () {
    test('renders labelled bars', () {
      final chart = BarChart.of(
        [82, 64, 43, 27, 18],
        labels: const ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'],
        width: 34,
        maxValue: 100,
      );
      // Body is 23 columns (34 - 8 label - 3 value), so e.g. 82% is 150.88
      // eighths, rounded to 151: eighteen whole cells and a seven-eighths tip.
      expect(
        chart.render(),
        block(r'''
        |Alpha   ██████████████████▉     82
        |Beta    ██████████████▊         64
        |Gamma   █████████▉              43
        |Delta   ██████▎                 27
        |Epsilon ████▏                   18
      '''),
      );
    });

    test('a full-scale bar fills the body exactly', () {
      final chart = BarChart.of(
        [100],
        maxValue: 100,
        width: 10,
        showValues: false,
      );
      expect(chart.render(), '██████████');
    });

    test('a zero bar draws nothing', () {
      final chart = BarChart.of(
        [0],
        maxValue: 100,
        width: 10,
        showValues: false,
      );
      expect(chart.render().trim(), '');
    });

    test('bar lengths never decrease as values increase', () {
      final chart = BarChart.of(
        List<num>.generate(20, (i) => i),
        width: 30,
        showValues: false,
      );
      var previous = -1;
      for (final line in chart.renderLines()) {
        final length = measureWidth(line.trimRight());
        expect(length, greaterThanOrEqualTo(previous));
        previous = length;
      }
    });

    test('uses eighths, so a half value ends on a half block', () {
      final chart = BarChart.of(
        [50],
        maxValue: 100,
        width: 8,
        showValues: false,
      );
      expect(chart.render(), '████');
      final chart2 = BarChart.of(
        [56.25],
        maxValue: 100,
        width: 8,
        showValues: false,
      );
      // 4.5 cells of 8 — a whole-cell renderer would round this to 4 or 5.
      expect(chart2.render(), '████▌');
    });

    test('a track makes the full extent visible', () {
      final chart = BarChart.of(
        [25],
        maxValue: 100,
        width: 8,
        showValues: false,
        track: '░',
      );
      expect(chart.render(), '██░░░░░░');
    });

    test('negative values draw nothing rather than lying', () {
      // Every partial-block glyph is anchored to the LEFT of its cell, so a bar
      // growing leftward cannot have sub-cell precision, and one drawn rightward
      // would misrepresent its sign. Negative data belongs in a column chart.
      final chart = BarChart.of(
        [-50, 50],
        maxValue: 100,
        width: 10,
        showValues: false,
      );
      final lines = chart.renderLines();
      expect(lines[0].trim(), '');
      expect(lines[1].trim(), isNotEmpty);
    });

    test('gaps draw nothing and do not poison the scale', () {
      final chart = BarChart.of(
        [null, 50, double.nan, 100],
        width: 20,
        showValues: false,
      );
      final lines = chart.renderLines();
      expect(lines[0].trim(), '');
      expect(lines[2].trim(), '');
      expect(lines[1].trim(), isNotEmpty);
      expect(lines[3].trim(), isNotEmpty);
    });

    test('is empty for no data', () {
      expect(BarChart.of([]).renderLines(), isEmpty);
      expect(const BarChart([]).renderLines(), isEmpty);
    });

    test('never exceeds the requested width', () {
      for (final width in [4, 8, 16, 40, 100]) {
        final chart = BarChart.of(
          [1, 500, 99999],
          labels: const ['a', 'bb', 'ccc'],
          width: width,
        );
        for (final line in chart.renderLines()) {
          expect(
            measureWidth(line),
            lessThanOrEqualTo(width),
            reason: '$width',
          );
        }
      }
    });

    test('a long label is truncated rather than squeezing out the chart', () {
      final chart = BarChart.of(
        [50],
        labels: const ['an extremely long category name'],
        width: 24,
        maxValue: 100,
      );
      final line = chart.renderLines().single;
      expect(measureWidth(line), lessThanOrEqualTo(24));
      expect(line, contains('…'));
      expect(line, contains('█'));
    });

    test('pinned maxValue makes two charts comparable', () {
      final small = BarChart.of(
        [8],
        maxValue: 8000,
        width: 20,
        showValues: false,
      );
      final large = BarChart.of(
        [8000],
        maxValue: 8000,
        width: 20,
        showValues: false,
      );
      expect(small.render(), isNot(large.render()));
      // Unpinned, both fill the width and look identical.
      expect(
        BarChart.of([8], width: 20, showValues: false).render(),
        BarChart.of([8000], width: 20, showValues: false).render(),
      );
    });

    test('ascii output is entirely ascii', () {
      final chart = BarChart.of(
        [82, 64],
        labels: const ['a', 'b'],
        width: 30,
        theme: ChartTheme.ascii,
      );
      expect(chart.render().codeUnits.every((u) => u < 128 || u == 10), isTrue);
    });

    test('stripping colour reproduces the plain render', () {
      List<String> build(ChartTheme theme) => BarChart.of(
        [82, 64, 43],
        labels: const ['a', 'b', 'c'],
        width: 30,
        theme: theme,
        track: '░',
      ).renderLines();
      expect(
        build(ChartTheme.colorful).map(stripAnsi).toList(),
        build(ChartTheme.plain),
      );
    });
  });

  group('BarChart stacked', () {
    const series = [
      Series([5, 3, 8]),
      Series([3, 4, 2]),
      Series([2, 3, 0]),
    ];

    test('segments sum to exactly the bar width', () {
      // The largest-remainder property. Rounding each segment independently leaves
      // a one-cell hole in some rows and overflows others.
      for (final width in [10, 17, 23, 40]) {
        final chart = BarChart(
          series,
          mode: BarMode.percentStacked,
          width: width,
          showValues: false,
        );
        for (final line in chart.renderLines()) {
          expect(
            measureWidth(line),
            width,
            reason: 'width $width gave "$line"',
          );
        }
      }
    });

    test('percent mode fills every row completely', () {
      final chart = BarChart(
        series,
        mode: BarMode.percentStacked,
        width: 12,
        showValues: false,
      );
      for (final line in chart.renderLines()) {
        expect(line.contains(' '), isFalse, reason: line);
      }
    });

    test('plain stacked scales rows against the widest', () {
      final chart = BarChart(
        [
          Series([1, 10]),
        ],
        mode: BarMode.stacked,
        width: 20,
        showValues: false,
      );
      final lines = chart.renderLines();
      expect(
        measureWidth(lines[0].trimRight()),
        lessThan(measureWidth(lines[1].trimRight())),
      );
    });

    test('a row summing to zero stays empty, not 100% of the first series', () {
      // The classic trap: dividing by a zero row total makes the first share NaN,
      // and flooring plus a leftover pass can hand it the whole row.
      final chart = BarChart(
        [
          Series([0, 5]),
          Series([0, 5]),
        ],
        mode: BarMode.percentStacked,
        width: 10,
        showValues: false,
      );
      expect(chart.renderLines()[0].trim(), '');
      expect(chart.renderLines()[1].trim(), isNotEmpty);
    });

    test('a missing value in a stack counts as zero, not a gap', () {
      // Opposite of a line chart, and correct: a stack is a composition, so an
      // absent part contributes nothing rather than breaking the bar.
      final chart = BarChart(
        [
          Series([null]),
          Series([10]),
        ],
        mode: BarMode.percentStacked,
        width: 10,
        showValues: false,
      );
      expect(chart.renderLines().single.trim(), isNotEmpty);
    });

    test('distinguishes series by shade', () {
      final chart = BarChart(
        series,
        mode: BarMode.percentStacked,
        width: 20,
        showValues: false,
      );
      expect(
        chart.renderLines().first.runes.toSet().length,
        greaterThanOrEqualTo(2),
      );
    });
  });

  group('BarChart grouped', () {
    test('gives every series its own row', () {
      final chart = BarChart(
        [
          Series([5, 3], label: 'x'),
          Series([2, 7], label: 'y'),
        ],
        labels: const ['one', 'two'],
        mode: BarMode.grouped,
        width: 30,
      );
      expect(chart.renderLines(), hasLength(4));
    });
  });
}
