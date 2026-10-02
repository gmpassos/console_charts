/// The drawing surface every chart composes onto.
library;

import 'charset.dart';
import 'style.dart';
import 'width.dart';

/// A fixed-size grid of character cells, each one glyph and an optional style.
///
/// `(0, 0)` is the **top-left** cell, and y grows downward, matching the order
/// lines are printed. Charts whose data grows upward convert once, when mapping a
/// value to a row, rather than everywhere.
///
/// ## Writes outside the grid are dropped, not an error
///
/// Clipping is the single most useful property here. A chart that computes a
/// position from data cannot always prove the result is in range — a label one
/// column too long, a value at the very top of the domain, a rounding step that
/// lands on `height` instead of `height - 1`. Making those silent keeps bounds
/// checks out of every drawing routine, and the alternative is a chart that throws
/// on real data. Anything that must not be clipped is caught by the layout tests
/// asserting exact output dimensions instead.
///
/// ## Glyphs and styles never mix
///
/// A cell stores its style *beside* its glyph, and escape sequences are produced
/// only in [renderLines]. Nothing that measures or positions text can therefore
/// see an escape sequence, which is what makes colour unable to disturb layout.
class Canvas {
  /// Creates a [width] × [height] canvas, every cell set to [fill].
  ///
  /// Both dimensions are clamped at zero, so a degenerate size produces an empty
  /// canvas rather than throwing — charts asked to draw in no space should render
  /// nothing.
  Canvas(int width, int height, {String fill = ' '})
    : width = width < 0 ? 0 : width,
      height = height < 0 ? 0 : height,
      _fill = fill {
    _glyphs = List<String>.filled(this.width * this.height, fill);
  }

  /// Columns.
  final int width;

  /// Rows.
  final int height;

  final String _fill;
  late final List<String> _glyphs;

  /// Allocated on the first styled write, so uncoloured charts never pay for it.
  List<AnsiStyle?>? _styles;

  /// Whether any cell has been given a style.
  bool get hasStyles => _styles != null;

  bool _inside(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  /// Writes [glyph] at ([x], [y]), ignoring positions outside the canvas.
  ///
  /// [glyph] should be a single character. A longer string is stored as-is and
  /// will widen the row, which is occasionally useful and usually a bug — prefer
  /// [drawText].
  void set(int x, int y, String glyph, {AnsiStyle? style}) {
    if (!_inside(x, y)) return;
    final i = y * width + x;
    _glyphs[i] = glyph;
    if (style != null && !style.isEmpty) {
      (_styles ??= List<AnsiStyle?>.filled(width * height, null))[i] = style;
    }
  }

  /// The glyph at ([x], [y]), or the fill character if outside the canvas.
  String glyphAt(int x, int y) =>
      _inside(x, y) ? _glyphs[y * width + x] : _fill;

  /// The style at ([x], [y]), or null if unstyled or outside the canvas.
  ///
  /// Written as a statement rather than a conditional expression because
  /// `cond ? _styles?[i] : null` parses the `?[` as a nested ternary followed by a
  /// list literal, which is a confusing error rather than a syntax one.
  AnsiStyle? styleAt(int x, int y) {
    if (!_inside(x, y)) return null;
    return _styles?[y * width + x];
  }

  /// Writes [text] left to right starting at ([x], [y]).
  ///
  /// Advances by each character's display width, so a wide character occupies the
  /// two columns it will actually be drawn in and whatever follows stays aligned.
  /// The second column of a wide character is left as the fill, because writing
  /// anything there would be overwritten by the terminal anyway.
  void drawText(
    int x,
    int y,
    String text, {
    AnsiStyle? style,
    DisplayWidth measure = DisplayWidth.standard,
  }) {
    var cx = x;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      set(cx, y, ch, style: style);
      final w = runeWidth(rune);
      cx += w == 0 ? 1 : w;
    }
  }

  /// Draws [length] cells of [glyph] rightward from ([x], [y]).
  void hLine(int x, int y, int length, String glyph, {AnsiStyle? style}) {
    for (var i = 0; i < length; i++) {
      set(x + i, y, glyph, style: style);
    }
  }

  /// Draws [length] cells of [glyph] downward from ([x], [y]).
  void vLine(int x, int y, int length, String glyph, {AnsiStyle? style}) {
    for (var i = 0; i < length; i++) {
      set(x, y + i, glyph, style: style);
    }
  }

