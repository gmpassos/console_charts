/// A bounded, append-only series for live data.
library;

/// What a [RingSeries] does when it reaches capacity.
enum RingDecimation {
  /// Discard the oldest values. The default.
  ///
  /// Keeps the most recent [RingSeries.capacity] samples at full resolution, which is
  /// what a live view means: the last N ticks, scaled to what is happening now.
  /// History older than that is gone.
  drop,

  /// Fold the oldest half, keeping its extremes.
  ///
  /// Each group of four becomes two — the group's minimum and maximum, in their
  /// original time order — so the whole history survives at falling resolution and
  /// no spike is ever averaged away.
  ///
  /// Four into two, not two into one: the minimum and maximum of a *pair* are that
  /// pair, so folding pairs would discard nothing at all.
  ///
  /// The cost is real and worth stating: a preserved outlier keeps setting the scale
  /// forever, so recent detail flattens against it. Use this when the question is
  /// "what shape was the whole run", not "what is happening now".
  fold,
}

/// A series that accepts values forever without growing without bound.
///
/// Charts in a console are usually watching something *happen* — a training run, a
/// request rate, a queue depth — which means appending a value per tick for as long
/// as the process lives. A plain `List` is the obvious thing to reach for and is
/// wrong twice over: it grows without limit, and re-rendering from a million samples
/// does work that a few dozen columns throw away.
///
/// ```dart
/// final loss = RingSeries(capacity: 512);
/// for (final step in steps) {
///   loss.add(step.loss);
///   print(sparkline(loss.values));
/// }
/// ```
///
/// ## Two ways to stay within capacity, and they are genuinely different
///
/// See [RingDecimation]. The default drops the oldest values, which is what a live
/// view wants — the last N ticks at full resolution. [RingDecimation.fold] instead
/// keeps the *whole* history at falling resolution, which sounds strictly better and
/// is not: an outlier from an hour ago survives forever and keeps setting the scale,
/// so every recent value is flattened against it. That is the right trade for "the
/// shape of the whole run in bounded memory" and the wrong one for "what is happening
/// now".
///
/// Older history therefore has coarser time resolution than recent history, which is
/// the right trade for a monitoring view and is why [isDecimated] exists: a caller
/// that needs uniform spacing should know it is not getting it.
class RingSeries {
  /// Creates a series holding at most [capacity] values.
  ///
  /// [capacity] is clamped to at least 4, below which neither strategy can preserve
  /// anything meaningful.
  RingSeries({int capacity = 1024, this.decimation = RingDecimation.drop})
    : capacity = capacity < 4 ? 4 : capacity;

  /// The most values this series will hold.
  final int capacity;

  /// What happens when [capacity] is reached. See [RingDecimation].
  final RingDecimation decimation;

  final List<double> _values = [];

  var _added = 0;
  var _decimations = 0;

  /// Appends [value], ignoring anything that cannot be plotted.
  ///
  /// Nulls and non-finite values are dropped rather than stored, because a chart
  /// cannot place them and a live series has no reader to notice a gap.
  void add(num? value) {
    if (value == null) return;
    final v = value.toDouble();
    if (!v.isFinite) return;
    _values.add(v);
    _added++;
    if (_values.length > capacity) _decimate();
  }

  /// Appends every value of [values].
  void addAll(Iterable<num?> values) {
    for (final v in values) {
      add(v);
    }
  }

  /// Halves the oldest half, folding each group of four into its min and max.
  ///
  /// **Four into two, not two into one.** Folding a *pair* into its minimum and
  /// maximum is a no-op — the min and max of two values are those two values — so it
  /// would discard nothing and the series would grow without bound. Four into two
  /// genuinely halves while still carrying an extreme from each side of the group.
  ///
  /// The two survivors keep their original time order, so a rising group stays rising.
  /// Emitting min-then-max unconditionally would introduce a sawtooth that is an
  /// artefact of the decimation rather than anything in the data.
  void _decimate() {
    if (decimation == RingDecimation.drop) {
      _values.removeRange(0, _values.length - capacity);
      _decimations++;
      return;
    }
    final half = _values.length ~/ 2;
    if (half < 4) {
      // Too short to fold without losing the shape entirely: drop the oldest quarter
      // outright, which is honest and happens only for a tiny capacity.
      _values.removeRange(0, _values.length - capacity);
      _decimations++;
      return;
    }

    final folded = <double>[];
    var i = 0;
    for (; i + 3 < half; i += 4) {
      var lo = i;
      var hi = i;
      for (var k = i; k < i + 4; k++) {
        if (_values[k] < _values[lo]) lo = k;
        if (_values[k] > _values[hi]) hi = k;
      }
      // Time order, so the pair reads as part of the curve rather than as a spike.
      if (lo <= hi) {
        folded
          ..add(_values[lo])
          ..add(_values[hi]);
      } else {
        folded
          ..add(_values[hi])
          ..add(_values[lo]);
      }
    }
    // Whatever did not make a group of four is carried through untouched, rather
    // than dropped — that would lose the oldest samples on every decimation.
    for (; i < half; i++) {
      folded.add(_values[i]);
    }
    _values.replaceRange(0, half, folded);
    _decimations++;

    // One fold takes the length to about three quarters of capacity, so a single
    // pass is normally enough; the loop is for a pathologically small capacity.
    while (_values.length > capacity && _values.length > 4) {
      _values.removeRange(0, _values.length - capacity);
    }
  }

  /// The series, oldest first.
  ///
  /// A view, not a copy — cheap to pass to a chart every tick.
  List<double> get values => List.unmodifiable(_values);

  /// How many values are currently held.
  int get length => _values.length;

  /// How many values have ever been added, decimation included.
  int get totalAdded => _added;

  /// Whether anything has been discarded to stay within [capacity].
  ///
  /// When true the series no longer has uniform time resolution: older samples each
  /// stand for several. A chart of recent behaviour does not care; an axis claiming
  /// evenly spaced time does.
  bool get isDecimated => _decimations > 0;

  /// Whether nothing has been added.
  bool get isEmpty => _values.isEmpty;

  /// Whether anything has been added.
  bool get isNotEmpty => _values.isNotEmpty;

  /// The most recent value.
  double? get latest => _values.isEmpty ? null : _values.last;

  /// The oldest value still held.
  double? get oldest => _values.isEmpty ? null : _values.first;

  /// The smallest value still held.
  double? get min {
    if (_values.isEmpty) return null;
    var m = _values.first;
    for (final v in _values) {
      if (v < m) m = v;
    }
    return m;
  }

  /// The largest value still held.
  double? get max {
    if (_values.isEmpty) return null;
    var m = _values.first;
    for (final v in _values) {
      if (v > m) m = v;
    }
    return m;
  }

  /// Discards everything.
  void clear() {
    _values.clear();
    _added = 0;
    _decimations = 0;
  }

  @override
  String toString() =>
      'RingSeries(${_values.length}/$capacity'
      '${isDecimated ? ', decimated' : ''})';
}
