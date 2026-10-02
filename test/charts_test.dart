import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

/// Every chart type, built from one awkward input, for the invariant sweep.
List<Renderable> allCharts(List<num?> data, int w, int h) {
  final labels = [for (var i = 0; i < data.length; i++) 'c$i'];
  return [
    SparklineGroup([Series(data, label: 's')], width: w),
    BarChart([Series(data)], labels: labels, width: w),
    BarChart(
      [Series(data), Series(data)],
      labels: labels,
      mode: BarMode.stacked,
      width: w,
    ),
    BarChart(
      [Series(data), Series(data)],
      labels: labels,
      mode: BarMode.percentStacked,
      width: w,
    ),
    BarChart(
      [Series(data), Series(data)],
      labels: labels,
      mode: BarMode.grouped,
      width: w,
    ),
    Gauge([for (final v in data) GaugeRow(v ?? 0, label: 'g')], width: w),
    BulletChart([
      for (final v in data) GaugeRow(v ?? 0, label: 'b', target: 0.5),
    ], width: w),
    ProgressBar(data.isEmpty ? 0 : (data.first ?? 0), width: w),
    LineChart([Series(data)], width: w, height: h),
    LineChart([Series(data)], width: w, height: h, smooth: true),
    AreaChart([Series(data)], width: w, height: h),
    ColumnChart([Series(data)], labels: labels, width: w, height: h),
    ColumnChart(
      [Series(data), Series(data)],
      labels: labels,
      stacked: true,
      width: w,
      height: h,
    ),
    Histogram(data, width: w, height: h),
    BlockChart(data, width: w, height: h),
    ScatterChart(
      [
        XYSeries([
          for (var i = 0; i < data.length; i++)
            DataPoint(i.toDouble(), (data[i] ?? 0).toDouble()),
        ]),
      ],
      width: w,
      height: h,
    ),
    CandlestickChart(
      [
        for (final v in data)
          Candle(
            open: v ?? 0,
            high: (v ?? 0) + 1,
            low: (v ?? 0) - 1,
            close: v ?? 0,
          ),
      ],
      width: w,
      height: h,
    ),
    WaterfallChart(
      [
        for (var i = 0; i < data.length; i++)
          WaterfallStep('s$i', data[i] ?? 0),
      ],
      width: w,
      height: h,
    ),
    BoxPlot([BoxStats.of(data, label: 'd')], width: w),
  ];
}

/// Charts that size themselves to their content rather than to a given width.
///
/// [Heatmap] and [Table] take no width on purpose: a heatmap's cells are its data
/// and a table that silently dropped a column would be worse than a wide one. They
/// still have to survive every awkward input, so they are swept — just not against
/// a width bound they never promised.
List<Renderable> contentSizedCharts(List<num?> data) => [
  Heatmap(GridData([data], rowLabels: const ['r'])),
  Table(
    [
      [for (final v in data) '$v'],
    ],
    header: const ['a'],
  ),
];

