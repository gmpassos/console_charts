/// Mapping data values onto character cells, and choosing readable axis ticks.
library;

import 'dart:math' as math;

/// How a chart's domain relates to its data.
enum AxisMode {
  /// Round the domain outward to tick-friendly bounds.
  ///
  /// The default wherever an axis is labelled. Labels then land exactly on the
  /// top and bottom rows, which is the only way they can be truthful: a chart
  /// plotted against the raw minimum and maximum while labelled with rounded
  /// values is wrong by a fraction of a row at every tick.
  nice,

  /// Use the data's exact range.
  ///
  /// Fills the plot area completely, at the cost of labels like `3.7` and `27.1`.
  /// Right for compact output where there are too few rows for nice ticks.
  tight,
}

/// A tick step, kept as mantissa and exponent rather than just a value.
///
/// Carrying [exponent] is what makes label formatting reliable. Recovering the
/// decimal count from the step's *value* means `log10`, and `log10(0.001)` can
/// come back as `-3.0000000000000004`, whose floor is `-4` — one decimal too many,
/// for every label on the axis. The exponent is known exactly when the step is
/// chosen, so it is kept.
class NiceStep {
  /// Creates a step of `mantissa × 10^exponent`.
  const NiceStep(this.value, this.exponent);

  /// The step size.
  final double value;

  /// The power of ten the step was built from.
  final int exponent;

  /// How many decimal places a label at this step needs.
  ///
  /// Capped at 20, which is the most `toStringAsFixed` accepts — a domain around
  /// `1e-300` otherwise asks for 300 decimals and throws a `RangeError` from deep
  /// inside label formatting, a long way from the data that caused it.
  int get decimals => exponent >= 0 ? 0 : (-exponent).clamp(0, 20);

  @override
  String toString() => 'NiceStep($value, 1e$exponent)';
}

/// Maps a numeric domain onto a number of character cells.
///
/// Construct with [LinearScale.fit] to derive the domain from data, or directly
/// when the domain is already known.
class LinearScale {
  /// Creates a scale over [min]..[max] across [size] cells.
  const LinearScale(
    this.min,
    this.max,
    this.size, {
    this.step,
    this.logarithmic = false,
  });

  /// Creates a scale that positions values by their logarithm.
  ///
  /// For data that decays or grows by *factors* rather than by amounts — a training
  /// loss, a latency distribution, anything spanning more than about two orders of
  /// magnitude. On a linear axis a series falling 2.4 → 0.05 spends most of its life
  /// compressed into the bottom row or two, so a plateau in the tail — the thing a
  /// reader is watching for — is invisible. On a log axis a constant decay rate is a
  /// straight line and a plateau is a visible bend.
  ///
  /// Both bounds must be strictly positive, since the logarithm of zero is
  /// unbounded. [LinearScale.fitLog] derives them from data and takes care of that;
  /// this constructor clamps a non-positive bound up to a small positive value
  /// rather than producing a scale that returns NaN for everything.
  factory LinearScale.log(double min, double max, int size) {
    var lo = min;
    var hi = max;
    if (!(lo > 0)) lo = _logFloor;
    if (!(hi > lo)) hi = lo * 10;
    return LinearScale(lo, hi, size, logarithmic: true);
  }

