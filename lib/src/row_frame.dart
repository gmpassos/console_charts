/// The shared layout behind every chart that is one row per item.
///
/// Horizontal bars, stacked bars, gauges, progress bars, bullet charts and
/// box plots all have the same shape: an optional label on the left, a drawing area
/// in the middle, an optional value on the right, every row aligned. Only the
/// middle differs. That middle is a callback here, so none of those charts contains
/// any layout code and they cannot drift out of alignment with each other.
library;

import 'canvas.dart';
import 'charset.dart';
import 'style.dart';
import 'theme.dart';
import 'width.dart';

/// Lays out labelled rows and lets [body] draw the middle of each one.
///
/// [body] is called once per row with a canvas exactly [rowHeight] tall and as
/// wide as the space left after the gutters, and may draw anywhere in it.
///
/// The label and value gutters are sized to their widest entry, then capped so
/// they cannot crowd out the chart: a label longer than a third of the width is
/// truncated. Both gutters vanish entirely when nothing needs them, so a gauge with
/// no label starts at column zero.
///
/// Returns one string per output line: [title] if given, then every row, separated
/// by [rowGap] blank lines.
List<String> renderRowFrame({
  required int width,
  required int rowCount,
  required void Function(int row, Canvas body) body,
  ChartTheme theme = ChartTheme.plain,
  List<String> labels = const [],
  List<String> values = const [],
  int rowHeight = 1,
  int rowGap = 0,
  String? title,
  TextAlign labelAlign = TextAlign.left,
}) {
  if (rowCount <= 0 || width <= 0 || rowHeight <= 0) return const [];
  final measure = theme.width;

  String labelAt(int i) => i < labels.length ? labels[i] : '';
  String valueAt(int i) => i < values.length ? values[i] : '';

  var labelWidth = 0;
  var valueWidth = 0;
  for (var i = 0; i < rowCount; i++) {
    final l = measure(labelAt(i));
    if (l > labelWidth) labelWidth = l;
    final v = measure(valueAt(i));
    if (v > valueWidth) valueWidth = v;
  }

  // A label is allowed at most a third of the width. Without a cap one long
  // category name squeezes every bar down to nothing, and the chart stops being a
  // chart while still looking like one.
  final labelCap = width ~/ 3;
  if (labelWidth > labelCap) labelWidth = labelCap;
  final valueCap = width ~/ 3;
  if (valueWidth > valueCap) valueWidth = valueCap;

  final labelCell = labelWidth > 0 ? labelWidth + 1 : 0;
  final valueCell = valueWidth > 0 ? valueWidth + 1 : 0;
  var bodyWidth = width - labelCell - valueCell;

  // Still no room: give the body what is left and let the gutters go. A chart with
  // no bar is useless, where a chart with a clipped label is merely untidy.
  if (bodyWidth < 1) {
    bodyWidth = width - labelCell;
    if (bodyWidth < 1) return const [];
    valueWidth = 0;
  }

  final out = <String>[];
  if (title != null && title.isNotEmpty) {
    out.add(truncateToWidth(title, width, ellipsis: '…', width: measure));
  }

  for (var i = 0; i < rowCount; i++) {
    final row = Canvas(width, rowHeight);
    if (labelWidth > 0) {
      final label = truncateToWidth(
        labelAt(i),
        labelWidth,
        ellipsis: '…',
        width: measure,
      );
      row.drawText(
        0,
        0,
        padToWidth(label, labelWidth, align: labelAlign, width: measure),
        style: theme.color ? theme.labelStyle : null,
      );
    }

    final bodyCanvas = Canvas(bodyWidth, rowHeight);
    body(i, bodyCanvas);
    row.blit(bodyCanvas, labelCell, 0);

    if (valueWidth > 0) {
      final value = truncateToWidth(
        valueAt(i),
        valueWidth,
        ellipsis: '…',
        width: measure,
      );
      row.drawText(
        labelCell + bodyWidth + 1,
        0,
        padToWidth(value, valueWidth, align: TextAlign.right, width: measure),
        style: theme.color ? theme.valueStyle : null,
      );
    }

    out.addAll(row.renderLines(color: theme.color));
    if (rowGap > 0 && i < rowCount - 1) {
      out.addAll(List<String>.filled(rowGap, ''));
    }
  }
  return out;
}

/// Draws a bar [cells] wide plus a fractional tip, on row [y] of [canvas].
///
/// [eighths] is the length in eighths of a cell, as [LinearScale.quantityEighths]
/// produces. Whole cells are filled with [CharSet.full] and the remainder becomes
/// one partial glyph from [CharSet.horizontalRamp], so a bar can end at `▊` rather
/// than rounding to the nearest whole character — which is both more precise and
/// what the house style of the author's own reports already uses.
///
/// Returns the number of columns drawn, tip included.
/// [extent] limits how many columns the bar and its track may occupy, for a caller
/// that has already reserved space to the right — a gauge's closing bracket, say.
/// Without it the track runs to the canvas edge and overwrites whatever is there.
int drawBarEighths(
  Canvas canvas,
  int eighths, {
  int y = 0,
  int x = 0,
  int? extent,
  required CharSet chars,
  AnsiStyle? style,
  String? track,
  AnsiStyle? trackStyle,
}) {
  final available = canvas.width - x;
  final total = extent == null
      ? available
      : (extent < available ? extent : available);
  if (total <= 0) return 0;
  final clamped = eighths < 0 ? 0 : eighths;
  var whole = clamped ~/ 8;
  final remainder = clamped % 8;
  if (whole > total) whole = total;

  for (var i = 0; i < whole; i++) {
    canvas.set(x + i, y, chars.full, style: style);
  }
  var drawn = whole;
  if (remainder > 0 && whole < total) {
    final tip = partialGlyph(chars.horizontalRamp, remainder / 8);
    if (tip != null) {
      canvas.set(x + whole, y, tip, style: style);
      drawn++;
    }
  }
  if (track != null) {
    for (var i = drawn; i < total; i++) {
      canvas.set(x + i, y, track, style: trackStyle);
    }
  }
  return drawn;
}
