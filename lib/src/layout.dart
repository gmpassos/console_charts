/// Composing charts: frames, rules, tables and dashboards.
///
/// Everything here works on `List<String>` blocks, so it composes any
/// [Renderable] — a chart, a panel holding a chart, or literal text — without
/// knowing what it is holding.
library;

import 'canvas.dart';
import 'charset.dart';
import 'renderable.dart';
import 'theme.dart';
import 'width.dart';

/// Any block of lines, treated as a rectangle.
extension BlockLayout on List<String> {
  /// The display width of the widest line.
  int blockWidth([DisplayWidth measure = DisplayWidth.standard]) =>
      fold(0, (m, l) {
        final w = measure(l);
        return w > m ? w : m;
      });

  /// This block padded to [width] columns and [height] rows.
  List<String> padBlock({
    int? width,
    int? height,
    DisplayWidth measure = DisplayWidth.standard,
  }) {
    final w = width ?? blockWidth(measure);
    final rows = [for (final line in this) padToWidth(line, w, width: measure)];
    if (height != null) {
      while (rows.length < height) {
        rows.add(' ' * w);
      }
    }
    return rows;
  }
}

/// Places [blocks] side by side, separated by [gap] columns.
///
/// Shorter blocks are padded down so the result is rectangular. This is what makes
/// a dashboard row work regardless of the heights of the charts in it.
List<String> hstack(
  List<List<String>> blocks, {
  int gap = 1,
  DisplayWidth measure = DisplayWidth.standard,
}) {
  if (blocks.isEmpty) return const [];
  final height = blocks.fold(0, (m, b) => b.length > m ? b.length : m);
  final padded = [
    for (final b in blocks) b.padBlock(height: height, measure: measure),
  ];
  final separator = ' ' * gap;
  return [
    for (var row = 0; row < height; row++)
      [for (final b in padded) b[row]].join(separator).trimRight(),
  ];
}

/// Stacks [blocks] vertically, separated by [gap] blank lines.
List<String> vstack(List<List<String>> blocks, {int gap = 0}) {
  final out = <String>[];
  for (var i = 0; i < blocks.length; i++) {
    out.addAll(blocks[i]);
    if (gap > 0 && i < blocks.length - 1) {
      out.addAll(List<String>.filled(gap, ''));
    }
  }
  return out;
}

/// A section rule, optionally with a title inlaid.
///
/// ```text
/// ── Training ─────────────────────────────
/// ═══ Done ════════════════════════════════
/// CONSOLE · · · · · · · · · · · · · · · · ·
/// ```
///
/// Replaces padding a run of dashes by eye, which is how these are usually written
/// and why they are usually a column or two off.
String rule(
  String? title, {
  int width = 60,
  ChartTheme theme = ChartTheme.plain,
  RuleStyle style = RuleStyle.light,
  int lead = 2,
}) {
  final chars = theme.charset;
  final glyph = switch (style) {
    RuleStyle.light => chars.horizontal,
    RuleStyle.heavy => chars.heavyHorizontal,
    RuleStyle.dotted => chars.dottedHorizontal,
  };
  final measure = theme.width;

  if (title == null || title.isEmpty) {
    return style == RuleStyle.dotted ? _dotted(glyph, width) : glyph * width;
  }

  // The dotted style leads with its title rather than with dots, because that is
  // how a trailing-dots rule reads: `CONSOLE · · · ·`, not `·· CONSOLE · ·`.
  if (style == RuleStyle.dotted) {
    final shown = truncateToWidth(
      title,
      width - 2,
      ellipsis: '…',
      width: measure,
    );
    final tailWidth = width - measure(shown) - 1;
    if (tailWidth <= 0) return shown;
    return '$shown ${_dotted(glyph, tailWidth)}';
  }

  final head = glyph * lead;
  final shown = truncateToWidth(
    title,
    width - lead - 2,
    ellipsis: '…',
    width: measure,
  );
  final used = lead + measure(shown) + 2;
  final tailWidth = width - used;
  if (tailWidth <= 0) return '$head $shown';
  final tail = style == RuleStyle.dotted
      ? _dotted(glyph, tailWidth)
      : glyph * tailWidth;
  return '$head $shown $tail';
}

/// A run of [glyph] separated by spaces, filling exactly [width] columns.
String _dotted(String glyph, int width) {
  if (width <= 0) return '';
  final out = StringBuffer();
  for (var i = 0; i < width; i++) {
    out.write(i.isEven ? glyph : ' ');
  }
  return out.toString();
}

