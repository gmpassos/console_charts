/// Annotations drawn across a plot: thresholds and event markers.
///
/// A curve answers "what happened"; an annotation answers "compared with what". A
/// target loss, the previous run's result, the step at which the model grew a layer —
/// each is context the series cannot carry itself, and without it a reader has to
/// hold the comparison in their head while looking at the chart.
library;

import 'plot.dart';
import 'style.dart';
import 'theme.dart';

/// A horizontal line across a plot at a fixed data value.
///
/// ```text
/// 100 ┤      ╭───╮
///  80 ┤   ╭──╯   ╰──╮
///  60 ┤╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ target
///  40 ┤╭─╯
/// ```
class ReferenceLine {
  /// Creates a reference at [value].
  const ReferenceLine(
    this.value, {
    this.label,
    this.glyph,
    this.style,
    this.labelAtEnd = true,
  });

  /// Where on the y axis the line sits.
  final double value;

  /// An optional caption, drawn in the plot beside the line.
  final String? label;

  /// The character the line is drawn with.
  ///
  /// Defaults to the charset's dotted horizontal, so a reference reads as annotation
  /// rather than as another series — which matters because it shares a plot with
  /// lines drawn from real data.
  final String? glyph;

  /// The style the line and its label take. Defaults to the theme's axis style.
  final AnsiStyle? style;

  /// Whether the label sits at the right end of the line rather than the left.
  final bool labelAtEnd;

  /// Draws this reference into [plot].
  void draw(Plot plot, ChartTheme theme) {
    final level = plot.levelOf(value);
    if (level < 0) return;
    final mark = glyph ?? theme.charset.dottedHorizontal;
    final effective = style ?? (theme.color ? theme.axisStyle : null);

    final text = label;
    // The label is written first and the line stops short of it, rather than the line
    // being drawn through and overwritten: a dotted rule running into the middle of a
    // word reads as corruption.
    var lineWidth = plot.width;
    var labelAt = -1;
    if (text != null && text.isNotEmpty && text.length + 2 < plot.width) {
      if (labelAtEnd) {
        labelAt = plot.width - text.length;
        lineWidth = labelAt - 1;
      } else {
        labelAt = 0;
        lineWidth = plot.width;
      }
    }

    final from = labelAt == 0 ? (text!.length + 1) : 0;
    for (var x = from; x < lineWidth; x++) {
      plot.putLevel(x, level, mark, style: effective);
    }
    if (labelAt >= 0) {
      for (var i = 0; i < text!.length; i++) {
        plot.putLevel(labelAt + i, level, text[i], style: effective);
      }
    }
  }
}

/// A vertical line at a column index, for marking when something happened.
///
/// ```text
/// 100 ┤      ╷╭───╮
///  80 ┤   ╭──┼╯   ╰──╮
///  60 ┤╭──╯  ╵
///       grew ┘
/// ```
///
/// The index is in *data* space — the position in the series — not a column, so a
/// marker stays attached to its event when the chart is resampled to a different
/// width.
class EventMarker {
  /// Creates a marker at data index [index].
  const EventMarker(this.index, {this.label, this.glyph, this.style});

  /// The position in the series this marker belongs to.
  final int index;

  /// An optional short caption, drawn at the top of the line.
  final String? label;

  /// The character the line is drawn with. Defaults to the charset's vertical.
  final String? glyph;

  /// The style the line takes. Defaults to the theme's axis style.
  final AnsiStyle? style;

  /// Draws this marker into [plot], given how many data points the series holds.
  ///
  /// [pointCount] is needed because the marker's index is in data space: the plot may
  /// be narrower or wider than the series, and a marker that ignored that would drift
  /// away from the event it marks.
  void draw(Plot plot, ChartTheme theme, int pointCount) {
    if (pointCount <= 0 || index < 0 || index >= pointCount) return;
    final column = pointCount == 1
        ? 0
        : (index * (plot.width - 1) / (pointCount - 1)).round();
    final mark = glyph ?? theme.charset.vertical;
    final effective = style ?? (theme.color ? theme.axisStyle : null);

    for (var level = 0; level < plot.height; level++) {
      // Only into empty cells, so a marker never erases the series it annotates.
      if (plot.canvas.glyphAt(column, plot.rowOfLevel(level)) ==
          theme.charset.blank) {
        plot.putLevel(column, level, mark, style: effective);
      }
    }

    final text = label;
    if (text == null || text.isEmpty) return;
    // Left of the line when there is room, right otherwise, so a marker near the
    // right edge still gets its caption.
    final start = column - text.length >= 0 ? column - text.length : column + 1;
    for (var i = 0; i < text.length; i++) {
      final x = start + i;
      if (x < 0 || x >= plot.width) continue;
      plot.putLevel(x, plot.height - 1, text[i], style: effective);
    }
  }
}
