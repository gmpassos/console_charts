/// Sub-cell plotting with Braille patterns.
///
/// A character cell can hold one glyph, which caps a line chart's vertical
/// resolution at its height in rows. Braille patterns (U+2800–U+28FF) encode an
/// arbitrary subset of a 2×4 dot grid in a single character, so one cell addresses
/// eight positions instead of one — **2× the horizontal and 4× the vertical
/// resolution** for the same space.
///
/// ```text
///  glyph mode, 8 rows          braille mode, 8 rows
///  100 ┤      ╭───╮            100 ┤      ⡠⠤⠤⢄
///   75 ┤   ╭──╯   ╰──╮          75 ┤   ⡠⠔⠁      ⠑⠢⡀
///   50 ┤ ╭─╯          ╰─╮       50 ┤ ⡠⠊            ⠈⠢⡀
/// ```
///
/// ## Why it is opt-in
///
/// Font coverage for U+2800–U+28FF is good but not universal, and a terminal without
/// it shows replacement boxes — which is worse than a coarse but legible staircase.
/// It is also genuinely harder to read at a glance than box-drawing: better for
/// shape, worse for reading a value off a row.
library;

import 'canvas.dart';
import 'style.dart';

/// Dots per cell, horizontally.
const int brailleDotsX = 2;

/// Dots per cell, vertically.
const int brailleDotsY = 4;

/// The base code point of the Braille Patterns block.
const int _brailleBase = 0x2800;

/// Bit for each dot, indexed `[dy][dx]`.
///
/// The Braille encoding is not row-major: dots 1–6 were the original 6-dot cell and
/// dots 7–8 were appended underneath when it was extended to 8, so the bottom row's
/// bits are 0x40 and 0x80 rather than continuing the sequence. Hard-coding the table
/// is clearer than deriving it, and a wrong derivation produces a chart that looks
/// subtly scrambled rather than broken.
const List<List<int>> _dotBits = [
  [0x01, 0x08],
  [0x02, 0x10],
  [0x04, 0x20],
  [0x40, 0x80],
];

/// A dot-addressable surface that renders onto a [Canvas] as Braille characters.
///
/// Coordinates are in dots: a canvas `width × height` cells gives
/// `width * 2 × height * 4` dots, with (0, 0) at the top left.
class BrailleCanvas {
  /// Creates a surface covering [cellWidth] × [cellHeight] character cells.
  BrailleCanvas(this.cellWidth, this.cellHeight)
    : _masks = List<int>.filled(
        (cellWidth < 0 ? 0 : cellWidth) * (cellHeight < 0 ? 0 : cellHeight),
        0,
      );

  /// Width in character cells.
  final int cellWidth;

  /// Height in character cells.
  final int cellHeight;

  final List<int> _masks;

  /// Width in addressable dots.
  int get dotWidth => cellWidth * brailleDotsX;

  /// Height in addressable dots.
  int get dotHeight => cellHeight * brailleDotsY;

  /// Lights the dot at ([x], [y]), ignoring positions outside the surface.
  void set(int x, int y) {
    if (x < 0 || y < 0 || x >= dotWidth || y >= dotHeight) return;
    final cell = (y ~/ brailleDotsY) * cellWidth + (x ~/ brailleDotsX);
    _masks[cell] |= _dotBits[y % brailleDotsY][x % brailleDotsX];
  }

  /// Lights every dot on the straight line between two dot positions.
  ///
  /// Bresenham, so the line is connected with no gaps — which is the whole point of
  /// drawing in dot space: at cell resolution a steep segment becomes a vertical run
  /// of box-drawing characters, where here it is an actual diagonal.
  void line(int x0, int y0, int x1, int y1) {
    var x = x0;
    var y = y0;
    final dx = (x1 - x0).abs();
    final dy = (y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx - dy;
    while (true) {
      set(x, y);
      if (x == x1 && y == y1) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }

  /// Lights a vertical run of dots, for filling under a curve.
  void fillColumn(int x, int fromY, int toY) {
    final lo = fromY < toY ? fromY : toY;
    final hi = fromY < toY ? toY : fromY;
    for (var y = lo; y <= hi; y++) {
      set(x, y);
    }
  }

  /// Writes this surface onto [canvas] with its top-left at ([originX], [originY]).
  ///
  /// Cells with no lit dots are left untouched rather than written as the blank
  /// Braille pattern U+2800. That matters for two reasons: U+2800 is not a space, so
  /// trailing-whitespace trimming would not remove it and every row would carry an
  /// invisible tail; and leaving the cell alone lets axes, references and other
  /// series show through.
  void blitTo(
    Canvas canvas, {
    int originX = 0,
    int originY = 0,
    AnsiStyle? style,
  }) {
    for (var cy = 0; cy < cellHeight; cy++) {
      for (var cx = 0; cx < cellWidth; cx++) {
        final mask = _masks[cy * cellWidth + cx];
        if (mask == 0) continue;
        canvas.set(
          originX + cx,
          originY + cy,
          String.fromCharCode(_brailleBase + mask),
          style: style,
        );
      }
    }
  }

  /// Whether no dot has been lit.
  bool get isEmpty => _masks.every((m) => m == 0);
}
