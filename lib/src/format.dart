/// Turning numbers into short, readable labels.
///
/// Axis ticks and bar values are the places a chart is most likely to embarrass
/// itself. `(0.1 + 0.2).toString()` is `0.30000000000000004`, and a y-axis showing
/// that is both wrong-looking and wide enough to shove the plot sideways. Every
/// formatter here goes through a fixed number of decimals and then strips what it
/// does not need, which cannot produce that.
library;

/// A sensible label for [value], without configuration.
///
/// The rules, in order:
///
/// * `NaN` and infinities get short symbolic labels rather than Dart's spellings,
///   because a chart axis has no room for `-Infinity`.
/// * A whole number never shows a decimal point: `5.0` is `5`.
/// * Very large or very small magnitudes go to exponential, since `0.0000123` is
///   both unreadable and wide.
/// * Otherwise decimals scale with magnitude — more precision for small numbers,
///   less for large — and trailing zeros are dropped.
String formatAuto(num value) {
  if (value is int) return '$value';
  final v = value.toDouble();
  if (v.isNaN) return 'NaN';
  if (v.isInfinite) return v.isNegative ? '-∞' : '∞';
  if (v == 0) return '0';
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toStringAsFixed(0);
  }
  final a = v.abs();
  if (a >= 1e7 || a < 1e-4) return _stripZeros(v.toStringAsExponential(2));
  if (a >= 100) return _stripZeros(v.toStringAsFixed(1));
  if (a >= 1) return _stripZeros(v.toStringAsFixed(2));
  return _stripZeros(v.toStringAsFixed(4));
}

/// A formatter showing exactly [digits] decimals, trailing zeros kept.
///
/// Use when a column of numbers must line up on the decimal point; [formatAuto]
/// strips zeros and so produces ragged columns.
NumberFormat formatFixed(int digits) => (num v) {
  final d = v.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d.isNegative ? '-∞' : '∞';
  return d.toStringAsFixed(digits);
};

/// A short label using a magnitude suffix: `1.2k`, `3.4M`, `5G`.
///
/// For counters big enough that the exact value is noise — request counts, token
/// throughput, byte totals. Uses powers of 1000, not 1024.
String formatCompact(num value) {
  final v = value.toDouble();
  if (v.isNaN) return 'NaN';
  if (v.isInfinite) return v.isNegative ? '-∞' : '∞';
  final a = v.abs();
  if (a < 1000) return formatAuto(v);
  const suffixes = ['k', 'M', 'G', 'T', 'P'];
  var scaled = a;
  var tier = -1;
  while (scaled >= 1000 && tier < suffixes.length - 1) {
    scaled /= 1000;
    tier++;
  }
  final sign = v.isNegative ? '-' : '';
  // One decimal below 10 so 1.2k keeps its precision, none above so 123k stays
  // narrow — the point of this formatter is width.
  final text = scaled < 10
      ? _stripZeros(scaled.toStringAsFixed(1))
      : scaled.toStringAsFixed(0);
  return '$sign$text${suffixes[tier]}';
}

/// A percentage label from a *fraction*: `0.82` becomes `82%`.
///
/// Takes 0..1 rather than 0..100 because that is what a gauge or a progress bar
/// already has. Pass [digits] for sub-percent precision.
NumberFormat formatPercent({int digits = 0}) => (num v) {
  final d = v.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d.isNegative ? '-∞' : '∞';
  return '${(d * 100).toStringAsFixed(digits)}%';
};

/// A label with [unit] appended: `formatWithUnit('ms')` gives `12.4ms`.
NumberFormat formatWithUnit(String unit, {NumberFormat? base}) {
  final inner = base ?? formatAuto;
  return (num v) => '${inner(v)}$unit';
}

/// The signature of every formatter here. Mirrors `NumberFormatter` in `theme.dart`.
typedef NumberFormat = String Function(num value);

/// Removes a trailing `.000` or `.50`-style zero run, and a bare trailing point.
///
/// Operates on the text, not the number, so it cannot reintroduce float error.
/// Leaves exponential notation's exponent alone: only the mantissa is trimmed.
String _stripZeros(String s) {
  if (!s.contains('.')) return s;
  final e = s.indexOf('e');
  if (e >= 0) {
    final mantissa = _stripZeros(s.substring(0, e));
    return '$mantissa${s.substring(e)}';
  }
  var end = s.length;
  while (end > 0 && s[end - 1] == '0') {
    end--;
  }
  if (end > 0 && s[end - 1] == '.') end--;
  return s.substring(0, end);
}
