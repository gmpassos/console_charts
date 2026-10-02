import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

void main() {
  group('Gauge', () {
    test('renders bracketed bars with percentages', () {
      const gauge = Gauge(
        [
          GaugeRow(0.68, label: 'CPU'),
          GaugeRow(0.82, label: 'RAM'),
          GaugeRow(0.97, label: 'GPU'),
        ],
        width: 30,
        fractional: false,
      );
      // Body is 22 columns (30 - 4 label - 4 value), brackets take two, so the bar
      // is 20 wide and whole-cell mode floors 68% to thirteen cells.
      expect(
        gauge.render(),
        [
          'CPU [█████████████░░░░░░░] 68%',
          'RAM [████████████████░░░░] 82%',
          'GPU [███████████████████░] 97%',
        ].join('\n'),
      );
    });

    test('a full reading fills every cell', () {
      // The epsilon case. Without it, (0.9999999 * cells * 8).floor() leaves the
      // last eighth unfilled and a gauge at 100% shows a gap, which gets reported
      // as a bug every time.
      for (final value in [1.0, 0.9999999999, 1.5]) {
        final out = Gauge.single(value, width: 12, showValues: false).render();
        expect(out, '[██████████]', reason: '$value');
      }
    });

    test('an empty reading fills nothing', () {
      for (final value in [0.0, -0.3, double.nan]) {
        final out = Gauge.single(value, width: 12, showValues: false).render();
        expect(out, '[░░░░░░░░░░]', reason: '$value');
      }
    });

    test('flags an overflowing reading rather than hiding it', () {
      final out = Gauge.single(1.4, width: 16).render();
      expect(out, contains('!'));
      expect(out, contains('140%'));
    });

    test('scales against an explicit max', () {
      final out = Gauge(
        [const GaugeRow(50, max: 200)],
        width: 14,
        showValues: false,
      ).render();
      // A quarter of the way along.
      expect(out, '[███░░░░░░░░░]');
    });

    test('a zero max yields an empty bar rather than dividing by zero', () {
      final out = Gauge(
        [const GaugeRow(5, max: 0)],
        width: 12,
        showValues: false,
      ).render();
      expect(out, '[░░░░░░░░░░]');
    });

    test('readings never decrease in length as they increase', () {
      final rows = [for (var i = 0; i <= 10; i++) GaugeRow(i / 10)];
      var previous = -1;
      for (final line in Gauge(
        rows,
        width: 24,
        showValues: false,
      ).renderLines()) {
        final filled = line.split('').where((c) => c == '█').length;
        expect(filled, greaterThanOrEqualTo(previous));
        previous = filled;
      }
    });

    test('is empty for no rows', () {
      expect(const Gauge([]).renderLines(), isEmpty);
    });

    test('never exceeds the requested width', () {
      for (final width in [6, 10, 20, 50]) {
        final lines = Gauge([
          const GaugeRow(0.5, label: 'label'),
        ], width: width).renderLines();
        for (final line in lines) {
          expect(
            measureWidth(line),
            lessThanOrEqualTo(width),
            reason: '$width',
          );
        }
      }
    });

    test('drops brackets when asked', () {
      final out = Gauge.single(
        1,
        width: 6,
        showValues: false,
        brackets: false,
      ).render();
      expect(out, '██████');
    });

    test('ascii output is entirely ascii', () {
      final out = Gauge(
        [const GaugeRow(0.5, label: 'cpu')],
        width: 20,
        theme: ChartTheme.ascii,
      ).render();
      expect(out.codeUnits.every((u) => u < 128), isTrue);
    });

    test('stripping colour reproduces the plain render', () {
      String build(ChartTheme theme) => Gauge(
        [
          const GaugeRow(0.68, label: 'CPU'),
          const GaugeRow(0.82, label: 'RAM'),
        ],
        width: 30,
        theme: theme,
      ).render();
      expect(stripAnsi(build(ChartTheme.colorful)), build(ChartTheme.plain));
    });
  });

  group('ProgressBar', () {
    test('prints a caption above the bar', () {
      final bar = ProgressBar(0.8, label: 'Downloading', width: 28);
      final lines = bar.renderLines();
      expect(lines.first, 'Downloading');
      expect(lines.last, contains('80%'));
      expect(lines, hasLength(2));
    });

    test('omits the caption line when there is none', () {
      expect(ProgressBar(0.5, width: 20).renderLines(), hasLength(1));
    });

    test('clamps the bar but reports the true figure', () {
      // The bar has nowhere to put an extra 100%, but reporting it as 100% would
      // turn an overflow into a silent success — the one thing a progress
      // indicator must not do. So the bar fills and the label says 200%.
      final over = ProgressBar(2, width: 20).render();
      expect(over, contains('200%'));
      expect(over, contains('!'));
      expect(over, isNot(contains('░')));

      final under = ProgressBar(-1, width: 20).render();
      expect(under, contains('0%'));
      expect(under, isNot(contains('█')));
    });
  });

  group('BulletChart', () {
    test('marks the target inside the bar', () {
      const chart = BulletChart([
        GaugeRow(0.72, label: 'CPU', target: 0.8),
      ], width: 44);
      final line = chart.renderLines().single;
      expect(line, contains('72%'));
      expect(line, contains('80%'));
      // The marker replaces a track cell at the target position.
      expect(line.indexOf('│'), greaterThan(line.indexOf('[')));
    });

    test('a row without a target renders as a plain gauge', () {
      const chart = BulletChart([GaugeRow(0.5, label: 'x')], width: 30);
      expect(chart.renderLines().single, contains('50%'));
    });

    test('a target at the maximum sits at the bar end, not past it', () {
      const chart = BulletChart(
        [GaugeRow(0.5, label: 'x', target: 1.0)],
        width: 30,
        showValues: false,
      );
      final line = chart.renderLines().single;
      expect(measureWidth(line), lessThanOrEqualTo(30));
      expect(line, endsWith(']'));
    });

    test('never exceeds the requested width', () {
      for (final width in [10, 24, 60]) {
        final lines = BulletChart([
          const GaugeRow(0.72, label: 'CPU', target: 0.8),
        ], width: width).renderLines();
        for (final line in lines) {
          expect(
            measureWidth(line),
            lessThanOrEqualTo(width),
            reason: '$width',
          );
        }
      }
    });

    test('is empty for no rows', () {
      expect(const BulletChart([]).renderLines(), isEmpty);
    });
  });
}
