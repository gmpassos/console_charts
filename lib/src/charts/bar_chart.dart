/// Horizontal bar charts: plain, grouped, stacked and 100%-stacked.
library;

import '../charset.dart';
import '../renderable.dart';
import '../row_frame.dart';
import '../scale.dart';
import '../series.dart';
import '../theme.dart';

/// How several series share a row.
enum BarMode {
  /// One bar per category, from the first series only.
  plain,

  /// One bar per series per category, on consecutive rows.
  grouped,

  /// Series laid end to end in one bar, each a different shade.
  stacked,

  /// Like [stacked], but every row is normalised to the full width.
  ///
  /// Shows composition rather than magnitude — which row is mostly errors, not
  /// which row has the most.
  percentStacked,
}

/// A labelled horizontal bar chart.
///
/// ```text
/// Alpha   ████████████████████ 82
/// Beta    ███████████████      64
/// Gamma   ██████████           43
/// ```
///
/// Bars are measured in eighths of a character, so a value lands within an eighth
/// of a column rather than rounding to the nearest whole one.
class BarChart implements Renderable {
  /// Creates a bar chart over [series].
  ///
  /// [labels] names the categories — the positions along a series. In
  /// [BarMode.grouped] the series' own labels name the rows instead.
  const BarChart(
    this.series, {
    this.labels = const [],
    this.mode = BarMode.plain,
    this.width,
    this.theme = ChartTheme.plain,
    this.showValues = true,
    this.maxValue,
    this.title,
    this.valueFormat,
    this.track,
  });

  /// Convenience for the common case of one unnamed series.
  BarChart.of(
    List<num?> values, {
    List<String> labels = const [],
    int? width,
    ChartTheme theme = ChartTheme.plain,
    bool showValues = true,
    num? maxValue,
    String? title,
    NumberFormatter? valueFormat,
    String? track,
  }) : this(
         [Series(values)],
         labels: labels,
         width: width,
         theme: theme,
         showValues: showValues,
         maxValue: maxValue,
         title: title,
         valueFormat: valueFormat,
         track: track,
       );

  /// The data. One series for [BarMode.plain]; several for the other modes.
  final List<Series> series;

  /// Category names, one per position along a series.
  final List<String> labels;

  /// How several series share a row.
  final BarMode mode;

  /// Total width including labels and values. Defaults to the theme's.
  final int? width;

  /// Glyphs, colours and number formatting.
  final ChartTheme theme;

  /// Whether to print each bar's value after it.
  final bool showValues;

  /// Pins the top of the scale, so several charts can be compared.
  ///
  /// Without it each chart scales to its own largest bar, and a chart whose
  /// biggest value is 8 looks identical to one whose biggest is 8000.
  final num? maxValue;

  /// A heading printed above the chart.
  final String? title;

  /// How values are formatted. Defaults to the theme's formatter.
  final NumberFormatter? valueFormat;

  /// A glyph drawn in the unfilled part of each bar, such as `░`.
  ///
  /// Null leaves the remainder blank. A track makes the full extent visible, which
  /// matters when the bars are short.
  final String? track;

  @override
  List<String> renderLines() {
    if (series.isEmpty) return const [];
    final total = width ?? theme.defaultWidth;
    final format = valueFormat ?? theme.format;
    final chars = theme.charset;

    return switch (mode) {
      BarMode.plain => _renderPlain(total, format, chars),
      BarMode.grouped => _renderGrouped(total, format, chars),
      BarMode.stacked ||
      BarMode.percentStacked => _renderStacked(total, format, chars),
    };
  }

  int get _categoryCount =>
      series.fold(0, (m, s) => s.length > m ? s.length : m);

  List<String> _renderPlain(int total, NumberFormatter format, CharSet chars) {
    final values = series.first.values;
    final count = values.length;
    if (count == 0) return const [];

    // Bars always measure from zero. A bar chart whose baseline is not the origin
    // misrepresents its own lengths, because a bar's meaning is its length.
    final scale = LinearScale.fit(
      values,
      1,
      includeZero: true,
      mode: AxisMode.tight,
      max: maxValue,
    );

    return renderRowFrame(
      width: total,
      rowCount: count,
      theme: theme,
      title: title,
      labels: [
        for (var i = 0; i < count; i++) i < labels.length ? labels[i] : '',
      ],
      values: showValues
          ? [
              for (final v in values)
                v == null || !v.toDouble().isFinite ? '' : format(v),
            ]
          : const [],
      body: (row, body) {
        final eighths = _eighthsFor(values[row], scale, body.width);
        if (eighths < 0) return;
        drawBarEighths(
          body,
          eighths,
          chars: chars,
          style: theme.color
              ? series.first.style ?? theme.seriesStyle(0)
              : null,
          track: track,
          trackStyle: theme.color ? theme.trackStyle : null,
        );
      },
    );
  }

