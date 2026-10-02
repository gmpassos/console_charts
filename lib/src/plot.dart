/// Drawing in data space: the primitives every two-dimensional chart uses.
library;

import 'canvas.dart';
import 'charset.dart';
import 'scale.dart';
import 'series.dart';
import 'style.dart';

/// A view over a [Canvas] that converts data values to cells.
///
/// Rows run top-down in the canvas and values run bottom-up, which is a reliable
/// source of inverted charts. The conversion happens in exactly one place here —
/// [rowOfLevel] — and every primitive goes through it, so the rest of the package
/// can think in levels where level 0 is the bottom of the plot.
class Plot {
  /// Creates a plot over [canvas] using [xScale] and [yScale].
  ///
  /// The scales should already be sized to the canvas; `renderPlotFrame` does that.
  Plot(this.canvas, this.xScale, this.yScale, this.chars);

  /// The surface drawn onto.
  final Canvas canvas;

  /// Maps a data x to a column.
  final LinearScale xScale;

  /// Maps a data y to a level.
  final LinearScale yScale;

  /// The glyphs to draw with.
  final CharSet chars;

  /// Columns available.
  int get width => canvas.width;

  /// Rows available.
  int get height => canvas.height;

  /// The canvas row for [level], where level 0 is the bottom row.
  int rowOfLevel(int level) => height - 1 - level;

  /// The level of data value [y], or -1 if it cannot be plotted.
  int levelOf(num? y) => yScale.pointCell(y);

  /// The column of data value [x], or -1 if it cannot be plotted.
  int columnOf(num? x) => xScale.pointCell(x);

  /// Writes [glyph] at ([column], [level]), level 0 being the bottom.
  void putLevel(int column, int level, String glyph, {AnsiStyle? style}) {
    if (level < 0) return;
    canvas.set(column, rowOfLevel(level), glyph, style: style);
  }

  /// Writes [glyph] at the cell holding data point ([x], [y]).
  void point(num? x, num? y, String glyph, {AnsiStyle? style}) {
    final c = columnOf(x);
    final l = levelOf(y);
    if (c < 0 || l < 0) return;
    putLevel(c, l, glyph, style: style);
  }

  /// Fills column [column] from level [fromLevel] up to [toLevel], inclusive.
  void fillColumn(
    int column,
    int fromLevel,
    int toLevel, {
    required String glyph,
    AnsiStyle? style,
  }) {
    if (fromLevel < 0 || toLevel < 0) return;
    final lo = fromLevel < toLevel ? fromLevel : toLevel;
    final hi = fromLevel < toLevel ? toLevel : fromLevel;
    for (var l = lo; l <= hi; l++) {
      putLevel(column, l, glyph, style: style);
    }
  }

  /// Fills column [column] upward to represent the quantity [value].
  ///
  /// Uses [CharSet.verticalRamp] for the partial cell at the top, so a bar lands
  /// within an eighth of a row. [baseline] is the data value the bar grows from,
  /// normally zero.
  ///
  /// A value *below* the baseline fills downward in **whole cells only**: Unicode
  /// has a lower-eighths ramp but no upper-eighths one, so there is no glyph for a
  /// cell that is partly filled from the top. Documented rather than faked, since
  /// the alternative is a bar whose length misstates its value.
  void fillQuantity(
    int column,
    num? value, {
    num baseline = 0,
    AnsiStyle? style,
  }) {
    final v = value?.toDouble();
    if (v == null || !v.isFinite) return;
    final base = baseline.toDouble();

    final baseEighths = _eighthsFromBottom(base);
    final valueEighths = _eighthsFromBottom(v);
    if (baseEighths < 0 || valueEighths < 0) return;

    if (valueEighths >= baseEighths) {
      final from = baseEighths ~/ 8;
      final whole = valueEighths ~/ 8;
      final remainder = valueEighths % 8;
      for (var l = from; l < whole; l++) {
        putLevel(column, l, chars.full, style: style);
      }
      if (remainder > 0) {
        final tip = partialGlyph(chars.verticalRamp, remainder / 8);
        if (tip != null) putLevel(column, whole, tip, style: style);
      } else if (whole == from && valueEighths > 0) {
        // A value smaller than one cell still deserves a mark, or a small-but-real
        // measurement renders as nothing at all.
        putLevel(column, from, chars.verticalRamp.first, style: style);
      }
    } else {
      // Downward, whole cells only — see the note above.
      final from = valueEighths ~/ 8;
      final to = baseEighths ~/ 8;
      for (var l = from; l < to; l++) {
        putLevel(column, l, chars.full, style: style);
      }
    }
  }