  /// Fits a logarithmic domain to [values], ignoring anything non-positive.
  ///
  /// Values at or below zero cannot be placed on a log axis at all — they are
  /// excluded from the domain and [normalize] returns null for them, so they render
  /// as gaps. That is the honest outcome: a zero is not "very small" on a
  /// multiplicative axis, it is off the end of it.
  ///
  /// The bounds are rounded outward to whole powers of ten, which is what makes the
  /// ticks readable.
  factory LinearScale.fitLog(
    Iterable<num?> values,
    int size, {
    num? min,
    num? max,
  }) {
    double? lo;
    double? hi;
    for (final value in values) {
      if (value == null) continue;
      final v = value.toDouble();
      if (!v.isFinite || v <= 0) continue;
      if (lo == null || v < lo) lo = v;
      if (hi == null || v > hi) hi = v;
    }
    var bottom = min?.toDouble() ?? lo ?? 1.0;
    var top = max?.toDouble() ?? hi ?? 10.0;
    if (!(bottom > 0)) bottom = _logFloor;
    if (!(top > bottom)) top = bottom * 10;

    // Outward to whole decades, so every tick is a round power of ten.
    final loExp = (math.log(bottom) / math.ln10).floor();
    final hiExp = (math.log(top) / math.ln10).ceil();
    final decadeLo = math.pow(10, loExp).toDouble();
    final decadeHi = math.pow(10, hiExp).toDouble();
    return LinearScale(
      decadeLo.isFinite && decadeLo > 0 ? decadeLo : bottom,
      decadeHi.isFinite && decadeHi > bottom ? decadeHi : top,
      size,
      logarithmic: true,
    );
  }

  /// Whether positions are computed from the logarithm of a value.
  ///
  /// When true, [min] and [max] are guaranteed positive and values at or below zero
  /// return null from [normalize] — they are off the axis, not at the bottom of it.
  final bool logarithmic;

  /// The step the bounds were rounded to, when they were.
  ///
  /// Recorded rather than recomputed because recomputing it from the *rounded*
  /// domain can choose a different step than the one that did the rounding — the
  /// domain is wider than the data, and a wider span can cross a 1/2/5 boundary.
  /// The ticks would then not land on the domain's ends, which defeats the whole
  /// purpose of rounding them: the top and bottom labels would sit a fraction of a
  /// row away from the top and bottom rows.
  final NiceStep? step;

  /// The bottom of the domain.
  final double min;

  /// The top of the domain.
  final double max;

  /// How many cells the domain is spread across.
  final int size;

  /// Derives a domain from [values].
  ///
  /// Nulls and non-finite values are ignored — they are gaps, not data, and
  /// letting one into the domain calculation is the single most destructive thing
  /// that can happen to a chart. See [dataExtent].
  ///
  /// [includeZero] extends the domain to the origin, which bar charts require: a
  /// bar whose baseline is not zero misrepresents its own length.
  /// [mode] chooses whether the bounds are rounded outward.
  /// [min] and [max] override the derived bounds.
  factory LinearScale.fit(
    Iterable<num?> values,
    int size, {
    bool includeZero = false,
    AxisMode mode = AxisMode.nice,
    int maxTicks = 5,
    num? min,
    num? max,
  }) {
    final extent = dataExtent(values);
    var lo = min?.toDouble() ?? extent?.$1 ?? 0.0;
    var hi = max?.toDouble() ?? extent?.$2 ?? 1.0;

    if (includeZero) {
      if (lo > 0) lo = 0;
      if (hi < 0) hi = 0;
    }

    // A domain of zero width cannot be divided by. Pad it proportionally, or by a
    // half unit when the value is itself zero, so that a flat series renders down
    // the middle of the plot instead of dividing by zero or hugging an edge.
    if (!(hi > lo)) {
      final pad = lo.abs() > 0 ? lo.abs() * 0.05 : 0.5;
      lo -= pad;
      hi += pad;
    }

    NiceStep? step;
    if (mode == AxisMode.nice) {
      step = niceStep(hi - lo, maxTicks);
      final nice = niceBounds(lo, hi, maxTicks);
      lo = nice.$1;
      hi = nice.$2;
    }

    // Last line of defence: if the bounds went non-finite — an overflow from a
    // domain near the limits of a double — fall back to the unit interval rather
    // than emit a chart full of NaN.
    if (!lo.isFinite || !hi.isFinite || !(hi > lo)) {
      lo = 0;
      hi = 1;
      step = null;
    }
    return LinearScale(lo, hi, size, step: step);
  }

  /// A scale over the indices `0 .. count - 1`, for categorical data.
  factory LinearScale.index(int count, int size) =>
      LinearScale(0, count <= 1 ? 1 : (count - 1).toDouble(), size);

