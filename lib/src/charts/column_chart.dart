/// Vertical bar charts, histograms and block charts.
library;

import '../plot.dart';
import '../plot_frame.dart';
import '../renderable.dart';
import '../scale.dart';
import '../series.dart';
import '../stats.dart';
import '../theme.dart';

/// A vertical bar chart.
///
/// ```text
///  100 ┤       █
///   80 ┤       █       █
///   60 ┤   █   █       █
///   40 ┤   █   █   █   █
///   20 ┤   █   █   █   █   █
///    0 ┼────────────────────────
///        A   B   C   D   E
/// ```
///
/// Unlike [BarChart], this one has a baseline **row**, so it can draw negative
/// values hanging below it — which is why negative data belongs here.
class ColumnChart implements Renderable {
  /// Creates a column chart over [series].
  const ColumnChart(
    this.series, {
    this.labels = const [],
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.stacked = false,
    this.title,
    this.yMin,
    this.yMax,
    this.axes = const Axes(),
    this.barWidth,
    this.gap = 1,
  });

  /// Convenience for a single unnamed series.
  ColumnChart.of(
    List<num?> values, {
    List<String> labels = const [],
    int? width,
    int? height,
    ChartTheme theme = ChartTheme.plain,
    String? title,
    num? yMin,
    num? yMax,
    Axes axes = const Axes(),
    int? barWidth,
    int gap = 1,
  }) : this(
         [Series(values)],
         labels: labels,
         width: width,
         height: height,
         theme: theme,
         title: title,
         yMin: yMin,
         yMax: yMax,
         axes: axes,
         barWidth: barWidth,
         gap: gap,
       );

  /// The data.
  final List<Series> series;

  /// Category names, placed under the columns.
  final List<String> labels;

  /// Total width. Defaults to the theme's.
  final int? width;

  /// Total height. Defaults to the theme's.
  final int? height;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// Whether to stack several series into one column per category.
  final bool stacked;

  /// A heading above the chart.
  final String? title;

  /// Pins the bottom of the y domain.
  final num? yMin;

  /// Pins the top of the y domain.
  final num? yMax;

  /// Axis decoration.
  final Axes axes;

  /// How many columns wide each bar is. Null fits them to the space.
  final int? barWidth;

  /// Blank columns between bars.
  final int gap;

  @override
  List<String> renderLines() {
    if (series.isEmpty) return const [];
    final w = width ?? theme.defaultWidth;
    final h = height ?? theme.defaultHeight;
    final categories = series.fold(0, (m, s) => s.length > m ? s.length : m);
    if (categories == 0) return const [];

    // A column chart's baseline is zero, always: a bar's meaning is its length from
    // the origin, so a domain that excluded zero would misstate every bar.
    final yScale = LinearScale.fit(
      stacked ? _stackTotals(categories) : series.expand((s) => s.values),
      h,
      includeZero: true,
      mode: axes.showYLabels ? AxisMode.nice : AxisMode.tight,
      min: yMin,
      max: yMax,
    );

    return renderPlotFrame(
      width: w,
      height: h,
      theme: theme,
      axes: axes,
      title: title,
      xLabels: labels.isEmpty ? null : labels,
      yScale: yScale,
      xScale: (plotWidth) => LinearScale.index(categories, plotWidth),
      draw: (plot) {
        final slot = (plot.width / categories).floor().clamp(1, plot.width);
        final bars = barWidth ?? (slot - gap).clamp(1, slot);

        for (var c = 0; c < categories; c++) {
          final left = ((c * plot.width) / categories).round();
          if (stacked) {
            _drawStack(plot, c, left, bars);
          } else {
            // Side by side within the slot when there are several series.
            final each = (bars / series.length).floor().clamp(1, bars);
            for (var s = 0; s < series.length; s++) {
              final value = c < series[s].length ? series[s].values[c] : null;
              final style = theme.color
                  ? series[s].style ?? theme.seriesStyle(s)
                  : null;
              for (var dx = 0; dx < each; dx++) {
                plot.fillQuantity(left + s * each + dx, value, style: style);
              }
            }
          }
        }
        plot.drawBaseline(0, style: theme.color ? theme.axisStyle : null);
      },
    );
  }

  List<num?> _stackTotals(int categories) => [
    for (var c = 0; c < categories; c++)
      () {
        var sum = 0.0;
        for (final s in series) {
          final v = c < s.length ? s.values[c] : null;
          if (v == null) continue;
          final d = v.toDouble();
          if (d.isFinite) sum += d;
        }
        return sum;
      }(),
  ];

