// A gallery of every chart type. Run it:
//
//   dart run example/console_charts_example.dart
//
// Nothing here imports dart:io — `print` is in dart:core — so this same file runs
// under `dart compile js` and in a browser console.
import 'dart:math' as math;

import 'package:console_charts/console_charts.dart';

const int w = 56;

void section(String title) {
  print('');
  print(rule(title, width: w));
  print('');
}

void main() {
  final loss = List<num>.generate(
    140,
    (i) => 2.4 * math.exp(-i / 45) + 0.05 + math.sin(i / 3) * 0.03,
  );
  final accuracy = List<num>.generate(
    140,
    (i) => 0.42 + 0.49 * (1 - math.exp(-i / 40)),
  );
  final throughput = List<num>.generate(
    140,
    (i) => 138000 + math.sin(i / 7) * 9000 + (i % 11) * 600,
  );

  section('sparklines');
  print(
    '  inline:  loss ${sparkline(loss, width: 20)} ${loss.last.toStringAsFixed(3)}',
  );
  print('  a gap stays a gap:  ${sparkline([5, 6, 7, null, null, 7, 6, 5])}');
  print('  ascii:   ${sparkline(loss, width: 20, theme: ChartTheme.ascii)}');
  print('');
  print(
    SparklineGroup(
      [
        Series(loss, label: 'loss'),
        Series(accuracy, label: 'accuracy'),
        Series(throughput, label: 'tokens/s'),
      ],
      width: w,
      valueFormat: formatCompact,
    ).render(),
  );

  section('line chart');
  print(
    LineChart.of(
      [20, 40, 62, 80, 100, 95, 72, 48, 32, 25],
      width: w,
      height: 11,
      xLabels: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
    ).render(),
  );

  section('multiple series');
  print(
    LineChart(
      const [
        Series([4, 9, 13, 11, 18, 22, 19], label: 'reqs'),
        Series([2, 3, 5, 9, 8, 12, 14], label: 'errs'),
      ],
      width: w,
      height: 10,
    ).render(),
  );

  section('area chart');
  print(
    AreaChart(
      const [
        Series([20, 40, 60, 80, 100, 95, 70, 45]),
      ],
      width: w,
      height: 10,
    ).render(),
  );

  section('horizontal bars');
  print(
    BarChart.of(
      [82, 64, 43, 27, 18],
      labels: const ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'],
      width: w,
      maxValue: 100,
      track: '░',
    ).render(),
  );

  section('100%-stacked bars');
  print(
    BarChart(
      const [
        Series([5, 3, 8], label: 'a'),
        Series([3, 4, 2], label: 'b'),
        Series([2, 3, 1], label: 'c'),
      ],
      labels: const ['Mon', 'Tue', 'Wed'],
      mode: BarMode.percentStacked,
      width: w,
    ).render(),
  );

  section('vertical bars, with negatives');
  print(
    ColumnChart.of(
      [40, -30, 60, -50, 20],
      labels: const ['A', 'B', 'C', 'D', 'E'],
      width: w,
      height: 11,
    ).render(),
  );

  section('histogram');
  print(
    Histogram(
      [for (var i = 0; i < 400; i++) (i % 7) + (i % 3) * 2 + (i % 11) * 0.5],
      binCount: 9,
      width: w,
      height: 9,
    ).render(),
  );

  section('scatter');
  print(
    ScatterChart.fromLists(
      [5, 20, 25, 40, 45, 60, 65, 80, 95],
      [10, 40, 35, 60, 55, 60, 80, 85, 100],
      width: w,
      height: 10,
    ).render(),
  );

  section('gauges, progress and bullets');
  print(
    Gauge(const [
      GaugeRow(0.68, label: 'CPU'),
      GaugeRow(0.82, label: 'RAM'),
      GaugeRow(0.97, label: 'GPU'),
    ], width: w).render(),
  );
  print('');
  print(ProgressBar(0.8, label: 'Downloading', width: w).render());
  print('');
  print(
    BulletChart(const [
      GaugeRow(0.72, label: 'CPU', target: 0.80),
      GaugeRow(0.84, label: 'RAM', target: 0.75),
    ], width: w).render(),
  );

  section('box plot');
  print(
    BoxPlot.of({
      'latency': [12, 14, 15, 15, 16, 18, 20, 22, 60],
      'startup': [3, 4, 4, 5, 5, 6, 7, 8],
      'teardown': [1, 2, 2, 3, 9],
    }, width: w).render(),
  );

  section('candlestick');
  print(
    CandlestickChart(
      const [
        Candle(open: 70, high: 82, low: 68, close: 80, label: 'M'),
        Candle(open: 80, high: 95, low: 78, close: 92, label: 'T'),
        Candle(open: 92, high: 110, low: 90, close: 96, label: 'W'),
        Candle(open: 96, high: 100, low: 80, close: 84, label: 'T'),
        Candle(open: 84, high: 88, low: 70, close: 72, label: 'F'),
      ],
      width: w,
      height: 11,
    ).render(),
  );

  section('waterfall');
  print(
    WaterfallChart(
      const [
        WaterfallStep('Start', 100),
        WaterfallStep('+A', 40),
        WaterfallStep('-B', -70),
        WaterfallStep('+C', 30),
        WaterfallStep.total('End'),
      ],
      width: w,
      height: 10,
    ).render(),
  );

  section('heatmap');
  print(
    Heatmap(
      GridData(
        [
          for (var h = 0; h < 6; h++)
            [for (var d = 0; d < 7; d++) (h * 3 + d * 2) % 10],
        ],
        rowLabels: const ['00h', '04h', '08h', '12h', '16h', '20h'],
        columnLabels: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
      ),
      cellWidth: 4,
      showLegend: true,
    ).render(),
  );

  section('calendar heatmap');
  print(
    CalendarHeatmap({
      for (var d = 0; d < 70; d++)
        DateTime.utc(2026, 1, 5).add(Duration(days: d)): (d * 7) % 11,
    }).render(),
  );

  section('block chart');
  print(BlockChart([1, 2, 3, 5, 8, 13, 21, 34], height: 8).render());

  section('table');
  print(
    const Table(
      [
        ['attn.q', '147456', '-8.52', '-1.09'],
        ['mlp.down', '589824', '-24.00', '-2.31'],
        ['embed', '32768', '-6.10', '-0.94'],
      ],
      header: ['role', 'blocks', 'min', 'max'],
      rule: true,
    ).render(),
  );

  section('rules');
  print(rule('Training', width: w));
  print(rule('Done', width: w, style: RuleStyle.heavy));
  print(rule('CONSOLE', width: w, style: RuleStyle.dotted));

  section('dashboard');
  print(
    Dashboard(
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
            SparklineGroup([
              Series(loss, label: 'loss'),
              Series(accuracy, label: 'acc'),
            ], width: 24),
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
    ).render(),
  );

  section('every charset');
  for (final charset in CharSets.all) {
    print('  ${charset.name}');
    print(
      LineChart.of(
        [20, 45, 70, 95, 80, 55, 30],
        width: 44,
        height: 7,
        theme: ChartTheme(charset: charset),
      ).render(),
    );
    print('');
  }
}