  /// Fills a [w] × [h] rectangle of [glyph] with its top-left at ([x], [y]).
  void fillRect(int x, int y, int w, int h, String glyph, {AnsiStyle? style}) {
    for (var dy = 0; dy < h; dy++) {
      hLine(x, y + dy, w, glyph, style: style);
    }
  }

  /// Copies [src] onto this canvas with its top-left at ([x], [y]).
  ///
  /// This is what lets a chart nest inside a panel inside a dashboard: each
  /// renders onto its own canvas at its own coordinates and the parent places the
  /// result. Styles travel with the glyphs. Cells of [src] that fall outside this
  /// canvas are clipped as usual.
  void blit(Canvas src, int x, int y) {
    for (var sy = 0; sy < src.height; sy++) {
      for (var sx = 0; sx < src.width; sx++) {
        set(
          x + sx,
          y + sy,
          src._glyphs[sy * src.width + sx],
          style: src._styles?[sy * src.width + sx],
        );
      }
    }
  }

  /// Draws a box around the whole canvas, or around the given rectangle.
  ///
  /// With [title], the title is inlaid into the top edge after one horizontal
  /// run — `┌─ Training ────┐`. A title too long for the width is truncated with
  /// an ellipsis so the frame stays exactly [w] wide, because a frame that grew to
  /// fit its title would break every enclosing layout.
  void drawBox(
    CharSet chars, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    String? title,
    AnsiStyle? style,
    AnsiStyle? titleStyle,
    DisplayWidth measure = DisplayWidth.standard,
  }) {
    final bw = w ?? width;
    final bh = h ?? height;
    if (bw < 2 || bh < 2) return;

    hLine(x, y, bw, chars.horizontal, style: style);
    hLine(x, y + bh - 1, bw, chars.horizontal, style: style);
    vLine(x, y, bh, chars.vertical, style: style);
    vLine(x + bw - 1, y, bh, chars.vertical, style: style);
    set(x, y, chars.topLeft, style: style);
    set(x + bw - 1, y, chars.topRight, style: style);
    set(x, y + bh - 1, chars.bottomLeft, style: style);
    set(x + bw - 1, y + bh - 1, chars.bottomRight, style: style);

    if (title != null && title.isNotEmpty) {
      // Two corners, one leading run, and a space either side of the text.
      final room = bw - 5;
      if (room > 0) {
        final shown = truncateToWidth(
          title,
          room,
          ellipsis: '…',
          width: measure,
        );
        drawText(
          x + 2,
          y,
          ' $shown ',
          style: titleStyle ?? style,
          measure: measure,
        );
        set(x + 1, y, chars.horizontal, style: style);
      }
    }
  }

  /// One string per row, top to bottom.
  ///
  /// With [color] false — the default — styles are ignored entirely and the result
  /// is plain text. That is what golden tests compare, and it is why colour cannot
  /// silently change a chart's shape.
  ///
  /// With [color] true, runs of cells sharing one style are wrapped in a single
  /// escape sequence and reset rather than one per cell, which keeps the output
  /// readable and small. Each row resets before its end, so a style never leaks
  /// into whatever the caller prints next.
  ///
  /// [trimRight] removes trailing fill characters, which keeps charts from
  /// emitting lines padded with spaces. Turn it off when the exact rectangle
  /// matters — a background colour extending to the right edge, for instance.
  List<String> renderLines({bool color = false, bool trimRight = true}) {
    final out = <String>[];
    for (var y = 0; y < height; y++) {
      final row = StringBuffer();
      var last = y * width + width - 1;
      if (trimRight) {
        while (last >= y * width && _glyphs[last] == _fill) {
          last--;
        }
      }
      if (color && _styles != null) {
        AnsiStyle? open;
        for (var i = y * width; i <= last; i++) {
          final s = _styles![i];
          if (s != open) {
            if (open != null) row.write(reset);
            if (s != null) row.write(s.escape);
            open = s;
          }
          row.write(_glyphs[i]);
        }
        if (open != null) row.write(reset);
      } else {
        for (var i = y * width; i <= last; i++) {
          row.write(_glyphs[i]);
        }
      }
      out.add(row.toString());
    }
    return out;
  }

  /// The canvas as a single string, rows joined by newlines.
  String render({bool color = false, bool trimRight = true}) =>
      renderLines(color: color, trimRight: trimRight).join('\n');

  @override
  String toString() => render();
}