  /// Draws one stacked column, each series starting where the last ended.
  void _drawStack(Plot plot, int category, int left, int bars) {
    var base = 0.0;
    for (var s = 0; s < series.length; s++) {
      final raw = category < series[s].length
          ? series[s].values[category]
          : null;
      if (raw == null) continue;
      final v = raw.toDouble();
      if (!v.isFinite) continue;
      final style = theme.color
          ? series[s].style ?? theme.seriesStyle(s)
          : null;
      for (var dx = 0; dx < bars; dx++) {
        plot.fillQuantity(left + dx, base + v, baseline: base, style: style);
      }
      base += v;
    }
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A histogram: the distribution of a set of samples.
///
/// Bins the data and delegates to [ColumnChart], because a histogram is a data
/// transform rather than a different way of drawing. See [histogramBins] for the
/// binning rules, including the closed last bin.
class Histogram implements Renderable {
  /// Creates a histogram of [values].
  const Histogram(
    this.values, {
    this.binCount,
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.title,
    this.showBinLabels = true,
    this.axes = const Axes(),
  });

  /// The samples to bin.
  final List<num?> values;

  /// How many bins. Null chooses automatically — see [histogramBins].
  final int? binCount;

  /// Total width.
  final int? width;

  /// Total height.
  final int? height;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// A heading above the chart.
  final String? title;

  /// Whether to label the bins with their lower bounds.
  final bool showBinLabels;

  /// Axis decoration.
  final Axes axes;

  /// The bins this histogram draws.
  List<HistogramBin> get bins => histogramBins(values, binCount: binCount);

  @override
  List<String> renderLines() {
    final b = bins;
    if (b.isEmpty) return const [];
    return ColumnChart.of(
      [for (final bin in b) bin.count],
      labels: showBinLabels
          ? [for (final bin in b) theme.format(bin.start)]
          : const [],
      width: width,
      height: height,
      theme: theme,
      title: title,
      axes: axes,
      gap: 0,
    ).renderLines();
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A filled block chart — a staircase of solid area, with no axes.
///
/// ```text
///   █
///   ██
///   ███
///  █████
/// ███████
/// ```
///
/// The simplest possible shape chart: no axis, no labels, just relative magnitude.
/// Useful where a sparkline is too small and a line chart is too much.
class BlockChart implements Renderable {
  /// Creates a block chart over [values].
  const BlockChart(
    this.values, {
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.fromLeft = false,
  });

  /// The values, one column each unless [width] forces resampling.
  final List<num?> values;

  /// Columns to draw in. Defaults to one per value.
  final int? width;

  /// Rows to draw in. Defaults to the theme's.
  final int? height;

  /// Glyphs and colours.
  final ChartTheme theme;

  /// Whether rows grow from the left as a horizontal staircase instead.
  final bool fromLeft;

  @override
  List<String> renderLines() {
    if (values.isEmpty) return const [];
    final h = height ?? theme.defaultHeight;
    final w = width ?? values.length;
    if (fromLeft) {
      // One row per value, each a run of blocks — a horizontal staircase.
      final scale = LinearScale.fit(
        values,
        w,
        includeZero: true,
        mode: AxisMode.tight,
      );
      return [
        for (final v in values)
          theme.charset.full *
              ((scale.quantityEighths(v).clamp(0, w * 8)) ~/ 8),
      ];
    }
    return ColumnFill(values, width: w, height: h, theme: theme).renderLines();
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A bare column fill with no axes, used by [BlockChart].
///
/// Exposed because it is the smallest useful two-dimensional chart and composes
/// neatly inside a panel.
class ColumnFill implements Renderable {
  /// Creates a bare column fill.
  const ColumnFill(
    this.values, {
    required this.width,
    required this.height,
    this.theme = ChartTheme.plain,
  });

  /// The values.
  final List<num?> values;

  /// Columns.
  final int width;

  /// Rows.
  final int height;

  /// Glyphs and colours.
  final ChartTheme theme;

  @override
  List<String> renderLines() => renderPlotFrame(
    width: width,
    height: height,
    theme: theme,
    axes: Axes.none,
    yScale: LinearScale.fit(
      values,
      height,
      includeZero: true,
      mode: AxisMode.tight,
    ),
    xScale: (plotWidth) => LinearScale.index(values.length, plotWidth),
    draw: (plot) {
      for (var x = 0; x < plot.width; x++) {
        final index = values.length == 1
            ? 0
            : (x * (values.length - 1) / (plot.width - 1).clamp(1, plot.width))
                  .round()
                  .clamp(0, values.length - 1);
        plot.fillQuantity(
          x,
          values[index],
          style: theme.color ? theme.seriesStyle(0) : null,
        );
      }
    },
  );

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}