/// The weight of a [rule].
enum RuleStyle {
  /// A single line: `── title ──`.
  light,

  /// A double line: `═══ title ═══`.
  heavy,

  /// Spaced dots: `title · · ·`.
  dotted,
}

/// A framed box around another renderable.
///
/// ```text
/// ┌─ Training ─────────────┐
/// │ loss  █▇▆▅▄▃▂▁  0.052  │
/// └────────────────────────┘
/// ```
///
/// The frame is sized to its content unless [width] says otherwise, and a title too
/// long to fit is truncated rather than widening the frame — a frame that grew to fit
/// its title would break whatever layout contains it.
class Panel implements Renderable {
  /// Frames [child].
  const Panel(
    this.child, {
    this.title,
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.padding = 1,
  });

  /// Frames literal [lines].
  Panel.lines(
    List<String> lines, {
    String? title,
    int? width,
    int? height,
    ChartTheme theme = ChartTheme.plain,
    int padding = 1,
  }) : this(
         _LiteralBlock(lines),
         title: title,
         width: width,
         height: height,
         theme: theme,
         padding: padding,
       );

  /// What goes inside the frame.
  final Renderable child;

  /// A title inlaid into the top edge.
  final String? title;

  /// Total width including the frame. Null fits the content.
  final int? width;

  /// Total height including the frame. Null fits the content.
  final int? height;

  /// Glyphs and colours.
  final ChartTheme theme;

  /// Blank columns between the frame and the content.
  final int padding;

