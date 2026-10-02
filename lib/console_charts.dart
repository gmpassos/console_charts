/// Charts for the console and terminal, rendered as plain text.
///
/// Sparklines, line and bar charts, gauges, heatmaps, box plots and composed
/// dashboards. Every chart is a value object that renders to a `String` or a
/// `List<String>` — nothing is printed, nothing is measured against a live
/// terminal, and nothing imports `dart:io`, so the same chart works in a CLI, in a
/// log pipeline, in an isolate with no terminal attached, and on the web.
///
/// ```dart
/// import 'package:console_charts/console_charts.dart';
///
/// void main() {
///   print(sparkline([1, 3, 2, 5, 8, 6, 9]));
///
///   print(LineChart.of([20, 40, 60, 80, 100, 95, 70], width: 40, height: 10));
///
///   print(BarChart.of(
///     [82, 64, 43],
///     labels: ['Alpha', 'Beta', 'Gamma'],
///     width: 34,
///   ));
/// }
/// ```
///
/// ## Width is always explicit
///
/// No chart detects the terminal's size, because that needs `dart:io` and is
/// unavailable or misleading in several of the places charts are most useful. Pass
/// a width; on the Dart VM `stdout.terminalColumns` is the value you want, guarded,
/// since it throws when output is not a terminal.
///
/// ## Colour is opt-in
///
/// Rendering is plain text unless the theme says otherwise — use
/// [ChartTheme.colorful], or `copyWith(color: true)`. Only SGR colour sequences are
/// ever emitted, never cursor movement, so charts coexist with terminal UIs that
/// manage the screen themselves.
///
/// ## Extending
///
/// The pieces charts are built from are exported too. [renderPlotFrame] gives you
/// axes and a [Plot] to draw data into; [renderRowFrame] gives you aligned labelled
/// rows. A new chart type is usually a few lines of "paint the body" over one of
/// them, with no layout code of its own.
library;

export 'src/canvas.dart' show Canvas;
export 'src/charset.dart' show CharSet, CharSets, levelGlyph, partialGlyph;
export 'src/charts/bar_chart.dart' show BarChart, BarMode;
export 'src/charts/box_plot.dart' show BoxPlot;
export 'src/charts/candlestick_chart.dart' show Candle, CandlestickChart;
export 'src/charts/column_chart.dart'
    show BlockChart, ColumnChart, ColumnFill, Histogram;
export 'src/charts/gauge.dart'
    show BulletChart, Gauge, GaugeRow, ProgressBar, drawGauge;
export 'src/charts/heatmap.dart'
    show CalendarHeatmap, GridData, Heatmap, drawHeatmapRow;
export 'src/charts/line_chart.dart' show AreaChart, LineChart;
export 'src/charts/scatter_chart.dart' show ScatterChart;
export 'src/charts/sparkline.dart'
    show SparklineGroup, drawSparkline, sparkline;
export 'src/charts/waterfall_chart.dart' show WaterfallChart, WaterfallStep;
export 'src/format.dart'
    show
        NumberFormat,
        formatAuto,
        formatCompact,
        formatFixed,
        formatPercent,
        formatWithUnit;
export 'src/layout.dart'
    show
        BlockLayout,
        Dashboard,
        Panel,
        RuleStyle,
        Table,
        TextBlock,
        drawRule,
        hstack,
        rule,
        vstack;
export 'src/plot.dart' show Plot, lineGlyphs;
export 'src/plot_frame.dart'
    show AxisInsets, Axes, indexScale, levelsFor, renderPlotFrame;
export 'src/renderable.dart' show Renderable;
export 'src/row_frame.dart' show drawBarEighths, renderRowFrame;
export 'src/resample.dart'
    show
        ColumnSample,
        ResampleMode,
        bucketSamples,
        interpolateToColumns,
        largestTriangleThreeBuckets,
        resample;
export 'src/scale.dart'
    show
        AxisMode,
        LinearScale,
        NiceStep,
        apportion,
        dataExtent,
        maxTicksForHeight,
        niceBounds,
        niceStep;
export 'src/series.dart' show DataPoint, Series, XYSeries;
export 'src/smooth.dart' show monotoneResample;
export 'src/stats.dart'
    show BoxStats, HistogramBin, finiteSorted, histogramBins, quantile;
export 'src/style.dart' show AnsiColor, AnsiStyle, reset, stripAnsi;
export 'src/theme.dart' show ChartTheme, NumberFormatter;
export 'src/width.dart'
    show
        DisplayWidth,
        TextAlign,
        WidthFn,
        measureWidth,
        padToWidth,
        runeWidth,
        truncateToWidth;
