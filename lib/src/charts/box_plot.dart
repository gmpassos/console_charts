/// Box-and-whisker plots.
library;

import '../canvas.dart';
import '../renderable.dart';
import '../row_frame.dart';
import '../scale.dart';
import '../stats.dart';
import '../theme.dart';

/// Horizontal box-and-whisker plots, one distribution per row.
///
/// ```text
/// latency  ├────[════╪════]────┤
/// startup  ├──[══╪══]──────┤      · ·
/// ```
///
/// A row chart rather than a plot: the layout is a label gutter plus a drawing area,
/// exactly like a bar chart, so it shares [renderRowFrame] with them and stays
/// aligned with them in a dashboard. All rows share one scale, since comparing
/// distributions is the only reason to draw several.
class BoxPlot implements Renderable {
  /// Creates a box plot of the given summaries.
  const BoxPlot(
    this.boxes, {
    this.width,
    this.theme = ChartTheme.plain,
    this.title,
    this.showOutliers = true,
    this.min,
    this.max,
    this.showScale = true,
  });

  /// Builds summaries from raw samples, one distribution per entry.
  ///
  /// [fences] controls whether whiskers stop at Tukey's 1.5×IQR limit — see
  /// [BoxStats.of].
  factory BoxPlot.of(
    Map<String, List<num?>> distributions, {
    int? width,
    ChartTheme theme = ChartTheme.plain,
    String? title,
    bool fences = true,
    bool showOutliers = true,
    bool showScale = true,
  }) => BoxPlot(
    [
      for (final e in distributions.entries)
        BoxStats.of(e.value, fences: fences, label: e.key),
    ],
    width: width,
    theme: theme,
    title: title,
    showOutliers: showOutliers,
    showScale: showScale,
  );

  /// The distributions to draw.
  final List<BoxStats> boxes;

  /// Total width including labels.
  final int? width;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// A heading above the rows.
  final String? title;

  /// Whether to mark values beyond the whiskers.
  final bool showOutliers;

  /// Pins the left of the shared scale.
  final num? min;

  /// Pins the right of the shared scale.
  final num? max;

  /// Whether to print the scale's bounds under the rows.
  final bool showScale;

  @override
  List<String> renderLines() {
    if (boxes.isEmpty) return const [];
    final total = width ?? theme.defaultWidth;
    final chars = theme.charset;

    final scale = LinearScale.fit(
      boxes.expand((b) => b.extent),
      1,
      mode: AxisMode.nice,
      min: min,
      max: max,
    );

    final lines = renderRowFrame(
      width: total,
      rowCount: boxes.length,
      theme: theme,
      title: title,
      labels: [for (final b in boxes) b.label ?? ''],
      body: (i, body) {
        final box = boxes[i];
        if (box.isEmpty) return;
        final s = scale.withSize(body.width);
        final style = theme.color ? theme.seriesStyle(i) : null;
        final axis = theme.color ? theme.axisStyle : null;

        int at(double v) => s.pointCell(v).clamp(0, body.width - 1);
        final lowCell = at(box.low);
        final q1Cell = at(box.q1);
        final medianCell = at(box.median);
        final q3Cell = at(box.q3);
        final highCell = at(box.high);

        // Drawn weakest first so stronger marks win the cell: whisker, then box,
        // then edges, then the median. At small widths several of these collide, and
        // the median is the one a reader needs most.
        for (var x = lowCell; x <= highCell; x++) {
          body.set(x, 0, chars.horizontal, style: axis);
        }
        body
          ..set(lowCell, 0, chars.teeRight, style: axis)
          ..set(highCell, 0, chars.teeLeft, style: axis);
        for (var x = q1Cell; x <= q3Cell; x++) {
          body.set(x, 0, chars.heavyHorizontal, style: style);
        }
        body
          ..set(q1Cell, 0, '[', style: style)
          ..set(q3Cell, 0, ']', style: style)
          ..set(medianCell, 0, chars.cross, style: style);

        if (showOutliers) {
          for (final o in box.outliers) {
            final cell = s.pointCell(o);
            if (cell < 0 || cell >= body.width) continue;
            // Only into a cell the box does not already use, so an outlier cannot
            // erase a quartile edge.
            if (body.glyphAt(cell, 0) == chars.blank ||
                body.glyphAt(cell, 0) == Canvas.continuation) {
              body.set(cell, 0, chars.pointSmall, style: style);
            }
          }
        }
      },
    );

    if (!showScale) return lines;
    return [...lines, _scaleLine(total, scale)];
  }

  /// A line showing the scale's extremes, so the boxes have units.
  String _scaleLine(int total, LinearScale scale) {
    final lo = theme.format(scale.min);
    final hi = theme.format(scale.max);
    final room = total - theme.width(lo) - theme.width(hi);
    if (room < 1) return '';
    return '$lo${' ' * room}$hi';
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}
