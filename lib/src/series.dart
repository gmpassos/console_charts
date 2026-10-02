/// The data a chart draws.
library;

import 'style.dart';

/// A named list of values, with optional per-series styling.
///
/// A `null` entry is **missing data**, not zero. Every chart here treats the two
/// differently: a gap breaks a line and leaves a column blank, where a zero is
/// plotted at the baseline. Conflating them invents data, and in a loss curve or an
/// error count the invented value is usually the most alarming point on the chart.
class Series {
  /// Creates a series over [values].
  const Series(this.values, {this.label, this.style, this.glyph});

  /// The values, in order. Nulls are gaps.
  final List<num?> values;

  /// A short name, used in legends and row labels.
  final String? label;

  /// Overrides the colour this series would take from the theme's palette.
  final AnsiStyle? style;

  /// Overrides the marker glyph, for scatter plots and multi-series lines.
  final String? glyph;

  /// How many values there are, gaps included.
  int get length => values.length;

  /// Whether there is nothing to draw.
  bool get isEmpty => values.isEmpty;

  /// The last value that can actually be plotted, or null if there is none.
  ///
  /// Used for the "current value" a dashboard prints beside a sparkline. Skips
  /// trailing gaps, because a series whose newest sample failed to arrive should
  /// still report the last one that did rather than showing nothing.
  double? get latestFinite {
    for (var i = values.length - 1; i >= 0; i--) {
      final v = values[i];
      if (v == null) continue;
      final d = v.toDouble();
      if (d.isFinite) return d;
    }
    return null;
  }

  /// This series with the given properties replaced.
  Series copyWith({
    List<num?>? values,
    String? label,
    AnsiStyle? style,
    String? glyph,
  }) => Series(
    values ?? this.values,
    label: label ?? this.label,
    style: style ?? this.style,
    glyph: glyph ?? this.glyph,
  );

  @override
  String toString() => 'Series(${label ?? 'unnamed'}, ${values.length} values)';
}

/// A point in data space, for charts whose x values are not an index.
class DataPoint {
  /// Creates a point at ([x], [y]).
  const DataPoint(this.x, this.y);

  /// The horizontal position, in data units.
  final double x;

  /// The vertical position, in data units.
  final double y;

  /// Whether this point can be plotted at all.
  bool get isFinite => x.isFinite && y.isFinite;

  @override
  String toString() => '($x, $y)';
}

/// A named list of [DataPoint]s, for scatter plots.
///
/// Distinct from [Series] because the data genuinely differs: a series' x values
/// are its indices, where these are independent. Bending one type to cover both
/// would mean every chart checking which kind it had.
class XYSeries {
  /// Creates a series of points.
  const XYSeries(this.points, {this.label, this.style, this.glyph});

  /// The points, in any order — charts that need them sorted sort a copy.
  final List<DataPoint> points;

  /// A short name, used in legends.
  final String? label;

  /// Overrides the colour from the theme's palette.
  final AnsiStyle? style;

  /// Overrides the marker glyph.
  final String? glyph;

  /// Builds a series from parallel x and y lists, skipping unusable pairs.
  ///
  /// Lists of different lengths are truncated to the shorter, rather than
  /// throwing: a caller plotting live data may legitimately have one more x than y.
  factory XYSeries.fromLists(
    List<num> xs,
    List<num> ys, {
    String? label,
    AnsiStyle? style,
    String? glyph,
  }) {
    final n = xs.length < ys.length ? xs.length : ys.length;
    final points = <DataPoint>[];
    for (var i = 0; i < n; i++) {
      final p = DataPoint(xs[i].toDouble(), ys[i].toDouble());
      if (p.isFinite) points.add(p);
    }
    return XYSeries(points, label: label, style: style, glyph: glyph);
  }

  /// Whether there is nothing to draw.
  bool get isEmpty => points.isEmpty;

  @override
  String toString() =>
      'XYSeries(${label ?? 'unnamed'}, ${points.length} points)';
}