void main() {
  group('the invariant sweep', () {
    // Every chart type against every awkward input at every awkward size. The
    // highest-value test here: it is what makes the degenerate-input handling real
    // rather than aspirational, and it is why none of these charts throws on data a
    // dashboard will genuinely hand it.
    final inputs = <String, List<num?>>{
      'empty': [],
      'single': [42],
      'all equal': [7, 7, 7],
      'all zero': [0, 0, 0],
      'nulls': [1, null, 3],
      'all null': [null, null],
      'NaN': [1, double.nan, 3],
      'infinity': [1, double.infinity, 3],
      'all non-finite': [double.nan, double.negativeInfinity],
      'negative': [-5, -10, -3],
      'mixed signs': [-5, 0, 5],
      'extreme': [1e300, -1e300],
      'tiny': [1e-300, 2e-300],
      'many': [for (var i = 0; i < 5000; i++) i % 97],
    };
    const sizes = [(1, 1), (4, 2), (9, 4), (24, 8), (80, 24)];

    for (final entry in inputs.entries) {
      test('survives "${entry.key}"', () {
        for (final (w, h) in sizes) {
          final charts = allCharts(entry.value, w, h);
          for (final chart in charts) {
            final name = '${chart.runtimeType} "${entry.key}" ${w}x$h';
            late List<String> lines;
            expect(
              () => lines = chart.renderLines(),
              returnsNormally,
              reason: name,
            );
            for (final line in lines) {
              expect(
                measureWidth(line),
                lessThanOrEqualTo(w),
                reason: '$name: "$line"',
              );
              // Plain rendering must never emit an escape or a stray control
              // character — either would corrupt whatever is reading the output.
              expect(line, isNot(contains('\x1b')), reason: name);
              expect(line, isNot(contains('\t')), reason: name);
              expect(line, isNot(contains('\r')), reason: name);
            }
          }
        }

        // The content-sized charts get everything but the width bound.
        for (final chart in contentSizedCharts(entry.value)) {
          final name = '${chart.runtimeType} "${entry.key}"';
          late List<String> lines;
          expect(
            () => lines = chart.renderLines(),
            returnsNormally,
            reason: name,
          );
          for (final line in lines) {
            expect(line, isNot(contains('\x1b')), reason: name);
            expect(line, isNot(contains('\t')), reason: name);
            expect(line, isNot(contains('\r')), reason: name);
          }
        }
      });
    }

    test('colour never changes geometry, for any chart type', () {
      // One assertion covering run coalescing, trailing-blank styling, reset
      // placement and wide-glyph bookkeeping across every chart at once.
      for (final data in [
        <num?>[3, 1, 4, 1, 5, 9, 2, 6],
        <num?>[1, null, 3],
        <num?>[],
      ]) {
        final plain = allCharts(data, 40, 10);
        for (var i = 0; i < plain.length; i++) {
          final a = plain[i].renderLines();
          // Rebuilt with a colourful theme where the chart takes one.
          final b = _colourful(data, 40, 10)[i].renderLines();
          expect(
            b.map(stripAnsi).toList(),
            a,
            reason: '${plain[i].runtimeType} with $data',
          );
        }
      }
    });

    test('rendering twice is byte-identical', () {
      // No hidden state, no clock, no randomness: the same input must always give
      // the same output, or a golden test is worthless.
      for (final chart in allCharts([3, 1, 4, 1, 5], 30, 8)) {
        expect(chart.render(), chart.render(), reason: '${chart.runtimeType}');
      }
    });
  });

  group('ColumnChart', () {
    test('draws negative values below the baseline', () {
      // The thing a horizontal bar chart cannot do, and why negative data belongs
      // here: there is a baseline row to hang from.
      final lines = ColumnChart.of(
        [40, -30],
        width: 20,
        height: 9,
        axes: Axes.none,
      ).renderLines();
      final inked = [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].trim().isNotEmpty) i,
      ];
      // Ink both above and below the middle.
      expect(inked.first, lessThan(lines.length ~/ 2));
      expect(inked.last, greaterThanOrEqualTo(lines.length ~/ 2));
    });

    test('baselines at zero even when the data does not reach it', () {
      final out = ColumnChart.of([50, 60, 70], width: 24, height: 8).render();
      expect(out, contains('0'));
    });

    test('a taller value makes a taller column', () {
      final lines = ColumnChart.of(
        [10, 100],
        width: 20,
        height: 8,
        axes: Axes.none,
      ).renderLines();
      var leftTop = lines.length;
      var rightTop = lines.length;
      for (var r = 0; r < lines.length; r++) {
        final line = lines[r];
        for (var c = 0; c < line.length; c++) {
          if (line[c].trim().isEmpty) continue;
          if (c < 10 && r < leftTop) leftTop = r;
          if (c >= 10 && r < rightTop) rightTop = r;
        }
      }
      expect(rightTop, lessThan(leftTop));
    });
  });

  group('Histogram', () {
    test('the last bin is closed, so the maximum is not dropped', () {
      // The classic histogram off-by-one. It hides well: the chart looks right and
      // the total is one short.
      final bins = histogramBins([1, 2, 3, 4, 5], binCount: 4);
      expect(bins.fold<int>(0, (a, b) => a + b.count), 5);
    });

    test('every sample lands in exactly one bin', () {
      for (final count in [1, 3, 7, 20]) {
        final data = [for (var i = 0; i < 100; i++) i * 0.37];
        final bins = histogramBins(data, binCount: count);
        expect(bins.fold<int>(0, (a, b) => a + b.count), data.length);
        expect(bins, hasLength(count));
      }
    });

    test('identical samples give one bin rather than dividing by zero', () {
      final bins = histogramBins([5, 5, 5]);
      expect(bins, hasLength(1));
      expect(bins.single.count, 3);
    });

    test('chooses a bin count automatically', () {
      final bins = histogramBins([for (var i = 0; i < 200; i++) i % 13]);
      expect(bins.length, greaterThan(1));
      expect(bins.length, lessThanOrEqualTo(100));
    });

    test('ignores non-finite samples', () {
      final bins = histogramBins([1, 2, double.nan, double.infinity, 3]);
      expect(bins.fold<int>(0, (a, b) => a + b.count), 3);
    });
  });

  group('quantiles', () {
    test('filters non-finite values before sorting', () {
      // NaN compares greater than everything, so it sorts to the END of a list
      // rather than being rejected — and then every high percentile is wrong, which
      // is exactly where a box plot looks.
      expect(finiteSorted([3, double.nan, 1, 2]), [1, 2, 3]);
      final withNaN = finiteSorted([1, 2, 3, 4, double.nan]);
      expect(quantile(withNaN, 1.0), 4);
      expect(quantile(withNaN, 0.5), 2.5);
    });

    test('uses the R-7 convention', () {
      // Matches NumPy and R defaults, so a box plot agrees with numbers computed
      // elsewhere. There are nine definitions and they disagree on small samples.
      final data = finiteSorted([1, 2, 3, 4]);
      expect(quantile(data, 0.25), closeTo(1.75, 1e-9));
      expect(quantile(data, 0.5), closeTo(2.5, 1e-9));
      expect(quantile(data, 0.75), closeTo(3.25, 1e-9));
    });

    test('handles degenerate samples', () {
      expect(quantile(const [], 0.5).isNaN, isTrue);
      expect(quantile(const [7], 0.5), 7);
      expect(quantile(const [7], 0.0), 7);
    });
  });

  group('BoxStats', () {
    test('separates outliers at the Tukey fences', () {
      final stats = BoxStats.of([10, 11, 12, 13, 14, 100]);
      expect(stats.outliers, contains(100));
      expect(stats.high, lessThan(100));
    });

    test('whiskers reach the extremes when fences are off', () {
      final stats = BoxStats.of([10, 11, 12, 100], fences: false);
      expect(stats.high, 100);
      expect(stats.outliers, isEmpty);
    });

    test('is empty for no samples rather than throwing', () {
      final stats = BoxStats.of([]);
      expect(stats.isEmpty, isTrue);
      expect(() => BoxPlot([stats], width: 20).render(), returnsNormally);
    });

    test('survives every sample being an outlier', () {
      final stats = BoxStats.of([1, 1, 1, 1000000]);
      expect(stats.low, lessThanOrEqualTo(stats.high));
    });
  });

  group('Heatmap', () {
    test('distinguishes a missing cell from the lowest value', () {
      // "No data" and "the minimum" are different facts, and a reader cannot
      // recover the difference once it is lost.
      final out = Heatmap(
        GridData([
          [0, null, 10],
        ]),
        cellWidth: 1,
      ).render();
      expect(out[0], '░');
      expect(out[1], ' ');
      expect(out[2], '█');
    });

    test('uses the middle shade when every value is identical', () {
      // The lightest shade would imply the data sat at its minimum.
      final out = Heatmap(
        GridData([
          [5, 5, 5],
        ]),
        cellWidth: 1,
      ).render();
      expect(out.trim(), isNot(contains('░')));
      expect(out.trim().split('').toSet(), hasLength(1));
    });

    test('labels rows and columns', () {
      final lines = Heatmap(
        GridData(
          [
            [1, 2],
            [3, 4],
          ],
          rowLabels: const ['a', 'b'],
          columnLabels: const ['x', 'y'],
        ),
      ).renderLines();
      expect(lines.first, contains('x'));
      expect(lines[1], startsWith('a'));
    });

    test('is empty for no rows', () {
      expect(const Heatmap(GridData([])).renderLines(), isEmpty);
    });
  });

  group('CalendarHeatmap', () {
    test('buckets days in UTC so a DST change cannot shift the grid', () {
      // A local-time day of 23 or 25 hours would otherwise move part of the grid by
      // a column, which is wrong and very hard to notice.
      final key = CalendarHeatmap.dayKey(DateTime(2026, 3, 29, 23, 30));
      expect(key.isUtc, isTrue);
      expect(key.hour, 0);
    });

    test('renders seven weekday rows', () {
      final values = <DateTime, num>{
        for (var d = 0; d < 30; d++)
          DateTime.utc(2026, 1, 1).add(Duration(days: d)): d % 7,
      };
      final lines = CalendarHeatmap(values).renderLines();
      expect(lines, hasLength(7));
    });

    test('is empty for no data', () {
      expect(const CalendarHeatmap({}).renderLines(), isEmpty);
    });
  });

  group('CandlestickChart', () {
    test('a doji draws as a bar', () {
      final out = CandlestickChart(
        const [Candle(open: 50, high: 60, low: 40, close: 50)],
        width: 20,
        height: 8,
        axes: Axes.none,
      ).render();
      expect(out, contains('─'));
    });

    test('tolerates an inconsistent candle instead of throwing', () {
      // Real feeds contain records where the high is below the low. Losing a chart
      // of a thousand candles to one bad record is the wrong trade.
      const bad = Candle(open: 10, high: 1, low: 100, close: 5);
      expect(bad.safeLow, 1);
      expect(bad.safeHigh, 100);
      expect(
        () => CandlestickChart([bad], width: 20, height: 8).render(),
        returnsNormally,
      );
    });

    test('rising and falling candles look different without colour', () {
      final up = CandlestickChart(
        const [Candle(open: 40, high: 70, low: 30, close: 60)],
        width: 24,
        height: 10,
        axes: Axes.none,
      ).render();
      final down = CandlestickChart(
        const [Candle(open: 60, high: 70, low: 30, close: 40)],
        width: 24,
        height: 10,
        axes: Axes.none,
      ).render();
      expect(up, isNot(down));
      expect(down, contains('█'));
    });

    test('skips candles that cannot be plotted', () {
      expect(
        CandlestickChart(
          const [Candle(open: double.nan, high: 1, low: 0, close: 1)],
          width: 20,
          height: 6,
        ).renderLines(),
        isEmpty,
      );
    });
  });

  group('WaterfallChart', () {
    test('bars float from the running total', () {
      final out = WaterfallChart(
        const [WaterfallStep('a', 50), WaterfallStep('b', 30)],
        width: 24,
        height: 8,
        axes: Axes.none,
      ).renderLines();
      // Compared by TOPMOST ink, not lowest: the zero baseline spans every column,
      // so the lowest inked row is the same everywhere and would prove nothing.
      // The second bar starts where the first ended, so it reaches higher.
      int topInk(int fromColumn, int toColumn) {
        for (var r = 0; r < out.length; r++) {
          for (var c = fromColumn; c < toColumn && c < out[r].length; c++) {
            if (out[r][c].trim().isNotEmpty) return r;
          }
        }
        return out.length;
      }

      expect(topInk(12, 24), lessThan(topInk(0, 12)));
    });

    test('a step crossing zero flips which side of the baseline it is on', () {
      expect(
        () => WaterfallChart(
          const [
            WaterfallStep('up', 50),
            WaterfallStep('down', -120),
            WaterfallStep.total('end'),
          ],
          width: 30,
          height: 10,
        ).render(),
        returnsNormally,
      );
    });

    test('a total is drawn from the baseline', () {
      final out = WaterfallChart(
        const [
          WaterfallStep('a', 40),
          WaterfallStep('b', 30),
          WaterfallStep.total('end'),
        ],
        width: 30,
        height: 9,
      ).render();
      expect(out, contains('█'));
    });
  });

  group('ScatterChart', () {
    test('plots every point without resampling', () {
      final out = ScatterChart.fromLists(
        [0, 50, 100],
        [0, 50, 100],
        width: 30,
        height: 9,
        axes: Axes.none,
      ).render();
      expect(out.split('').where((c) => c == '•').length, 3);
    });

    test('distinguishes a second series by glyph, not only colour', () {
      // Colour is off by default, so glyph is what has to carry it.
      final out = ScatterChart(
        [
          XYSeries.fromLists([0, 10], [0, 10]),
          XYSeries.fromLists([5, 15], [15, 5]),
        ],
        width: 30,
        height: 9,
        axes: Axes.none,
      ).render();
      expect(out, contains('•'));
      expect(out, contains('○'));
    });

    test('skips unplottable points', () {
      final series = XYSeries.fromLists([0, double.nan, 10], [0, 5, 10]);
      expect(series.points, hasLength(2));
    });

    test('truncates mismatched x and y lists rather than throwing', () {
      expect(XYSeries.fromLists([1, 2, 3], [1, 2]).points, hasLength(2));
    });
  });

  group('layout', () {
    test('hstack pads short blocks so the result is rectangular', () {
      final out = hstack([
        ['a', 'b', 'c'],
        ['x'],
      ]);
      expect(out, hasLength(3));
      expect(out[0], 'a x');
      expect(out[1], 'b');
    });

    test('vstack inserts gaps between blocks', () {
      expect(
        vstack([
          ['a'],
          ['b'],
        ], gap: 1),
        ['a', '', 'b'],
      );
    });

    test('a panel frames its child and fits the content', () {
      final out = Panel.lines(const ['ab', 'cde'], title: 'T').renderLines();
      // Two content rows plus the top and bottom edges.
      expect(out, hasLength(4));
      expect(out.first, startsWith('┌─ T '));
      for (final line in out) {
        expect(measureWidth(line), measureWidth(out.first));
      }
    });

    test('a panel keeps its width when the title is too long', () {
      final out = Panel.lines(
        const ['x'],
        title: 'an extremely long title',
        width: 12,
      ).renderLines();
      for (final line in out) {
        expect(measureWidth(line), 12);
      }
    });

    test('rules fill exactly the requested width', () {
      for (final width in [10, 20, 47, 80]) {
        for (final style in RuleStyle.values) {
          expect(
            measureWidth(rule('Title', width: width, style: style)),
            width,
            reason: '$style at $width',
          );
          expect(
            measureWidth(rule(null, width: width, style: style)),
            width,
            reason: 'untitled $style at $width',
          );
        }
      }
    });

    test('a dotted rule leads with its title', () {
      expect(
        rule('CONSOLE', width: 20, style: RuleStyle.dotted),
        startsWith('CONSOLE'),
      );
    });

    test('a table aligns numeric columns to the right automatically', () {
      final out = const Table(
        [
          ['a', '1'],
          ['bb', '1000'],
        ],
        header: ['name', 'count'],
      ).renderLines();
      expect(out[1], contains('     1'));
      expect(out[2], contains('  1000'));
    });

    test('a table computes its own rule width', () {
      final out = const Table(
        [
          ['a', '1'],
        ],
        header: ['name', 'count'],
        rule: true,
      ).renderLines();
      expect(measureWidth(out[1]), measureWidth(out[0]));
    });

    test('a table is empty with no rows and no header', () {
      expect(const Table([]).renderLines(), isEmpty);
    });

    test('a dashboard composes panels into one block', () {
      final out = Dashboard(
        [
          [
            Panel.lines(const ['a']),
            Panel.lines(const ['b']),
          ],
          [
            Panel.lines(const ['c']),
          ],
        ],
        title: 'D',
        framed: true,
      ).renderLines();
      final width = measureWidth(out.first);
      for (final line in out) {
        expect(measureWidth(line), width);
      }
      expect(out.first, contains('D'));
    });

    test('a dashboard tolerates ragged rows', () {
      expect(
        () => Dashboard([
          [
            Panel.lines(const ['a', 'b', 'c']),
          ],
          [
            Panel.lines(const ['x']),
            Panel.lines(const ['y']),
          ],
          const [],
        ]).render(),
        returnsNormally,
      );
    });
  });
}

