import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

/// Expected output as a leading-pipe block, so meaningful leading spaces survive
/// and the left edge is visible in the source.
String block(String s) => s
    .split('\n')
    .where((l) => l.trimLeft().startsWith('|'))
    .map((l) => l.substring(l.indexOf('|') + 1))
    .join('\n');

/// The README shows rendered output. Output in documentation rots silently — it
/// stays plausible long after it stops being what the code produces, and a reader
/// has no way to tell. These pin every sample in it.
void main() {
  group('README samples', () {
    test('the opening sparkline', () {
      expect(sparkline([1, 3, 2, 5, 8, 6, 9]), '▁▃▂▅▇▅█');
    });

    test('the gap sparkline', () {
      expect(sparkline([5, 6, 7, null, null, 7, 6, 5]), '▁▅█  █▅▁');
    });

    test('the line chart', () {
      expect(
        LineChart.of(
          [20, 40, 62, 80, 100, 95, 72, 48, 32, 25],
          width: 56,
          height: 11,
          xLabels: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
        ).render(),
        block(r'''
          |100 ┤                    ╭──────╮
          |    │                  ╭─╯      ╰──╮
          | 80 ┤               ╭──╯           ╰─╮
          |    │            ╭──╯                ╰─╮
          | 60 ┤         ╭──╯                     ╰──╮
          |    │      ╭──╯                           ╰─╮
          | 40 ┤    ╭─╯                                ╰───╮
          |    │ ╭──╯                                      ╰───────
          | 20 ┤─╯
          |    ┼───────────────────────────────────────────────────
          |     Jan    Feb      Mar     Apr     May      Jun    Jul
        '''),
      );
    });

    test('the ascii chart', () {
      expect(
        LineChart.of(
          [20, 45, 70, 95, 80, 55, 30],
          width: 44,
          height: 7,
          theme: ChartTheme.ascii,
        ).render(),
        block(r'''
          |100 +                  /-\
          | 80 +              /---/ \-----\
          | 60 +          /---/           \---\
          |    |      /---/                   \---\
          | 40 +  /---/                           \----
          | 20 +--/
          |    +---------------------------------------
        '''),
      );
    });

    test('ascii and unicode differ only in glyphs, as claimed', () {
      // The README says a chart drawn with CharSets.ascii occupies exactly the same
      // rows and columns as the Unicode one, cell for cell. This is that claim.
      List<String> render(ChartTheme theme) => LineChart.of(
        [20, 45, 70, 95, 80, 55, 30],
        width: 44,
        height: 7,
        theme: theme,
      ).renderLines();
      final uni = render(ChartTheme.plain);
      final asc = render(ChartTheme.ascii);
      expect(asc, hasLength(uni.length));
      for (var r = 0; r < uni.length; r++) {
        expect(asc[r].length, uni[r].length, reason: 'row $r');
        for (var c = 0; c < uni[r].length; c++) {
          expect(asc[r][c] == ' ', uni[r][c] == ' ', reason: 'row $r col $c');
        }
      }
      // And the ascii render really is ascii.
      expect(asc.join().codeUnits.every((u) => u < 128), isTrue);
    });

    test('the dashboard', () {
      final loss = List<num>.generate(60, (i) => 100 - i * 1.5);
      final accuracy = List<num>.generate(60, (i) => 40 + i);
      final out = Dashboard(
        [
          [
            Panel(
              Gauge(const [
                GaugeRow(0.68, label: 'cpu'),
                GaugeRow(0.82, label: 'ram'),
              ], width: 22),
              title: 'System',
            ),
            Panel(
              SparklineGroup(
                [Series(loss, label: 'loss'), Series(accuracy, label: 'acc')],
                width: 24,
                showValues: false,
              ),
              title: 'Training',
            ),
          ],
          [
            Panel(
              BarChart.of(
                [12, 7, 3],
                labels: const ['warn', 'error', 'fatal'],
                width: 48,
              ),
              title: 'Log levels',
            ),
          ],
        ],
        title: 'Run 1842',
        framed: true,
      ).renderLines();

      // Composition, not an exact picture: every line the same width, framed, and
      // the nested panels present.
      final width = measureWidth(out.first);
      for (final line in out) {
        expect(measureWidth(line), width, reason: '"$line"');
      }
      expect(out.first, contains('Run 1842'));
      expect(out.any((l) => l.contains('System')), isTrue);
      expect(out.any((l) => l.contains('Training')), isTrue);
      expect(out.any((l) => l.contains('Log levels')), isTrue);
    });

    test('the extension example compiles and renders', () {
      // The README shows a custom chart type built on renderPlotFrame. If the
      // extension API changes shape, this is what notices.
      final chart = StepChart([1, 4, 2, 8, 5, 7]);
      final lines = chart.renderLines();
      expect(lines, hasLength(10));
      for (final line in lines) {
        expect(measureWidth(line), lessThanOrEqualTo(40));
      }
    });
  });
}

/// The custom chart type from the README's "Extending" section, verbatim.
class StepChart implements Renderable {
  const StepChart(this.values, {this.width = 40, this.height = 10});

  final List<num?> values;
  final int width;
  final int height;

  @override
  List<String> renderLines() => renderPlotFrame(
    width: width,
    height: height,
    yScale: LinearScale.fit(values, height),
    xScale: (plotWidth) => LinearScale.index(values.length, plotWidth),
    draw: (plot) {
      for (var x = 0; x < plot.width; x++) {
        plot.fillQuantity(x, values[x * values.length ~/ plot.width]);
      }
    },
  );

  @override
  String render() => renderLines().join('\n');
}
