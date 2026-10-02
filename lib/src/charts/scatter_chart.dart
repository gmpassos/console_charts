/// Scatter plots.
library;

import '../plot_frame.dart';
import '../renderable.dart';
import '../scale.dart';
import '../series.dart';
import '../theme.dart';

/// A scatter plot of independent x and y values.
///
/// ```text
/// 100 ┤                    •
///  80 ┤              •
///  60 ┤         •       •
///  40 ┤    •  •
///  20 ┤ •
///   0 ┼──────────────────────────
///     0   20  40  60  80  100
/// ```
///
/// Points are **never resampled**: each is placed in whatever cell it falls in, and
/// several landing in one cell simply overlap. Averaging them would fabricate a
/// measurement that was never taken, which is acceptable for a line through
/// continuous data and not for a cloud of observations.
class ScatterChart implements Renderable {
  /// Creates a scatter plot over [series].
  const ScatterChart(
    this.series, {
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.title,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
    this.axes = const Axes(),
    this.showXLabels = true,
  });

  /// Convenience for a single series from parallel lists.
  ScatterChart.fromLists(
    List<num> xs,
    List<num> ys, {
    String? label,
    int? width,
    int? height,
    ChartTheme theme = ChartTheme.plain,
    String? title,
    Axes axes = const Axes(),
  }) : this(
         [XYSeries.fromLists(xs, ys, label: label)],
         width: width,
         height: height,
         theme: theme,
         title: title,
         axes: axes,
       );

  /// The point sets to draw. Each gets its own glyph and colour.
  final List<XYSeries> series;

  /// Total width. Defaults to the theme's.
  final int? width;

  /// Total height. Defaults to the theme's.
  final int? height;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// A heading above the chart.
  final String? title;

  /// Pins the left of the x domain.
  final num? xMin;

  /// Pins the right of the x domain.
  final num? xMax;

  /// Pins the bottom of the y domain.
  final num? yMin;

  /// Pins the top of the y domain.
  final num? yMax;

  /// Axis decoration.
  final Axes axes;

  /// Whether to label the x axis with its own tick values.
  final bool showXLabels;

  @override
  List<String> renderLines() {
    if (series.isEmpty) return const [];
    final w = width ?? theme.defaultWidth;
    final h = height ?? theme.defaultHeight;

    final allY = series.expand((s) => s.points.map((p) => p.y));
    final allX = series.expand((s) => s.points.map((p) => p.x));
    final yScale = LinearScale.fit(
      allY,
      h,
      mode: axes.showYLabels ? AxisMode.nice : AxisMode.tight,
      min: yMin,
      max: yMax,
    );
    final xDomain = LinearScale.fit(
      allX,
      1,
      mode: AxisMode.nice,
      min: xMin,
      max: xMax,
    );

    // The x axis of a scatter plot labels VALUES, not categories, so the labels come
    // from the x domain's own ticks rather than from a caller-supplied list.
    final xLabels = showXLabels
        ? [for (final t in xDomain.ticks(5)) theme.format(t)]
        : null;

    // Glyphs cycle so a second and third series stay distinguishable without colour,
    // which matters because colour is off by default.
    final glyphs = [
      theme.charset.point,
      theme.charset.pointHollow,
      theme.charset.pointSmall,
    ];

    return renderPlotFrame(
      width: w,
      height: h,
      theme: theme,
      axes: axes,
      title: title,
      xLabels: xLabels,
      yScale: yScale,
      xScale: (plotWidth) => LinearScale(xDomain.min, xDomain.max, plotWidth),
      draw: (plot) {
        for (var i = 0; i < series.length; i++) {
          final s = series[i];
          plot.scatter(
            s,
            glyph: s.glyph ?? glyphs[i % glyphs.length],
            style: theme.color ? s.style ?? theme.seriesStyle(i) : null,
          );
        }
      },
    );
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}