  List<String> _renderGrouped(
    int total,
    NumberFormatter format,
    CharSet chars,
  ) {
    // One row per (category, series) pair, so every bar keeps a full-width row.
    final categories = _categoryCount;
    final rows = <(int, int)>[];
    for (var c = 0; c < categories; c++) {
      for (var s = 0; s < series.length; s++) {
        rows.add((c, s));
      }
    }
    if (rows.isEmpty) return const [];

    final scale = LinearScale.fit(
      series.expand((s) => s.values),
      1,
      includeZero: true,
      mode: AxisMode.tight,
      max: maxValue,
    );

    num? valueAt((int, int) r) {
      final s = series[r.$2];
      return r.$1 < s.length ? s.values[r.$1] : null;
    }

    return renderRowFrame(
      width: total,
      rowCount: rows.length,
      theme: theme,
      title: title,
      labels: [
        for (final r in rows)
          // The series name labels the row; the category name appears once, on the
          // first row of its group, so the grouping is visible.
          r.$2 == 0
              ? (r.$1 < labels.length ? labels[r.$1] : '')
              : (series[r.$2].label ?? ''),
      ],
      values: showValues
          ? [
              for (final r in rows)
                () {
                  final v = valueAt(r);
                  return v == null || !v.toDouble().isFinite ? '' : format(v);
                }(),
            ]
          : const [],
      body: (row, body) {
        final r = rows[row];
        final eighths = _eighthsFor(valueAt(r), scale, body.width);
        if (eighths < 0) return;
        drawBarEighths(
          body,
          eighths,
          chars: chars,
          style: theme.color
              ? series[r.$2].style ?? theme.seriesStyle(r.$2)
              : null,
          track: track,
          trackStyle: theme.color ? theme.trackStyle : null,
        );
      },
    );
  }

  List<String> _renderStacked(
    int total,
    NumberFormatter format,
    CharSet chars,
  ) {
    final categories = _categoryCount;
    if (categories == 0) return const [];
    final percent = mode == BarMode.percentStacked;

    double rowTotal(int c) {
      var sum = 0.0;
      for (final s in series) {
        final v = c < s.length ? s.values[c] : null;
        if (v == null) continue;
        final d = v.toDouble();
        // A missing value in a stack IS zero — unlike in a line, where it is a
        // gap. A stack is a composition, and an absent part contributes nothing.
        if (d.isFinite && d > 0) sum += d;
      }
      return sum;
    }

    // Shared denominator for the plain stacked mode, so rows are comparable.
    var widest = 0.0;
    for (var c = 0; c < categories; c++) {
      final t = rowTotal(c);
      if (t > widest) widest = t;
    }
    if (maxValue != null) widest = maxValue!.toDouble();

    return renderRowFrame(
      width: total,
      rowCount: categories,
      theme: theme,
      title: title,
      labels: [
        for (var c = 0; c < categories; c++) c < labels.length ? labels[c] : '',
      ],
      values: showValues
          ? [
              for (var c = 0; c < categories; c++)
                percent ? '100%' : format(rowTotal(c)),
            ]
          : const [],
      body: (c, body) {
        final weights = [
          for (final s in series)
            () {
              final v = c < s.length ? s.values[c] : null;
              if (v == null) return 0.0;
              final d = v.toDouble();
              return d.isFinite && d > 0 ? d : 0.0;
            }(),
        ];
        final rowSum = weights.fold<double>(0, (a, b) => a + b);
        // An empty row stays empty rather than becoming 100% of series 0.
        if (!(rowSum > 0)) return;

        // How many cells this row's stack occupies. In percent mode always the
        // whole width; otherwise proportional to the widest row.
        final cells = percent
            ? body.width
            : (widest > 0 ? (rowSum / widest * body.width).round() : 0);

        // Largest-remainder apportionment, so the segments sum to exactly `cells`.
        // Rounding each independently leaves a one-cell hole in some rows and
        // overflows others — a bug that looks like a rendering glitch.
        final parts = apportion(cells.clamp(0, body.width), weights);
        var x = 0;
        for (var si = 0; si < parts.length; si++) {
          final glyph = series.length == 1
              ? chars.full
              : chars.shades[si % chars.shades.length];
          for (var i = 0; i < parts[si]; i++) {
            body.set(
              x + i,
              0,
              glyph,
              style: theme.color
                  ? series[si].style ?? theme.seriesStyle(si)
                  : null,
            );
          }
          x += parts[si];
        }
        if (track != null) {
          for (var i = x; i < body.width; i++) {
            body.set(
              i,
              0,
              track!,
              style: theme.color ? theme.trackStyle : null,
            );
          }
        }
      },
    );
  }

  /// The bar length for [value], or -1 when it cannot be drawn.
  ///
  /// A negative value draws nothing. Unicode's partial-block glyphs are all
  /// anchored to the *left* of their cell, so there is no way to draw a bar that
  /// grows leftward with sub-cell precision — and a negative bar drawn rightward
  /// would be a lie. Negative data belongs in a column chart, which has a baseline
  /// row to hang from.
  int _eighthsFor(num? value, LinearScale scale, int bodyWidth) {
    if (value == null) return -1;
    final d = value.toDouble();
    if (!d.isFinite || d < 0) return -1;
    return scale.withSize(bodyWidth).quantityEighths(d);
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}
