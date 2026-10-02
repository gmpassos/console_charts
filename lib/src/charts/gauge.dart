/// Gauges, progress bars and bullet charts — a fraction of a known whole.
///
/// All three are one chart with different decoration, so they share an
/// implementation. The distinction that matters is against a bar chart: a bar's
/// length means a quantity on a scale derived from the data, where these measure
/// against a *known maximum*. That is why they can show a percentage at all.
library;

import '../canvas.dart';
import '../charset.dart';
import '../format.dart';
import '../renderable.dart';
import '../row_frame.dart';
import '../style.dart';
import '../theme.dart';

/// One labelled reading of a fraction, for [Gauge] and [BulletChart].
class GaugeRow {
  /// Creates a reading of [value] out of [max].
  const GaugeRow(
    this.value, {
    this.label,
    this.max = 1.0,
    this.target,
    this.style,
  });

  /// The measured value.
  final num value;

  /// A short name for this row.
  final String? label;

  /// The value that corresponds to a full bar. Defaults to 1, i.e. a fraction.
  final num max;

  /// An optional target, drawn as a marker across the bar by [BulletChart].
  final num? target;

  /// Overrides the colour from the theme's palette.
  final AnsiStyle? style;

  /// [value] as a fraction of [max], clamped to 0..1.
  ///
  /// Returns 0 for an unusable reading rather than null, because a gauge's job is
  /// to show a level and an empty bar is the honest rendering of "no reading".
  double get fraction {
    final v = value.toDouble();
    final m = max.toDouble();
    if (!v.isFinite || !m.isFinite || m == 0) return 0;
    final t = v / m;
    if (!t.isFinite) return 0;
    return t < 0 ? 0 : (t > 1 ? 1 : t);
  }

  /// [value] as a fraction of [max], **not** clamped.
  ///
  /// What the printed label uses, where the bar uses [fraction]. The bar has
  /// nowhere to put an extra 40%, but hiding it in the label too would turn an
  /// overflow into a silent "100%" — the one reading a gauge must not misreport.
  double get ratio {
    final v = value.toDouble();
    final m = max.toDouble();
    if (!v.isFinite || !m.isFinite || m == 0) return 0;
    final t = v / m;
    return t.isFinite ? t : 0;
  }

  /// Whether [value] exceeded [max].
  bool get overflows => ratio > 1;
}

/// Bracketed gauges showing a fraction of a known whole.
///
/// ```text
/// CPU  [██████████████░░░░░░] 68%
/// RAM  [█████████████████░░░] 82%
/// GPU  [████████████████████] 97%
/// ```
class Gauge implements Renderable {
  /// Creates a gauge for each of [rows].
  const Gauge(
    this.rows, {
    this.width,
    this.theme = ChartTheme.plain,
    this.showValues = true,
    this.brackets = true,
    this.title,
    this.valueFormat,
    this.fractional = true,
  });

  /// Creates a single gauge for [value] out of [max].
  Gauge.single(
    num value, {
    String? label,
    num max = 1.0,
    int? width,
    ChartTheme theme = ChartTheme.plain,
    bool showValues = true,
    bool brackets = true,
    NumberFormatter? valueFormat,
  }) : this(
         [GaugeRow(value, label: label, max: max)],
         width: width,
         theme: theme,
         showValues: showValues,
         brackets: brackets,
         valueFormat: valueFormat,
       );

  /// The readings, one row each.
  final List<GaugeRow> rows;

  /// Total width including label, brackets and value.
  final int? width;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// Whether to print the value after the bar.
  final bool showValues;

  /// Whether to wrap the bar in `[` and `]`.
  final bool brackets;

  /// A heading printed above the rows.
  final String? title;

  /// How the value is formatted. Defaults to a percentage.
  final NumberFormatter? valueFormat;

  /// Whether the bar may end on a partial character.
  ///
  /// On by default, giving eighth-of-a-cell precision. Turn it off for a gauge
  /// that should read as a count of whole blocks.
  final bool fractional;

