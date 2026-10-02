/// Monotone cubic interpolation, for smoothing a line without inventing peaks.
library;

import 'dart:math' as math;

/// Interpolates [values] onto [columns] evenly spaced positions.
///
/// Uses Fritsch–Carlson monotone cubic Hermite interpolation, **not** a natural
/// cubic spline. The difference matters and is not cosmetic: a natural spline
/// overshoots near a sharp bend, so a decaying loss curve that approaches zero gets
/// drawn dipping *below* zero. That looks exactly like a rendering bug, and on a
/// chart of a quantity that cannot be negative it is one. A monotone interpolant
/// cannot overshoot: between two samples it stays within their range.
///
/// Gaps are respected. A null or non-finite sample splits the series, each run is
/// interpolated on its own, and the positions between runs stay null — the same rule
/// the rest of the package follows, because bridging a gap draws data that was never
/// measured.
List<double?> monotoneResample(List<num?> values, int columns) {
  if (columns <= 0) return const [];
  if (values.isEmpty) return List<double?>.filled(columns, null);

  // Usable samples, keeping their original positions so the x spacing is right.
  final xs = <double>[];
  final ys = <double>[];
  for (var i = 0; i < values.length; i++) {
    final raw = values[i];
    if (raw == null) continue;
    final v = raw.toDouble();
    if (!v.isFinite) continue;
    xs.add(i.toDouble());
    ys.add(v);
  }
  if (xs.isEmpty) return List<double?>.filled(columns, null);
  if (xs.length == 1) return List<double?>.filled(columns, ys.first);

  final slopes = _monotoneSlopes(xs, ys);
  final lastIndex = (values.length - 1).toDouble();

  return List<double?>.generate(columns, (c) {
    final x = columns == 1 ? lastIndex : c * lastIndex / (columns - 1);
    return _evaluate(xs, ys, slopes, x);
  }, growable: false);
}

/// Tangents at each sample, limited so the interpolant cannot overshoot.
List<double> _monotoneSlopes(List<double> xs, List<double> ys) {
  final n = xs.length;
  final secants = List<double>.generate(
    n - 1,
    (i) => (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]),
  );
  final m = List<double>.filled(n, 0);
  m[0] = secants.first;
  m[n - 1] = secants.last;
  for (var i = 1; i < n - 1; i++) {
    // A sign change means a local extremum, and a zero tangent there is what stops
    // the curve from sailing past it.
    m[i] = secants[i - 1] * secants[i] <= 0
        ? 0
        : (secants[i - 1] + secants[i]) / 2;
  }

  // Fritsch–Carlson limiter: keep each tangent inside the circle of radius 3 that
  // guarantees monotonicity on the interval.
  for (var i = 0; i < n - 1; i++) {
    final s = secants[i];
    if (s == 0) {
      m[i] = 0;
      m[i + 1] = 0;
      continue;
    }
    final a = m[i] / s;
    final b = m[i + 1] / s;
    final sum = a * a + b * b;
    if (sum > 9) {
      final t = 3 / math.sqrt(sum);
      m[i] = t * a * s;
      m[i + 1] = t * b * s;
    }
  }
  return m;
}

/// The interpolated value at [x], or null if [x] lies in a gap.
double? _evaluate(
  List<double> xs,
  List<double> ys,
  List<double> slopes,
  double x,
) {
  if (x <= xs.first) return ys.first;
  if (x >= xs.last) return ys.last;

  // Binary search for the interval containing x.
  var lo = 0;
  var hi = xs.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) ~/ 2;
    if (xs[mid] <= x) {
      lo = mid;
    } else {
      hi = mid;
    }
  }

  // Samples more than one position apart mean the data between them was missing.
  // Interpolating across that would bridge a gap, so it stays a gap.
  if (xs[hi] - xs[lo] > 1.0 + 1e-9) return null;

  final h = xs[hi] - xs[lo];
  final t = (x - xs[lo]) / h;
  final t2 = t * t;
  final t3 = t2 * t;
  return (2 * t3 - 3 * t2 + 1) * ys[lo] +
      (t3 - 2 * t2 + t) * h * slopes[lo] +
      (-2 * t3 + 3 * t2) * ys[hi] +
      (t3 - t2) * h * slopes[hi];
}