  /// This scale respread across [size] cells.
  ///
  /// Charts build a scale before they know the plot area, because the axis labels
  /// determine how much room is left; this rebinds it afterwards.
  LinearScale withSize(int size) =>
      LinearScale(min, max, size, step: step, logarithmic: logarithmic);

  /// The width of the domain.
  double get span => max - min;

  /// Whether zero falls inside the domain, so a baseline should be drawn.
  bool get spansZero => min <= 0 && max >= 0;

  /// Where [value] sits in the domain, from 0 at [min] to 1 at [max].
  ///
  /// Returns null for a value that cannot be placed — null, NaN or an infinity.
  /// Callers must treat that as a gap and draw nothing, which is the only honest
  /// rendering of a missing sample.
  ///
  /// Finite values are clamped, so a caller-supplied domain narrower than the data
  /// flattens outliers against an edge rather than drawing outside the plot.
  double? normalize(num? value) {
    if (value == null) return null;
    final v = value.toDouble();
    if (!v.isFinite) return null;
    if (!(max > min)) return 0.5;
    if (logarithmic) {
      // Off the axis rather than at the bottom of it: on a multiplicative scale a
      // zero is not a small number, and clamping it to the floor would draw a point
      // that claims a value the data does not have.
      if (v <= 0) return null;
      final lo = math.log(min);
      final span = math.log(max) - lo;
      if (!(span > 0)) return 0.5;
      final t = (math.log(v) - lo) / span;
      if (!t.isFinite) return null;
      return t < 0 ? 0 : (t > 1 ? 1 : t);
    }
    final t = (v - min) / (max - min);
    if (!t.isFinite) return null;
    return t < 0 ? 0 : (t > 1 ? 1 : t);
  }

  /// The cell index of [value] treated as a **point**, from 0 to [size] - 1.
  ///
  /// Returns -1 for an unplaceable value.
  ///
  /// Scales by `size - 1`, so the domain's top lands on the last cell. Line,
  /// scatter, candlestick and box charts all plot points and must use this; using
  /// [quantityEighths] instead would make the maximum value unreachable.
  int pointCell(num? value) {
    final t = normalize(value);
    if (t == null) return -1;
    return size <= 1 ? 0 : (t * (size - 1)).round();
  }

  /// The length of [value] treated as a **quantity**, in eighths of a cell.
  ///
  /// Returns -1 for an unplaceable value. The result runs 0 to `size * 8`.
  ///
  /// Scales by `size`, not `size - 1`, because a quantity fills area rather than
  /// marking a position: a bar at the top of the domain must fill every one of
  /// [size] cells. Bars, areas, histograms and gauges use this. Mixing the two up
  /// is visible either way — a bar one cell short, or a line that cannot reach
  /// the top row.
  int quantityEighths(num? value) {
    final t = normalize(value);
    if (t == null) return -1;
    return (t * size * 8).round();
  }

  /// The value at the centre of cell [cell].
  double valueOfCell(int cell) {
    if (size <= 1) return min;
    final t = cell / (size - 1);
    if (logarithmic) {
      final lo = math.log(min);
      return math.exp(lo + (math.log(max) - lo) * t);
    }
    return min + span * t;
  }

  /// Tick values spanning the domain, ascending.
  ///
  /// [maxTicks] is a hint, not a bound, though a tight one. The step is chosen so
  /// the *data's* span needs at most [maxTicks] ticks, and rounding the domain
  /// outward can then add at most one step at each end — so the result holds
  /// between 2 and `maxTicks + 2` values. Asking for an exact count and a readable
  /// step at the same time is not possible, and a readable step is worth more.
  ///
  /// When the domain was rounded, the recorded [step] is reused, which makes the
  /// first and last tick land exactly on [min] and [max].
  ///
  /// Each value is computed as `min + i * step` rather than by adding repeatedly,
  /// so error cannot accumulate along the axis.
  List<double> ticks(int maxTicks) {
    if (maxTicks < 2) return [min, max];
    if (logarithmic) return _logTicks(maxTicks);
    final s = step ?? niceStep(span, maxTicks);
    if (!(s.value > 0)) return [min, max];
    final out = <double>[];
    // A safety valve one above the proven bound, so it can never truncate a
    // legitimate axis — only a step that went wrong.
    final limit = maxTicks + 3;
    for (var i = 0; ; i++) {
      final v = min + i * s.value;
      if (v > max + s.value * 1e-9) break;
      out.add(v);
      if (out.length >= limit) break;
    }
    if (out.length < 2) return [min, max];
    return out;
  }

