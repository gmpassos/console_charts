/// Candlestick charts.
library;

import '../plot_frame.dart';
import '../renderable.dart';
import '../scale.dart';
import '../style.dart';
import '../theme.dart';

/// One open/high/low/close bar.
class Candle {
  /// Creates a candle.
  const Candle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.label,
  });

  /// The opening value.
  final num open;

  /// The highest value reached.
  final num high;

  /// The lowest value reached.
  final num low;

  /// The closing value.
  final num close;

  /// A short name, used as an x label.
  final String? label;

  /// Whether the close was above the open.
  bool get isUp => close.toDouble() >= open.toDouble();

  /// Whether every value can be plotted.
  bool get isFinite =>
      open.toDouble().isFinite &&
      high.toDouble().isFinite &&
      low.toDouble().isFinite &&
      close.toDouble().isFinite;

  /// The true low, tolerating inconsistent input.
  ///
  /// Real feeds do contain candles where the high is below the low, or the open is
  /// outside the range. Clamping is better than throwing, because a chart of a
  /// thousand candles should not be lost to one bad record.
  double get safeLow => [
    low.toDouble(),
    high.toDouble(),
    open.toDouble(),
    close.toDouble(),
  ].reduce((a, b) => a < b ? a : b);

  /// The true high, tolerating inconsistent input. See [safeLow].
  double get safeHigh => [
    low.toDouble(),
    high.toDouble(),
    open.toDouble(),
    close.toDouble(),
  ].reduce((a, b) => a > b ? a : b);

  @override
  String toString() => 'Candle(o: $open, h: $high, l: $low, c: $close)';
}

/// A candlestick chart.
///
/// ```text
/// 110 ┤          │
/// 100 ┤      ┌───┼───┐
///  90 ┤      │   │   │
///  80 ┤  │   └───┼───┘
///  70 ┤  │       │
///  60 ┼──┴───────────────
/// ```
///
/// The body spans open to close and the wick spans low to high. A candle whose open
/// and close land in the same cell draws as a single horizontal line — a doji — which
/// is correct rather than a degenerate case to hide.
class CandlestickChart implements Renderable {
  /// Creates a candlestick chart.
  const CandlestickChart(
    this.candles, {
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.title,
    this.axes = const Axes(),
    this.upStyle,
    this.downStyle,
    this.showLabels = true,
    this.bodySpan,
  });

  /// The candles, oldest first.
  final List<Candle> candles;

  /// Total width. Defaults to the theme's.
  final int? width;

  /// Total height. Defaults to the theme's.
  final int? height;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// A heading above the chart.
  final String? title;

  /// Axis decoration.
  final Axes axes;

  /// Colour for a candle that closed up. Defaults to green.
  final AnsiStyle? upStyle;

  /// Colour for a candle that closed down. Defaults to red.
  final AnsiStyle? downStyle;

  /// Whether to use the candles' labels on the x axis.
  final bool showLabels;

  /// How many columns wide each body is. Null fits them to the available slot.
  final int? bodySpan;

  @override
  List<String> renderLines() {
    final usable = candles.where((c) => c.isFinite).toList();
    if (usable.isEmpty) return const [];
    final w = width ?? theme.defaultWidth;
    final h = height ?? theme.defaultHeight;
    final chars = theme.charset;

    final yScale = LinearScale.fit(
      usable.expand((c) => [c.safeLow, c.safeHigh]),
      h,
      mode: axes.showYLabels ? AxisMode.nice : AxisMode.tight,
    );

    final labels = showLabels && usable.any((c) => c.label != null)
        ? [for (final c in usable) c.label ?? '']
        : null;

    return renderPlotFrame(
      width: w,
      height: h,
      theme: theme,
      axes: axes,
      title: title,
      xLabels: labels,
      yScale: yScale,
      xScale: (plotWidth) => LinearScale.index(usable.length, plotWidth),
      draw: (plot) {
        final up = upStyle ?? const AnsiStyle.of(AnsiColor.green);
        final down = downStyle ?? const AnsiStyle.of(AnsiColor.red);

        // Bodies get whatever width the slot allows, up to five columns, with the
        // wick running up the middle. A one-column body is technically correct and
        // unreadable — a candlestick chart is read by the shape of its bodies.
        final slot = (plot.width / usable.length).floor();
        final bodyWidth = bodySpan ?? (slot - 1).clamp(1, 5);
        final halfBody = bodyWidth ~/ 2;

        // Inset by half a body at each edge, so the first and last candles are drawn
        // whole instead of being clipped against the plot's sides.
        final span = plot.width - 1 - bodyWidth;
        for (var i = 0; i < usable.length; i++) {
          final candle = usable[i];
          final column = usable.length == 1
              ? plot.width ~/ 2
              : halfBody + (i * span / (usable.length - 1)).round();
          final style = theme.color ? (candle.isUp ? up : down) : null;

          final highLevel = plot.levelOf(candle.safeHigh);
          final lowLevel = plot.levelOf(candle.safeLow);
          final openLevel = plot.levelOf(candle.open);
          final closeLevel = plot.levelOf(candle.close);
          if (highLevel < 0 || lowLevel < 0) continue;

          // Wick first; the body overwrites it where they overlap, which is the
          // conventional rendering.
          plot.fillColumn(
            column,
            lowLevel,
            highLevel,
            glyph: chars.vertical,
            style: style,
          );

          final bodyLow = openLevel < closeLevel ? openLevel : closeLevel;
          final bodyHigh = openLevel < closeLevel ? closeLevel : openLevel;
          final left = column - halfBody;
          if (bodyLow == bodyHigh) {
            // A doji: open and close land in the same cell. Drawn as a bar across
            // the body's width, which is exactly what it means.
            for (var dx = 0; dx < bodyWidth; dx++) {
              plot.putLevel(left + dx, bodyLow, chars.horizontal, style: style);
            }
          } else if (bodyWidth <= 1) {
            plot
              ..putLevel(column, bodyLow, chars.teeUp, style: style)
              ..putLevel(column, bodyHigh, chars.teeDown, style: style);
            for (var l = bodyLow + 1; l < bodyHigh; l++) {
              plot.putLevel(column, l, chars.full, style: style);
            }
          } else {
            // A hollow body for a rising candle and a filled one for a falling
            // candle — the convention, and it survives having no colour.
            for (var l = bodyLow; l <= bodyHigh; l++) {
              final edgeRow = l == bodyLow || l == bodyHigh;
              for (var dx = 0; dx < bodyWidth; dx++) {
                final edgeColumn = dx == 0 || dx == bodyWidth - 1;
                final glyph = candle.isUp
                    ? (edgeRow
                          ? chars.horizontal
                          : (edgeColumn ? chars.vertical : chars.blank))
                    : chars.full;
                if (glyph == chars.blank) continue;
                plot.putLevel(left + dx, l, glyph, style: style);
              }
            }
            if (candle.isUp) {
              plot
                ..putLevel(left, bodyHigh, chars.topLeft, style: style)
                ..putLevel(
                  left + bodyWidth - 1,
                  bodyHigh,
                  chars.topRight,
                  style: style,
                )
                ..putLevel(left, bodyLow, chars.bottomLeft, style: style)
                ..putLevel(
                  left + bodyWidth - 1,
                  bodyLow,
                  chars.bottomRight,
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
