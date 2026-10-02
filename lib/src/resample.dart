/// Fitting a series to the number of columns available to draw it.
///
/// A chart almost never has one column per data point. With more points than
/// columns something must be discarded, and *which* something is a correctness
/// question rather than a cosmetic one: averaging a training-loss curve into
/// twenty columns erases exactly the spike the reader is looking for, and the
/// result looks entirely plausible. With fewer points than columns, inventing
/// intermediate values is honest for a continuous line and dishonest for a bar.
library;

/// What a single column's worth of samples reduced to.
///
/// Carries several reductions at once because different charts need different
/// ones from the same bucketing pass: a line wants [first] and [last] to connect
/// through, a filled area wants [max], and a candle wants all four.
class ColumnSample {
  /// Creates a reduction. [count] is how many usable samples it came from.
  const ColumnSample({
    this.first,
    this.last,
    this.min,
    this.max,
    this.mean,
    this.count = 0,
  });

  /// A column with no usable samples — a gap.
  static const ColumnSample empty = ColumnSample();

  /// The earliest usable sample.
  final double? first;

  /// The latest usable sample.
  final double? last;

  /// The smallest usable sample.
  final double? min;

  /// The largest usable sample.
  final double? max;

  /// The arithmetic mean of the usable samples.
  final double? mean;

  /// How many samples were usable. Zero means this column is a gap.
  final int count;

  /// Whether this column has nothing to draw.
  bool get isEmpty => count == 0;

  /// The reduction [mode] selects.
  double? value(ResampleMode mode) => switch (mode) {
    ResampleMode.mean => mean,
    ResampleMode.min => min,
    ResampleMode.max => max,
    ResampleMode.first => first,
    ResampleMode.last => last,
    ResampleMode.extremes => _furthestFromMean,
  };

  /// Whichever of [min] and [max] sits further from [mean].
  double? get _furthestFromMean {
    if (min == null || max == null || mean == null) return null;
    return (mean! - min!).abs() >= (max! - mean!).abs() ? min : max;
  }

  @override
  String toString() =>
      'ColumnSample(min: $min, max: $max, mean: $mean, n: $count)';
}

/// How several samples falling in one column are reduced to a drawable value.
enum ResampleMode {
  /// The average. Representative, and smooths away spikes.
  mean,

  /// The lowest sample.
  min,

  /// The highest sample. What a monitoring chart usually wants.
  max,

  /// The earliest sample.
  first,

  /// The latest sample — the "current value" a dashboard shows.
  last,

  /// Whichever of the lowest and highest deviates further from the average.
  ///
  /// Keeps a spike visible in whichever direction it went, which a single-row
  /// chart like a sparkline cannot otherwise show. The cost is that the drawn
  /// value is a real sample but not a typical one.
  extremes,
}

/// Reduces [values] to exactly [columns] buckets.
///
/// Nulls and non-finite values are excluded from every reduction — they are
/// missing data, not zeroes. A bucket is a gap only when *all* of its samples are
/// missing, so one dropout in a dense series does not punch a visible hole.
///
/// Runs in a single pass, because a chart may be handed a hundred thousand points
/// and a per-bucket sort would dominate the render.
List<ColumnSample> bucketSamples(List<num?> values, int columns) {
  if (columns <= 0) return const [];
  final n = values.length;
  if (n == 0) return List<ColumnSample>.filled(columns, ColumnSample.empty);

  return List<ColumnSample>.generate(columns, (c) {
    final start = (c * n) ~/ columns;
    var end = ((c + 1) * n) ~/ columns;
    // With more columns than points, several columns map to the same index; give
    // each at least one sample rather than leaving holes between them.
    if (end <= start) end = start + 1;

    double? lo;
    double? hi;
    double? first;
    double? last;
    var sum = 0.0;
    var count = 0;
    for (var i = start; i < end && i < n; i++) {
      final raw = values[i];
      if (raw == null) continue;
      final v = raw.toDouble();
      if (!v.isFinite) continue;
      first ??= v;
      last = v;
      sum += v;
      count++;
      if (lo == null || v < lo) lo = v;
      if (hi == null || v > hi) hi = v;
    }
    if (count == 0) return ColumnSample.empty;
    return ColumnSample(
      first: first,
      last: last,
      min: lo,
      max: hi,
      mean: sum / count,
      count: count,
    );
  });
}