  /// Ticks for a logarithmic axis: powers of ten, thinned to fit.
  ///
  /// Decades first, because a log axis is read by its decades. If there are too few
  /// to label — a domain spanning less than two — the 2 and 5 mantissas are added,
  /// which keeps a narrow log axis from having only one tick on it. If there are too
  /// many, whole decades are skipped rather than crowding.
  List<double> _logTicks(int maxTicks) {
    final loExp = (math.log(min) / math.ln10).round();
    final hiExp = (math.log(max) / math.ln10).round();
    final decades = hiExp - loExp;
    if (decades < 1) return [min, max];

    if (decades + 1 <= maxTicks) {
      final out = <double>[];
      // Sub-decade mantissas only when there is room for all of them, otherwise the
      // axis ends up with an uneven mix of 1s and 5s that reads as a mistake.
      final withMantissas = (decades * 3 + 1) <= maxTicks;
      for (var e = loExp; e <= hiExp; e++) {
        final decade = math.pow(10, e).toDouble();
        out.add(decade);
        if (withMantissas && e < hiExp) {
          out.add(decade * 2);
          out.add(decade * 5);
        }
      }
      return out.where((v) => v >= min && v <= max * (1 + 1e-9)).toList();
    }

    final stride = (decades / (maxTicks - 1)).ceil();
    final out = <double>[];
    for (var e = loExp; e <= hiExp; e += stride) {
      out.add(math.pow(10, e).toDouble());
    }
    if (out.last < max * (1 - 1e-9)) out.add(max);
    return out;
  }

  /// The step [ticks] uses, for callers that need its [NiceStep.decimals].
  NiceStep tickStep(int maxTicks) =>
      step ?? (maxTicks < 2 ? const NiceStep(1, 0) : niceStep(span, maxTicks));

  @override
  String toString() =>
      'LinearScale($min..$max over $size${logarithmic ? ', log' : ''})';
}

/// The smallest positive bound a logarithmic scale falls back to.
///
/// Small enough never to clip real data, large enough that its logarithm is a long
/// way from underflow.
const double _logFloor = 1e-12;

/// The lowest and highest finite values in [values], or null if there are none.
///
/// Written as an explicit loop rather than `reduce(math.max)` **because
/// `math.max(1.0, double.nan)` is `NaN`**. A single NaN in a series would
/// otherwise make the whole domain NaN, every normalisation NaN, and the chart
/// silently blank — with no error anywhere to explain it.
(double, double)? dataExtent(Iterable<num?> values) {
  double? lo;
  double? hi;
  for (final value in values) {
    if (value == null) continue;
    final v = value.toDouble();
    if (!v.isFinite) continue;
    if (lo == null || v < lo) lo = v;
    if (hi == null || v > hi) hi = v;
  }
  return lo == null ? null : (lo, hi!);
}

/// A tick step for a domain of width [span], aiming for about [maxTicks] ticks.
///
/// Rounds to 1, 2 or 5 times a power of ten, which is what makes an axis read
/// 0/20/40/60/80/100 instead of 0/16.7/33.3/50.
///
/// The ideal step is rounded **up** to the next such number, never to the nearest
/// one. Rounding to the nearest is the textbook form and gives a marginally
/// prettier step, but it can round *down* — and a smaller step means *more* ticks
/// than were asked for. Since the tick budget is derived from how many rows are
/// available, overshooting it means labels that collide. A span of 1 with a budget
/// of 8 rounds 0.143 down to 0.1 and yields eleven ticks; rounding up gives 0.2 and
/// six.
NiceStep niceStep(double span, int maxTicks) {
  if (!span.isFinite || span <= 0 || maxTicks < 2) return const NiceStep(1, 0);
  return _niceNumber(span / (maxTicks - 1), round: false);
}