  @override
  List<String> renderLines() {
    final inner = child.renderLines();
    final measure = theme.width;
    final contentWidth = inner.blockWidth(measure);
    final totalWidth = width ?? contentWidth + 2 + padding * 2;
    final totalHeight = height ?? inner.length + 2;
    if (totalWidth < 2 || totalHeight < 2) return inner;

    final canvas = Canvas(totalWidth, totalHeight)
      ..drawBox(
        theme.charset,
        title: title,
        style: theme.color ? theme.axisStyle : null,
        titleStyle: theme.color ? theme.titleStyle : null,
        measure: measure,
      );
    for (var i = 0; i < inner.length && i + 1 < totalHeight - 1; i++) {
      canvas.drawText(1 + padding, 1 + i, inner[i], measure: measure);
    }
    return canvas.renderLines(color: theme.color);
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A grid of renderables composed into one block.
///
/// ```dart
/// Dashboard([
///   [Panel(gauge, title: 'Storage'), Panel(spark, title: 'Latency')],
///   [Panel(bars, title: 'Log levels')],
/// ], title: 'Training');
/// ```
///
/// Each inner list is a row, laid out left to right. Rows of unequal height are
/// padded, so a tall chart beside a short one does not shear the layout.
class Dashboard implements Renderable {
  /// Creates a dashboard of [rows].
  const Dashboard(
    this.rows, {
    this.title,
    this.theme = ChartTheme.plain,
    this.gap = 1,
    this.rowGap = 0,
    this.framed = false,
    this.width,
  });

  /// The grid: one list per row.
  final List<List<Renderable>> rows;

  /// A heading, or the frame's title when [framed].
  final String? title;

  /// Glyphs and colours.
  final ChartTheme theme;

  /// Columns between items in a row.
  final int gap;

  /// Blank lines between rows.
  final int rowGap;

  /// Whether to frame the whole dashboard.
  final bool framed;

  /// Total width when [framed]. Null fits the content.
  final int? width;

  @override
  List<String> renderLines() {
    final measure = theme.width;
    final composed = vstack([
      for (final row in rows)
        hstack(
          [for (final item in row) item.renderLines()],
          gap: gap,
          measure: measure,
        ),
    ], gap: rowGap);
    if (framed) {
      return Panel.lines(
        composed,
        title: title,
        theme: theme,
        width: width,
      ).renderLines();
    }
    if (title != null && title!.isNotEmpty) {
      return [
        rule(title, width: width ?? composed.blockWidth(measure), theme: theme),
        ...composed,
      ];
    }
    return composed;
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A table of aligned columns.
///
/// ```text
/// role            blocks     min     max
/// attn.q          147456   -8.52   -1.09
/// mlp.down        589824  -24.00   -2.31
/// ```
///
/// Column widths are measured from the content, which is the point: the alternative
/// is `'-' * (nameW + 2 + 12 + 12 + 12)` summed by hand, and that arithmetic is
/// wrong as soon as anything changes.
///
/// ## Sized by its content
///
/// There is no total width, deliberately. A table forced into fewer columns would
/// have to drop or truncate data, and a reader cannot tell which — so it is wide
/// instead, and [maxColumnWidth] caps individual columns when a single cell is the
/// problem.
class Table implements Renderable {
  /// Creates a table of [rows], optionally with a [header].
  const Table(
    this.rows, {
    this.header,
    this.align = const [],
    this.theme = ChartTheme.plain,
    this.gap = 2,
    this.rule = false,
    this.maxColumnWidth,
  });

  /// The body, one list of cells per row.
  final List<List<String>> rows;

  /// Column titles.
  final List<String>? header;

  /// Per-column alignment. Missing entries default to left, except that a column
  /// whose every body cell parses as a number defaults to right — which is what
  /// numeric columns always want and what nobody remembers to ask for.
  final List<TextAlign> align;

  /// Glyphs and colours.
  final ChartTheme theme;

  /// Columns between cells.
  final int gap;

  /// Whether to draw a rule under the header.
  final bool rule;

  /// Caps any one column's width, truncating with an ellipsis.
  final int? maxColumnWidth;

  @override
  List<String> renderLines() {
    if (rows.isEmpty && header == null) return const [];
    final measure = theme.width;
    final columnCount = [
      if (header != null) header!.length,
      ...rows.map((r) => r.length),
    ].fold(0, (m, l) => l > m ? l : m);
    if (columnCount == 0) return const [];

    String cell(List<String> row, int c) => c < row.length ? row[c] : '';

    final widths = List<int>.filled(columnCount, 0);
    for (var c = 0; c < columnCount; c++) {
      if (header != null) {
        final w = measure(cell(header!, c));
        if (w > widths[c]) widths[c] = w;
      }
      for (final row in rows) {
        final w = measure(cell(row, c));
        if (w > widths[c]) widths[c] = w;
      }
      if (maxColumnWidth != null && widths[c] > maxColumnWidth!) {
        widths[c] = maxColumnWidth!;
      }
    }

    final alignment = List<TextAlign>.generate(columnCount, (c) {
      if (c < align.length) return align[c];
      // Numeric columns right-align, which is the only way a column of numbers can
      // be compared down the page.
      final body = rows.where((r) => cell(r, c).isNotEmpty);
      if (body.isNotEmpty &&
          body.every((r) => num.tryParse(cell(r, c).trim()) != null)) {
        return TextAlign.right;
      }
      return TextAlign.left;
    });

    String renderRow(List<String> row) {
      final parts = <String>[
        for (var c = 0; c < columnCount; c++)
          padToWidth(
            truncateToWidth(
              cell(row, c),
              widths[c],
              ellipsis: '…',
              width: measure,
            ),
            widths[c],
            align: alignment[c],
            width: measure,
          ),
      ];
      return parts.join(' ' * gap).trimRight();
    }

    final out = <String>[];
    if (header != null) {
      out.add(renderRow(header!));
      if (rule) {
        final total =
            widths.fold<int>(0, (a, b) => a + b) + gap * (columnCount - 1);
        out.add(theme.charset.horizontal * total);
      }
    }
    for (final row in rows) {
      out.add(renderRow(row));
    }
    return out;
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// Wraps literal lines so anything can go into a [Panel] or [Dashboard].
class TextBlock implements Renderable {
  /// Wraps [lines].
  const TextBlock(this.lines);

  /// Splits [text] on newlines.
  TextBlock.of(String text) : lines = text.split('\n');

  /// The lines.
  final List<String> lines;

  @override
  List<String> renderLines() => lines;

  @override
  String render() => lines.join('\n');

  @override
  String toString() => render();
}

class _LiteralBlock implements Renderable {
  const _LiteralBlock(this.lines);
  final List<String> lines;
  @override
  List<String> renderLines() => lines;
  @override
  String render() => lines.join('\n');
}

/// Draws a rule onto [canvas], for embedding in a layout.
void drawRule(
  Canvas canvas,
  int x,
  int y,
  int width, {
  CharSet chars = CharSets.unicode,
  String? title,
}) {
  canvas.hLine(x, y, width, chars.horizontal);
  if (title != null && title.isNotEmpty) {
    canvas.drawText(x + 2, y, ' $title ');
  }
}
