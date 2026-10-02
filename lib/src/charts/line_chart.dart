/// Line and area charts.
library;

import '../braille.dart';
import '../plot.dart';
import '../plot_frame.dart';
import '../reference.dart';
import '../renderable.dart';
import '../resample.dart';
import '../scale.dart';
import '../series.dart';
import '../smooth.dart';
import '../style.dart';
import '../theme.dart';
import '../width.dart';

/// How a line chart draws its line.
enum LineStyle {
  /// Box-drawing characters: `─ │ ╭ ╮ ╰ ╯`. The default.
  ///
  /// One glyph per cell, so the vertical resolution is the chart's height in rows.
  /// Legible everywhere, and easy to read a value off a row.
  glyph,

  /// Braille patterns, at 2× the horizontal and 4× the vertical resolution.
  ///
  /// Better for *shape* — a shallow trend or a small wobble that a glyph chart
  /// quantizes away — and worse for reading a value off a row. Opt-in because font
  /// coverage for U+2800–U+28FF, while good, is not universal, and a terminal without
  /// it shows replacement boxes, which is worse than a coarse but legible staircase.
  braille,
}

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
    this.logY = false,
    this.references = const [],
    this.markers = const [],
    this.xCaption,
    this.lineStyle = LineStyle.glyph,
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
    bool logY = false,
    List<ReferenceLine> references = const [],
    List<EventMarker> markers = const [],
    (String, String)? xCaption,
    LineStyle lineStyle = LineStyle.glyph,
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
         logY: logY,
         references: references,
         markers: markers,
         xCaption: xCaption,
         lineStyle: lineStyle,
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
  /// spline would add — see [monotoneResample].
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

  /// Whether to position values by their logarithm.
  ///
  /// For a series that decays or grows by *factors* — a training loss, a latency
  /// distribution. On a linear axis a series falling 2.4 → 0.05 spends most of its
  /// length squashed into the bottom row, so a plateau in the tail is invisible; on
  /// a log axis a constant decay rate is a straight line and a plateau is a bend.
  ///
  /// Values at or below zero cannot be placed and render as gaps — see
  /// [LinearScale.fitLog]. Ignored when [fill] is set, because a filled area is read
  /// as a quantity from a zero baseline and zero is not on a log axis.
  final bool logY;

  /// Horizontal lines drawn across the plot at fixed values.
  ///
  /// A target, a previous run's result, a service level. Drawn under the series, so
  /// data always wins a shared cell.
  final List<ReferenceLine> references;

  /// Vertical lines marking when something happened, by data index.
  ///
  /// The index is in data space rather than columns, so a marker stays attached to
  /// its event however the chart is resampled. Drawn only into empty cells, so a
  /// marker never erases the series it annotates.
  final List<EventMarker> markers;

  /// A caption for the two ends of the x axis, in place of spread tick labels.
  ///
  /// For an axis whose x is a sample index, only the ends are meaningful:
  /// intermediate ticks would imply the samples are evenly spaced in time, which for
  /// a training run or a log tail they are not. Pass `('step 0', 'step 2000')`.
  ///
  /// Ignored when [xLabels] is given, since that is the spread-label form.
  final (String, String)? xCaption;

  /// How the line itself is drawn. See [LineStyle].
  ///
  /// Named `lineStyle` rather than `style` because the series each carry an
  /// [AnsiStyle] of that name, and one word meaning two things inside the same draw
  /// loop is how a shadowed variable turns into a silent bug.
  final LineStyle lineStyle;

  @override
  List<String> renderLines() {
    if (series.isEmpty) return const [];
    final w = width ?? theme.defaultWidth;
    final h = height ?? theme.defaultHeight;

    // The domain comes from every series, so they share one scale and can be read
    // against each other. Rounded outward when there are axis labels, because a
    // label must sit exactly on the row it names.
    // A filled area is read as a quantity measured from zero, and zero is not a
    // point on a logarithmic axis — so the two are mutually exclusive and fill wins,
    // since it is the more visible of the two.
    final useLog = logY && !fill;
    final values = [
      ...series.expand((s) => s.values),
      ...references.map((r) => r.value),
    ];
    final yScale = useLog
        ? LinearScale.fitLog(values, h, min: yMin, max: yMax)
        : LinearScale.fit(
            values,
            h,
            mode: axes.showYLabels ? AxisMode.nice : AxisMode.tight,
            min: yMin,
            max: yMax,
            // Area fills read as quantities, so their baseline belongs at zero.
            includeZero: fill,
          );

    final longest = series.fold(0, (m, s) => s.length > m ? s.length : m);

    final lines = renderPlotFrame(
      width: w,
      height: h,
      theme: theme,
      axes: axes,
      title: title,
      xLabels: xLabels,
      yScale: yScale,
      xScale: (plotWidth) => LinearScale.index(plotWidth, plotWidth),
      draw: (plot) {
        // References first, so a series drawn over one keeps the cell. A reference is
        // context; the data is the point.
        for (final reference in references) {
          reference.draw(plot, theme);
        }
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
          if (lineStyle == LineStyle.braille) {
            _drawBraille(plot, columns, style);
          } else {
            plot.polyline(levels, style: style, glyph: s.glyph);
          }
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
        // Last, so a marker can see which cells the series left empty.
        for (final marker in markers) {
          marker.draw(plot, theme, longest);
        }
      },
    );

    final caption = xCaption;
    if (caption == null || xLabels != null || lines.isEmpty) return lines;
    return [...lines, _captionLine(caption, w, lines)];
  }

  /// Draws one series as Braille dots, at 2× the horizontal and 4× the vertical
  /// resolution of the cell grid.
  ///
  /// Resampled again, to dot columns rather than cell columns, because the extra
  /// horizontal resolution is only real if the data is sampled at it — drawing twice
  /// as many dots from the same cell-resolution samples would widen the staircase
  /// rather than remove it.
  void _drawBraille(Plot plot, List<double?> columns, AnsiStyle? style) {
    final surface = BrailleCanvas(plot.width, plot.height);
    final dotColumns = resample(columns, surface.dotWidth, mode: mode);

    int? dotY(double? value) {
      final t = plot.yScale.normalize(value);
      if (t == null) return null;
      // Inverted because dot y grows downward while a value grows upward, and
      // scaled by dotHeight - 1 so the domain's top reaches the topmost dot.
      return ((1 - t) * (surface.dotHeight - 1)).round();
    }

    int? previous;
    for (var x = 0; x < dotColumns.length; x++) {
      final y = dotY(dotColumns[x]);
      if (y == null) {
        // A gap breaks the line here as everywhere else: the next real sample starts
        // a new run rather than being joined across the hole.
        previous = null;
        continue;
      }
      if (previous != null) {
        surface.line(x - 1, previous, x, y);
      } else {
        surface.set(x, y);
      }
      previous = y;
    }
    surface.blitTo(plot.canvas, style: style);
  }

  /// A line captioning the two ends of the x axis.
  ///
  /// Indented to line up under the plot area rather than the y gutter. The gutter is
  /// read back from the rendered axis row — the frame already decided how wide it is,
  /// and deriving it a second time is how the two drift apart.
  ///
  /// **The row is stripped of escape sequences before it is scanned.** With colour on,
  /// the axis row begins with an SGR sequence, and counting its characters as gutter
  /// made the caption land in a different column than it did in the plain render —
  /// which is the exact failure this package's cell-grid design exists to prevent,
  /// and which a colour-equivalence test caught.
  String _captionLine(
    (String, String) caption,
    int totalWidth,
    List<String> lines,
  ) {
    final axisRow = stripAnsi(lines.last);
    var gutter = 0;
    while (gutter < axisRow.length &&
        axisRow[gutter] != theme.charset.axisOrigin &&
        axisRow[gutter] != theme.charset.horizontal) {
      gutter++;
    }
    if (gutter >= axisRow.length) gutter = 0;

    final room = totalWidth - gutter;
    final measure = theme.width;
    var left = caption.$1;
    var right = caption.$2;

    // Both captions truncated to fit, left first, rather than letting either run past
    // the requested width — a caller that asked for n columns budgeted n columns.
    if (measure(left) + measure(right) + 1 > room) {
      right = truncateToWidth(right, room ~/ 2, ellipsis: '…', width: measure);
      left = truncateToWidth(
        left,
        room - measure(right) - 1,
        ellipsis: '…',
        width: measure,
      );
    }
    final gap = room - measure(left) - measure(right);
    if (gap < 1) {
      return '${' ' * gutter}$left';
    }
    return '${' ' * gutter}$left${' ' * gap}$right';
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