/// [lo] and [hi] rounded outward to multiples of a nice step.
(double, double) niceBounds(double lo, double hi, int maxTicks) {
  if (!lo.isFinite || !hi.isFinite || !(hi > lo)) return (lo, hi);
  final step = niceStep(hi - lo, maxTicks).value;
  if (!(step > 0)) return (lo, hi);
  final nLo = (lo / step).floorToDouble() * step;
  final nHi = (hi / step).ceilToDouble() * step;
  if (!nLo.isFinite || !nHi.isFinite || !(nHi > nLo)) return (lo, hi);
  return (nLo, nHi);
}

/// Rounds [x] to 1, 2, 5 or 10 times a power of ten.
///
/// With [round] the nearest such number is chosen; without it, the smallest one
/// that is at least [x].
NiceStep _niceNumber(double x, {required bool round}) {
  if (!x.isFinite || x <= 0) return const NiceStep(1, 0);
  var exp = (math.log(x) / math.ln10).floor();
  var frac = x / math.pow(10, exp);
  // `log` is not exact, so a power of ten can land just either side of the
  // boundary and leave the mantissa outside 1..10. Nudge it back rather than
  // trusting the logarithm.
  if (frac >= 10) {
    frac /= 10;
    exp += 1;
  } else if (frac < 1) {
    frac *= 10;
    exp -= 1;
  }
  final double mantissa = round
      ? (frac < 1.5
            ? 1
            : frac < 3
            ? 2
            : frac < 7
            ? 5
            : 10)
      : (frac <= 1
            ? 1
            : frac <= 2
            ? 2
            : frac <= 5
            ? 5
            : 10);
  return mantissa == 10
      ? NiceStep(math.pow(10, exp + 1).toDouble(), exp + 1)
      : NiceStep(mantissa * math.pow(10, exp), exp);
}

/// About one tick every three rows, which keeps an axis legible without crowding.
int maxTicksForHeight(int rows) => (1 + (rows - 1) ~/ 3).clamp(2, 11);

/// Apportions [total] cells across [weights] so the parts sum to exactly [total].
///
/// Uses the largest-remainder method: floor every share, then hand the leftover
/// cells to whichever parts lost most to rounding.
///
/// Stacked bars need this. Rounding each segment independently leaves a one-cell
/// gap at the end of some rows and overflows others by one, which looks like a
/// rendering bug and is one of the most commonly shipped flaws in text bar charts.
/// A chart cannot draw a boundary inside a cell, so the only question is which
/// segment gets the cell — and this answers it without ever losing or inventing one.
List<int> apportion(int total, List<double> weights) {
  final n = weights.length;
  if (n == 0 || total <= 0) return List<int>.filled(n, 0);

  var sum = 0.0;
  for (final w in weights) {
    if (w.isFinite && w > 0) sum += w;
  }
  // Every weight zero or unusable: nothing to apportion. Notably this is the
  // 100%-stacked row that sums to zero, where dividing would make the first
  // segment NaN and, after flooring, silently claim the whole row.
  if (!(sum > 0)) return List<int>.filled(n, 0);

  final shares = List<int>.filled(n, 0);
  final remainders = <(double, int)>[];
  var used = 0;
  for (var i = 0; i < n; i++) {
    final w = weights[i];
    final exact = (w.isFinite && w > 0) ? w / sum * total : 0.0;
    final whole = exact.floor();
    shares[i] = whole;
    used += whole;
    remainders.add((exact - whole, i));
  }

  // Descending by lost fraction; ties go to the earlier index so the result is
  // deterministic, which the golden tests depend on.
  remainders.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  for (var k = 0; used < total && k < remainders.length; k++) {
    shares[remainders[k].$2]++;
    used++;
  }
  return shares;
}
