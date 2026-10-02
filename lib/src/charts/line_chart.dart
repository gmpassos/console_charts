/// Line and area charts.
library;

import '../plot_frame.dart';
import '../renderable.dart';
import '../resample.dart';
import '../scale.dart';
import '../series.dart';
import '../smooth.dart';
import '../theme.dart';

/// A line chart, with one or more series.
///
/// ```text
/// 100 ┤                 ╭──╮
///  80 ┤            ╭────╯  ╰╮
///  60 ┤       ╭────╯        ╰──╮
///  40 ┤   ╭───╯                 ╰─
///  20 ┤───╯
///   0 ┼──────────────────────────────
///      Jan Feb Mar Apr May Jun Jul
/// ```
///
/// A `null` in a series breaks the line rather than being bridged — see [Series].
class LineChart implements Renderable {
  /// Creates a line chart over [series].
  const LineChart(
    this.series, {
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.smooth = false,
    this.fill = false,
    this.showMarkers = false,
    this.xLabels,
    this.title,
    this.yMin,
    this.yMax,
    this.axes = const Axes(),
    this.mode = ResampleMode.mean,
  });

  /// Convenience for a single unnamed series.
  LineChart.of(
    List<num?> values, {
    int? width,
    int? height,
    ChartTheme theme = ChartTheme.plain,
    bool smooth = false,
    bool fill = false,
    bool showMarkers = false,
    List<String>? xLabels,
    String? title,
    num? yMin,
    num? yMax,
    Axes axes = const Axes(),
    ResampleMode mode = ResampleMode.mean,
  }) : this(
         [Series(values)],
         width: width,
         height: height,
         theme: theme,
         smooth: smooth,
         fill: fill,
         showMarkers: showMarkers,
         xLabels: xLabels,
         title: title,
         yMin: yMin,
         yMax: yMax,
         axes: axes,
         mode: mode,
       );

  /// The series to draw. Each gets its own colour from the theme's palette.
  final List<Series> series;

  /// Total width including axis labels. Defaults to the theme's.
  final int? width;

  /// Total height including the x axis. Defaults to the theme's.
  final int? height;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// Whether to interpolate the series through a monotone cubic before drawing.
  ///
  /// Smooths the staircase a coarse grid produces, without the overshoot a natural
  /// spline would add — see [monotoneCubic].
  final bool smooth;

  /// Whether to fill the area between the line and the baseline.
  ///
  /// This is what makes an area chart; it is a flag rather than a class because the
  /// only difference is the fill.
  final bool fill;

  /// Whether to mark each data point as well as connecting them.
  final bool showMarkers;

  /// Labels for the x axis, spread across the plot and thinned if they collide.
  final List<String>? xLabels;

  /// A heading above the chart.
  final String? title;

  /// Pins the bottom of the y domain.
  final num? yMin;

  /// Pins the top of the y domain.
  final num? yMax;

  /// Axis decoration. Use [Axes.none] for a bare plot.
  final Axes axes;

  /// How several points falling in one column are reduced.
  final ResampleMode mode;

  @override
  List<String> renderLines() {
    if (series.isEmpty) return const [];
    final w = width ?? theme.defaultWidth;
    final h = height ?? theme.defaultHeight;

    // The domain comes from every series, so they share one scale and can be read
    // against each other. Rounded outward when there are axis labels, because a
    // label must sit exactly on the row it names.
    final yScale = LinearScale.fit(
      series.expand((s) => s.values),
      h,
      mode: axes.showYLabels ? AxisMode.nice : AxisMode.tight,
      min: yMin,
      max: yMax,
      // Area fills read as quantities, so their baseline belongs at zero.
      includeZero: fill,
    );

    return renderPlotFrame(
      width: w,
      height: h,
      theme: theme,
      axes: axes,
      title: title,
      xLabels: xLabels,
      yScale: yScale,
      xScale: (plotWidth) => LinearScale.index(plotWidth, plotWidth),
      draw: (plot) {
        for (var i = 0; i < series.length; i++) {
          final s = series[i];
          if (s.isEmpty) continue;
          final style = theme.color ? s.style ?? theme.seriesStyle(i) : null;

          final columns = smooth
              ? monotoneResample(s.values, plot.width)
              : resample(s.values, plot.width, mode: mode);
          final levels = levelsFor(columns, plot.yScale);

          if (fill) {
            // Filled to one level BELOW the line, so the line itself stays visible
            // on top. Filling up to the line instead would let the fill's own top
            // edge stand in for it, and the result reads as a ragged block rather
            // than as a curve over shaded area.
            final baseLevel = plot.yScale.pointCell(
              plot.yScale.spansZero ? 0 : plot.yScale.min,
            );
            for (var x = 0; x < levels.length; x++) {
              if (levels[x] <= baseLevel) continue;
              plot.fillColumn(
                x,
                baseLevel,
                levels[x] - 1,
                glyph: theme.charset.full,
                style: style,
              );
            }
          }
          plot.polyline(levels, style: style, glyph: s.glyph);
          if (showMarkers) {
            for (var x = 0; x < levels.length; x++) {
              if (levels[x] < 0) continue;
              plot.putLevel(
                x,
                levels[x],
                s.glyph ?? theme.charset.point,
                style: style,
              );
            }
          }
        }
      },
    );
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// An area chart: a line with the space beneath it filled.
///
/// A [LineChart] with `fill: true`, named separately for discoverability.
class AreaChart implements Renderable {
  /// Creates an area chart over [series].
  const AreaChart(
    this.series, {
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.smooth = false,
    this.xLabels,
    this.title,
    this.yMin,
    this.yMax,
    this.axes = const Axes(),
  });

  /// The series to draw.
  final List<Series> series;

  /// Total width including axis labels.
  final int? width;

  /// Total height including the x axis.
  final int? height;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// Whether to interpolate through a monotone cubic first.
  final bool smooth;

  /// Labels for the x axis.
  final List<String>? xLabels;

  /// A heading above the chart.
  final String? title;

  /// Pins the bottom of the y domain.
  final num? yMin;

  /// Pins the top of the y domain.
  final num? yMax;

  /// Axis decoration.
  final Axes axes;

  @override
  List<String> renderLines() => LineChart(
    series,
    width: width,
    height: height,
    theme: theme,
    smooth: smooth,
    fill: true,
    xLabels: xLabels,
    title: title,
    yMin: yMin,
    yMax: yMax,
    axes: axes,
  ).renderLines();

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}