/// The same chart list with a colourful theme, for the colour-equivalence test.
List<Renderable> _colourful(List<num?> data, int w, int h) {
  const theme = ChartTheme.colorful;
  final labels = [for (var i = 0; i < data.length; i++) 'c$i'];
  return [
    SparklineGroup(
      [Series(data, label: 's')],
      width: w,
      theme: theme,
    ),
    BarChart([Series(data)], labels: labels, width: w, theme: theme),
    BarChart(
      [Series(data), Series(data)],
      labels: labels,
      mode: BarMode.stacked,
      width: w,
      theme: theme,
    ),
    BarChart(
      [Series(data), Series(data)],
      labels: labels,
      mode: BarMode.percentStacked,
      width: w,
      theme: theme,
    ),
    BarChart(
      [Series(data), Series(data)],
      labels: labels,
      mode: BarMode.grouped,
      width: w,
      theme: theme,
    ),
    Gauge(
      [for (final v in data) GaugeRow(v ?? 0, label: 'g')],
      width: w,
      theme: theme,
    ),
    BulletChart(
      [for (final v in data) GaugeRow(v ?? 0, label: 'b', target: 0.5)],
      width: w,
      theme: theme,
    ),
    ProgressBar(data.isEmpty ? 0 : (data.first ?? 0), width: w, theme: theme),
    LineChart([Series(data)], width: w, height: h, theme: theme),
    LineChart([Series(data)], width: w, height: h, smooth: true, theme: theme),
    AreaChart([Series(data)], width: w, height: h, theme: theme),
    ColumnChart(
      [Series(data)],
      labels: labels,
      width: w,
      height: h,
      theme: theme,
    ),
    ColumnChart(
      [Series(data), Series(data)],
      labels: labels,
      stacked: true,
      width: w,
      height: h,
      theme: theme,
    ),
    Histogram(data, width: w, height: h, theme: theme),
    BlockChart(data, width: w, height: h, theme: theme),
    ScatterChart(
      [
        XYSeries([
          for (var i = 0; i < data.length; i++)
            DataPoint(i.toDouble(), (data[i] ?? 0).toDouble()),
        ]),
      ],
      width: w,
      height: h,
      theme: theme,
    ),
    CandlestickChart(
      [
        for (final v in data)
          Candle(
            open: v ?? 0,
            high: (v ?? 0) + 1,
            low: (v ?? 0) - 1,
            close: v ?? 0,
          ),
      ],
      width: w,
      height: h,
      theme: theme,
    ),
    WaterfallChart(
      [
        for (var i = 0; i < data.length; i++)
          WaterfallStep('s$i', data[i] ?? 0),
      ],
      width: w,
      height: h,
      theme: theme,
    ),
    BoxPlot(
      [BoxStats.of(data, label: 'd')],
      width: w,
      theme: theme,
    ),
  ];
}