  @override
  List<String> renderLines() {
    if (rows.isEmpty) return const [];
    final total = width ?? theme.defaultWidth;
    final format = valueFormat ?? formatPercent();
    final chars = theme.charset;
    final track = chars.shades.first;

    return renderRowFrame(
      width: total,
      rowCount: rows.length,
      theme: theme,
      title: title,
      labels: [for (final r in rows) r.label ?? ''],
      values: showValues
          ? [
              for (final r in rows)
                '${format(r.ratio)}${r.overflows ? '!' : ''}',
            ]
          : const [],
      body: (i, body) {
        final row = rows[i];
        final open = brackets ? 1 : 0;
        final barWidth = body.width - open * 2;
        if (barWidth < 1) return;

        if (brackets) {
          final style = theme.color ? theme.axisStyle : null;
          body
            ..set(0, 0, '[', style: style)
            ..set(body.width - 1, 0, ']', style: style);
        }

        final style = theme.color ? row.style ?? theme.seriesStyle(i) : null;
        final eighths = _eighths(row.fraction, barWidth);
        drawBarEighths(
          body,
          fractional ? eighths : (eighths ~/ 8) * 8,
          x: open,
          extent: barWidth,
          chars: chars,
          style: style,
          track: track,
          trackStyle: theme.color ? theme.trackStyle : null,
        );
      },
    );
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A single progress bar.
///
/// ```text
/// Downloading
/// [████████████████████░░░░░] 80%
/// ```
///
/// A [Gauge] with one row, named for what it is usually used for.
class ProgressBar implements Renderable {
  /// Creates a progress bar at [fraction] of the way through.
  const ProgressBar(
    this.fraction, {
    this.label,
    this.width,
    this.theme = ChartTheme.plain,
    this.showValue = true,
    this.brackets = true,
  });

  /// How far along, from 0 to 1. Values outside that range are clamped.
  final num fraction;

  /// A caption printed above the bar.
  final String? label;

  /// Total width of the bar line.
  final int? width;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// Whether to print the percentage after the bar.
  final bool showValue;

  /// Whether to wrap the bar in brackets.
  final bool brackets;

  @override
  List<String> renderLines() => [
    if (label != null && label!.isNotEmpty) label!,
    ...Gauge(
      [GaugeRow(fraction)],
      width: width,
      theme: theme,
      showValues: showValue,
      brackets: brackets,
    ).renderLines(),
  ];

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// Gauges with a target marker.
///
/// ```text
/// CPU  [███████████████░░░░░░░░░] 72%  ┃ target 80%
/// RAM  [██████████████████░░░░░░] 84%  ┃ target 75%
/// ```
///
/// The marker is drawn *into* the bar at its target position, so whether the
/// reading has passed the target is visible without reading the numbers.
class BulletChart implements Renderable {
  /// Creates a bullet chart for each of [rows]. Rows without a target render as
  /// plain gauges.
  const BulletChart(
    this.rows, {
    this.width,
    this.theme = ChartTheme.plain,
    this.showValues = true,
    this.showTargets = true,
    this.title,
    this.valueFormat,
  });

  /// The readings, each optionally carrying a target.
  final List<GaugeRow> rows;

  /// Total width including label, bar, value and target note.
  final int? width;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// Whether to print the reading after the bar.
  final bool showValues;

  /// Whether to print `target N` after the reading.
  final bool showTargets;

  /// A heading printed above the rows.
  final String? title;

  /// How values are formatted. Defaults to a percentage.
  final NumberFormatter? valueFormat;

  @override
  List<String> renderLines() {
    if (rows.isEmpty) return const [];
    final total = width ?? theme.defaultWidth;
    final format = valueFormat ?? formatPercent();
    final chars = theme.charset;

    return renderRowFrame(
      width: total,
      rowCount: rows.length,
      theme: theme,
      title: title,
      labels: [for (final r in rows) r.label ?? ''],
      values: showValues
          ? [
              for (final r in rows)
                () {
                  final value = format(r.ratio);
                  if (!showTargets || r.target == null) return value;
                  final t = r.target!.toDouble() / r.max.toDouble();
                  return '$value ${chars.vertical} ${format(t)}';
                }(),
            ]
          : const [],
      body: (i, body) {
        final row = rows[i];
        final barWidth = body.width - 2;
        if (barWidth < 1) return;
        final axis = theme.color ? theme.axisStyle : null;
        body
          ..set(0, 0, '[', style: axis)
          ..set(body.width - 1, 0, ']', style: axis);

        drawBarEighths(
          body,
          _eighths(row.fraction, barWidth),
          x: 1,
          extent: barWidth,
          chars: chars,
          style: theme.color ? row.style ?? theme.seriesStyle(i) : null,
          track: chars.shades.first,
          trackStyle: theme.color ? theme.trackStyle : null,
        );

        final target = row.target;
        if (target == null) return;
        final m = row.max.toDouble();
        final t = m == 0 ? 0.0 : target.toDouble() / m;
        if (!t.isFinite) return;
        // Positioned by the same rule as the bar's tip so the two agree: a reading
        // exactly at its target must put the marker at the bar's end, not one cell
        // either side of it.
        final cell = ((t.clamp(0.0, 1.0) * barWidth * 8) ~/ 8).clamp(
          0,
          barWidth - 1,
        );
        body.set(
          1 + cell,
          0,
          chars.vertical,
          style: theme.color
              ? const AnsiStyle(foreground: AnsiColor.brightWhite, bold: true)
              : null,
        );
      },
    );
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A fraction's length in eighths of a cell, across a given number of cells.
///
/// A full reading must fill every cell and an empty one must fill none, exactly.
/// Without the epsilon, `(0.9999999 * 20 * 8).floor()` leaves the last eighth
/// unfilled and a gauge at 100% shows a gap — reported as a bug every time.
int _eighths(double fraction, int cells) {
  if (!fraction.isFinite || fraction <= 0) return 0;
  if (fraction >= 1 - 1e-9) return cells * 8;
  return (fraction * cells * 8).round();
}

/// Draws a gauge bar onto [canvas] at ([x], [y]), for embedding in a layout.
void drawGauge(
  Canvas canvas,
  int x,
  int y,
  double fraction, {
  required int width,
  CharSet chars = CharSets.unicode,
  AnsiStyle? style,
  AnsiStyle? trackStyle,
  bool brackets = false,
}) {
  if (width <= 0) return;
  final open = brackets ? 1 : 0;
  final barWidth = width - open * 2;
  if (barWidth < 1) return;
  if (brackets) {
    canvas
      ..set(x, y, '[', style: trackStyle)
      ..set(x + width - 1, y, ']', style: trackStyle);
  }
  final sub = Canvas(barWidth, 1);
  drawBarEighths(
    sub,
    _eighths(fraction, barWidth),
    chars: chars,
    style: style,
    track: chars.shades.first,
    trackStyle: trackStyle,
  );
  canvas.blit(sub, x + open, y);
}
