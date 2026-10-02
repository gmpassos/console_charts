/// Summary statistics for the charts that need them.
library;

import 'dart:math' as math;

/// The finite values of [values], sorted ascending.
///
/// Non-finite values are removed **before** sorting, which is the whole point of
/// this function existing. `double.nan.compareTo(1.0)` returns 1, so NaN sorts to
/// the end of a list rather than being rejected — and every quantile computed from
/// that list is then silently wrong, with the corruption worst at the high
/// percentiles a box plot cares most about.
List<double> finiteSorted(Iterable<num?> values) {
  final out = <double>[];
  for (final value in values) {
    if (value == null) continue;
    final v = value.toDouble();
    if (v.isFinite) out.add(v);
  }
  out.sort();
  return out;
}

/// The [p]th quantile of [sorted], with `p` from 0 to 1.
///
/// Uses the R-7 method — linear interpolation between the two closest ranks, with
/// `h = (n - 1) * p`. That is what NumPy, R and most spreadsheets do by default, so
/// a box plot drawn here agrees with the numbers a reader computed elsewhere. There
/// are nine conventional definitions and they disagree by more than rounding on
/// small samples, so the choice is documented rather than implicit.
///
/// [sorted] must already be ascending and finite; see [finiteSorted].
double quantile(List<double> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  if (sorted.length == 1) return sorted.first;
  final h = (sorted.length - 1) * p.clamp(0.0, 1.0);
  final lo = h.floor();
  final hi = h.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] + (h - lo) * (sorted[hi] - sorted[lo]);
}

/// A five-number summary with its outliers separated out.
class BoxStats {
  /// Creates a summary directly.
  const BoxStats({
    required this.low,
    required this.q1,
    required this.median,
    required this.q3,
    required this.high,
    this.outliers = const [],
    this.label,
  });

  /// Summarises [values].
  ///
  /// With [fences], the whiskers stop at the most extreme value still within 1.5
  /// interquartile ranges of the box — Tukey's rule — and anything beyond becomes an
  /// [outliers] entry. Without it the whiskers reach the true extremes.
  ///
  /// An empty input yields a summary of NaNs, which every chart here treats as
  /// nothing to draw. That is deliberate: a metric with no samples yet is a normal
  /// state for a dashboard, not an error.
  factory BoxStats.of(
    Iterable<num?> values, {
    bool fences = true,
    String? label,
  }) {
    final sorted = finiteSorted(values);
    if (sorted.isEmpty) {
      return BoxStats(
        low: double.nan,
        q1: double.nan,
        median: double.nan,
        q3: double.nan,
        high: double.nan,
        label: label,
      );
    }
    final q1 = quantile(sorted, 0.25);
    final q3 = quantile(sorted, 0.75);
    final median = quantile(sorted, 0.5);
    if (!fences) {
      return BoxStats(
        low: sorted.first,
        q1: q1,
        median: median,
        q3: q3,
        high: sorted.last,
        label: label,
      );
    }
    final iqr = q3 - q1;
    final lowFence = q1 - 1.5 * iqr;
    final highFence = q3 + 1.5 * iqr;
    var low = sorted.last;
    var high = sorted.first;
    final outliers = <double>[];
    for (final v in sorted) {
      if (v < lowFence || v > highFence) {
        outliers.add(v);
      } else {
        if (v < low) low = v;
        if (v > high) high = v;
      }
    }
    // Every sample outside the fences: fall back to the true extremes rather than
    // emitting a box with inverted bounds.
    if (low > high) {
      low = sorted.first;
      high = sorted.last;
    }
    return BoxStats(
      low: low,
      q1: q1,
      median: median,
      q3: q3,
      high: high,
      outliers: outliers,
      label: label,
    );
  }

  /// The lower whisker's end.
  final double low;

  /// The first quartile — the box's lower edge.
  final double q1;

  /// The median.
  final double median;

  /// The third quartile — the box's upper edge.
  final double q3;

  /// The upper whisker's end.
  final double high;

  /// Values beyond the whiskers.
  final List<double> outliers;

  /// A short name for this distribution.
  final String? label;

  /// The interquartile range.
  double get iqr => q3 - q1;

  /// Whether there is anything to draw.
  bool get isEmpty => !median.isFinite;

  /// Every value this summary needs plotted, for deriving a domain.
  Iterable<double> get extent => [low, q1, median, q3, high, ...outliers];

  @override
  String toString() =>
      'BoxStats(${label ?? ''} $low/$q1/$median/$q3/$high'
      '${outliers.isEmpty ? '' : ', ${outliers.length} outliers'})';
}

/// One bar of a histogram.
class HistogramBin {
  /// Creates a bin covering [start] up to [end] holding [count] samples.
  const HistogramBin(this.start, this.end, this.count);

  /// The bin's lower bound, inclusive.
  final double start;

  /// The bin's upper bound — exclusive, except for the last bin of a set.
  final double end;

  /// How many samples fell in it.
  final int count;

  /// The bin's midpoint, which is what labels it.
  double get centre => (start + end) / 2;

  @override
  String toString() => 'HistogramBin($start..$end: $count)';
}

/// Sorts [values] into [binCount] equal-width bins.
///
/// Bins are half-open — `[start, end)` — **except the last, which is closed**, so
/// the largest sample lands in a bin instead of being silently dropped. That
/// off-by-one is the classic histogram bug, and it hides well: the chart looks
/// right and the total is one short.
///
/// With [binCount] null or non-positive the count is chosen automatically by the
/// Freedman–Diaconis rule, which adapts to spread rather than only to sample size,
/// falling back to Sturges' rule when the interquartile range is zero.
List<HistogramBin> histogramBins(
  Iterable<num?> values, {
  int? binCount,
  num? min,
  num? max,
}) {
  final sorted = finiteSorted(values);
  if (sorted.isEmpty) return const [];

  final lo = min?.toDouble() ?? sorted.first;
  final hi = max?.toDouble() ?? sorted.last;
  if (!(hi > lo)) {
    // Every sample identical: one bin holding all of them, rather than a division
    // by a zero width.
    return [HistogramBin(lo, lo, sorted.length)];
  }

  final count = (binCount != null && binCount > 0)
      ? binCount
      : _autoBinCount(sorted);
  final width = (hi - lo) / count;
  final counts = List<int>.filled(count, 0);
  for (final v in sorted) {
    if (v < lo || v > hi) continue;
    var index = ((v - lo) / width).floor();
    // The closed last bin.
    if (index >= count) index = count - 1;
    if (index < 0) index = 0;
    counts[index]++;
  }
  return [
    for (var i = 0; i < count; i++)
      HistogramBin(lo + i * width, lo + (i + 1) * width, counts[i]),
  ];
}

/// Freedman–Diaconis bin count, falling back to Sturges.
int _autoBinCount(List<double> sorted) {
  final n = sorted.length;
  if (n < 2) return 1;
  final iqr = quantile(sorted, 0.75) - quantile(sorted, 0.25);
  final span = sorted.last - sorted.first;
  if (iqr > 0 && span > 0) {
    final binWidth = 2 * iqr / math.pow(n, 1 / 3);
    if (binWidth > 0) {
      final count = (span / binWidth).ceil();
      if (count > 0) return count.clamp(1, 100);
    }
  }
  // Sturges: fine when the distribution is roughly normal, and a safe fallback when
  // the interquartile range degenerates.
  return ((math.log(n) / math.ln2).ceil() + 1).clamp(1, 100);
}