  int _eighthsFromBottom(double v) => yScale.quantityEighths(v);

  /// Connects [levels] into a continuous line across the plot.
  ///
  /// [levels] holds one level per column, or -1 for a gap. See [lineGlyphs] for
  /// how the turning glyphs are chosen.
  ///
  /// A gap **breaks** the line: the column before it is terminated with a
  /// horizontal run rather than being joined across. Bridging the gap would draw a
  /// line through data that does not exist.
  void polyline(List<int> levels, {AnsiStyle? style, String? glyph}) {
    final n = levels.length;
    if (n == 0) return;

    if (n == 1) {
      if (levels[0] >= 0) {
        putLevel(0, levels[0], glyph ?? chars.horizontal, style: style);
      }
      return;
    }

    for (var x = 0; x < n - 1; x++) {
      final a = levels[x];
      final b = levels[x + 1];
      if (a < 0) continue;
      if (b < 0) {
        // Terminate cleanly instead of leaving a turning glyph pointing at nothing.
        _merge(x, a, glyph ?? chars.horizontal, style);
        continue;
      }
      for (final (level, g) in lineGlyphs(a, b, chars, override: glyph)) {
        _merge(x, level, g, style);
      }
    }

    // The final column. Without this every line chart ends one column short of its
    // own plot area, which reads as a notch of dead space on the right.
    final last = levels[n - 1];
    if (last >= 0 && levels[n - 2] >= 0) {
      _merge(n - 1, last, glyph ?? chars.horizontal, style);
    }
  }

  /// Writes [glyph], turning a crossing of two runs into a cross glyph.
  ///
  /// With several series on one plot, a later line meeting an earlier one at right
  /// angles reads better as `┼` than as whichever happened to be drawn second.
  /// Anything else keeps what is already there, so series 0 stays legible.
  void _merge(int column, int level, String glyph, AnsiStyle? style) {
    if (level < 0) return;
    final existing = canvas.glyphAt(column, rowOfLevel(level));
    if (existing == chars.blank || existing == Canvas.continuation) {
      putLevel(column, level, glyph, style: style);
      return;
    }
    final crossing =
        (existing == chars.horizontal && glyph == chars.vertical) ||
        (existing == chars.vertical && glyph == chars.horizontal);
    if (crossing) putLevel(column, level, chars.cross, style: style);
  }

  /// Marks the baseline row, if the domain contains [value].
  void drawBaseline(num value, {AnsiStyle? style}) {
    final level = levelOf(value);
    if (level < 0) return;
    for (var x = 0; x < width; x++) {
      _merge(x, level, chars.horizontal, style);
    }
  }

  /// Draws [series] as points only, with no connecting line.
  void scatter(XYSeries series, {required String glyph, AnsiStyle? style}) {
    for (final p in series.points) {
      point(p.x, p.y, glyph, style: style);
    }
  }
}

/// The glyphs connecting a line that moves from level [a] to level [b].
///
/// Returns `(level, glyph)` pairs, all within one column — the column that *owns*
/// the transition from its own point to the next.
///
/// The three cases:
///
/// * Flat: one horizontal run at [a].
/// * Rising: a glyph at [a] that turns the stroke upward, one at [b] that hands it
///   rightward, and a vertical run between them.
/// * Falling: the mirror.
///
/// Why those glyphs and not others: `╯` joins *up* and *left*, so it receives the
/// horizontal stroke arriving from the previous column and turns it upward. `╭`
/// joins *down* and *right*, so it terminates the vertical run and hands the stroke
/// on to the next column. Every stroke end therefore has a matching partner, which
/// is the whole of what makes a line look continuous instead of dotted.
///
/// [override] replaces every glyph, for drawing a line in a single character.
List<(int, String)> lineGlyphs(
  int a,
  int b,
  CharSet chars, {
  String? override,
}) {
  if (a < 0 || b < 0) return const [];
  if (override != null) {
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    return [for (var l = lo; l <= hi; l++) (l, override)];
  }
  if (a == b) return [(a, chars.horizontal)];

  final rising = b > a;
  final lo = a < b ? a : b;
  final hi = a < b ? b : a;
  return [
    (a, rising ? chars.cornerUpLeft : chars.cornerDownLeft),
    (b, rising ? chars.cornerDownRight : chars.cornerUpRight),
    for (var l = lo + 1; l < hi; l++) (l, chars.vertical),
  ];
}