/// Reduces [values] to exactly [columns] drawable values, or nulls for gaps.
///
/// Combines [bucketSamples] with [mode]. When there are fewer values than
/// columns, [stretch] decides whether the gaps between them are interpolated.
List<double?> resample(
  List<num?> values,
  int columns, {
  ResampleMode mode = ResampleMode.mean,
  bool stretch = true,
}) {
  if (columns <= 0) return const [];
  if (values.isEmpty) return List<double?>.filled(columns, null);

  if (stretch && values.length < columns) {
    return interpolateToColumns(values, columns);
  }
  return bucketSamples(
    values,
    columns,
  ).map((s) => s.value(mode)).toList(growable: false);
}

/// Spreads [values] across [columns] by linear interpolation.
///
/// Used when a series is shorter than the space available, so a line fills the
/// plot rather than hugging the left edge.
///
/// **Never interpolates across a gap.** If either neighbour of a position is
/// missing, that position is missing too — bridging a gap would draw a line
/// through data that does not exist, which is the one thing a chart of missing data
/// must not do.
List<double?> interpolateToColumns(List<num?> values, int columns) {
  if (columns <= 0) return const [];
  final n = values.length;
  if (n == 0) return List<double?>.filled(columns, null);

  double? at(int i) {
    final raw = values[i];
    if (raw == null) return null;
    final v = raw.toDouble();
    return v.isFinite ? v : null;
  }

  if (n == 1 || columns == 1) {
    // A single column shows the last value, which is what a dashboard means by
    // "current". A single value fills every column.
    return n == 1
        ? List<double?>.filled(columns, at(0))
        : List<double?>.filled(columns, at(n - 1));
  }

  return List<double?>.generate(columns, (c) {
    final t = c * (n - 1) / (columns - 1);
    final lo = t.floor();
    final hi = t.ceil();
    final a = at(lo);
    if (lo == hi) return a;
    final b = at(hi);
    if (a == null || b == null) return null;
    return a + (b - a) * (t - lo);
  }, growable: false);
}

/// Picks [columns] of [values] by largest-triangle-three-buckets.
///
/// Keeps the points that contribute most to the series' visible shape, and emits
/// only values that are genuinely in the input — it never averages two samples
/// into one that was never measured. Endpoints are always kept.
///
/// It does **not** guarantee the extremes survive, so it is not the default for
/// data where a spike is the point. Use [ResampleMode.max] or
/// [ResampleMode.extremes] for that.
List<double?> largestTriangleThreeBuckets(List<num?> values, int columns) {
  final clean = <(int, double)>[];
  for (var i = 0; i < values.length; i++) {
    final raw = values[i];
    if (raw == null) continue;
    final v = raw.toDouble();
    if (v.isFinite) clean.add((i, v));
  }
  if (columns <= 0) return const [];
  if (clean.length <= columns || columns < 3) {
    return resample(values, columns, stretch: false);
  }

  final out = <double?>[clean.first.$2];
  final every = (clean.length - 2) / (columns - 2);
  var a = 0;
  for (var i = 0; i < columns - 2; i++) {
    final rangeStart = (((i + 1) * every).floor() + 1).clamp(
      0,
      clean.length - 1,
    );
    final rangeEnd = (((i + 2) * every).floor() + 1).clamp(0, clean.length);
    var avgX = 0.0;
    var avgY = 0.0;
    final span = rangeEnd - rangeStart;
    if (span > 0) {
      for (var k = rangeStart; k < rangeEnd; k++) {
        avgX += clean[k].$1;
        avgY += clean[k].$2;
      }
      avgX /= span;
      avgY /= span;
    }

    final from = ((i * every).floor() + 1).clamp(0, clean.length - 1);
    final to = (((i + 1) * every).floor() + 1).clamp(0, clean.length);
    var bestArea = -1.0;
    var best = from;
    final ax = clean[a].$1.toDouble();
    final ay = clean[a].$2;
    for (var k = from; k < to; k++) {
      final area =
          ((ax - avgX) * (clean[k].$2 - ay) - (ax - clean[k].$1) * (avgY - ay))
              .abs();
      if (area > bestArea) {
        bestArea = area;
        best = k;
      }
    }
    out.add(clean[best].$2);
    a = best;
  }
  out.add(clean.last.$2);
  return out;
}
