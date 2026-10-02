import 'package:console_charts/src/scale.dart';
import 'package:test/test.dart';

void main() {
  group('dataExtent', () {
    test('finds the finite range', () {
      expect(dataExtent([3, 1, 4, 1, 5]), (1.0, 5.0));
    });

    test('is null when there is nothing finite', () {
      expect(dataExtent(<num?>[]), isNull);
      expect(dataExtent([null, null]), isNull);
      expect(dataExtent([double.nan, double.infinity]), isNull);
    });

    test('a single NaN does not poison the range', () {
      // The trap this function exists for. `[1, 2, 3].reduce(math.max)` with a NaN
      // in it returns NaN, because `math.max(1.0, double.nan)` is NaN — so the
      // domain, every normalisation and the whole chart would go blank with no
      // error to explain it.
      expect(dataExtent([1, 2, double.nan, 3]), (1.0, 3.0));
      expect(dataExtent([double.nan, 7]), (7.0, 7.0));
    });

    test('infinities are excluded, not clamped', () {
      expect(dataExtent([1, double.infinity, 5]), (1.0, 5.0));
      expect(dataExtent([double.negativeInfinity, 2]), (2.0, 2.0));
    });
  });

  group('niceStep and niceBounds', () {
    test('gives 0/20/40/60/80/100 for a 0..100 domain', () {
      // The headline requirement: an axis a human would have drawn.
      final scale = LinearScale.fit([0, 100], 10, maxTicks: 6);
      expect(scale.min, 0);
      expect(scale.max, 100);
      expect(scale.ticks(6), [0, 20, 40, 60, 80, 100]);
    });

    test('expands a ragged domain outward', () {
      final scale = LinearScale.fit([3.7, 91.2], 10, maxTicks: 6);
      expect(scale.min, lessThanOrEqualTo(3.7));
      expect(scale.max, greaterThanOrEqualTo(91.2));
      expect(scale.min, 0);
      expect(scale.max, 100);
    });

    test('handles a domain spanning zero', () {
      final (lo, hi) = niceBounds(-30, 70, 6);
      expect(lo, -40);
      expect(hi, 80);
    });

    test('handles an all-negative domain', () {
      final (lo, hi) = niceBounds(-95, -12, 5);
      expect(lo, -100);
      expect(hi, 0);
    });

    test('decimals come from the exponent, not a log of the value', () {
      // Recovering decimals via log10 can yield -3.0000000000000004, whose floor
      // is -4 — one decimal too many on every label of the axis.
      expect(niceStep(0.01, 11).decimals, 3);
      expect(niceStep(100, 6).decimals, 0);
      expect(niceStep(1, 6).decimals, 1);
    });

    test('survives a power-of-ten span, where log is inexact', () {
      for (final span in [0.001, 0.01, 0.1, 1.0, 10.0, 100.0, 1000.0, 1e6]) {
        final step = niceStep(span, 6);
        expect(step.value, greaterThan(0), reason: 'span $span');
        expect(step.value.isFinite, isTrue, reason: 'span $span');
      }
    });

    test('never returns a non-positive or non-finite step', () {
      for (final span in [0.0, -5.0, double.nan, double.infinity]) {
        expect(niceStep(span, 6).value, greaterThan(0), reason: 'span $span');
      }
    });

    test('a rounded domain puts its first and last tick on its own bounds', () {
      // The reason the step is recorded rather than recomputed. Recomputing from
      // the widened domain can pick a different step, and then the top label sits
      // a fraction of a row away from the top row.
      final bad = <String>[];
      for (var lo = -97; lo < 100; lo += 23) {
        for (var hi = lo + 1; hi < lo + 300; hi += 37) {
          for (final maxTicks in [3, 5, 8]) {
            final scale = LinearScale.fit([lo, hi], 10, maxTicks: maxTicks);
            final ticks = scale.ticks(maxTicks);
            final tol = scale.span * 1e-9;
            if ((ticks.first - scale.min).abs() > tol ||
                (ticks.last - scale.max).abs() > tol) {
              bad.add(
                'data $lo..$hi maxTicks $maxTicks -> domain '
                '${scale.min}..${scale.max} step ${scale.step?.value} '
                'ticks ${ticks.length} ${ticks.first}..${ticks.last}',
              );
            }
          }
        }
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
    });

    test('tick count stays within two and maxTicks + 2', () {
      for (var lo = -100; lo < 100; lo += 17) {
        for (var hi = lo + 1; hi < lo + 400; hi += 31) {
          for (final maxTicks in [2, 3, 5, 8, 11]) {
            final t = LinearScale.fit(
              [lo, hi],
              10,
              maxTicks: maxTicks,
            ).ticks(maxTicks);
            expect(t.length, greaterThanOrEqualTo(2));
            expect(
              t.length,
              lessThanOrEqualTo(maxTicks + 2),
              reason: '$lo..$hi at $maxTicks gave ${t.length}',
            );
          }
        }
      }
    });

    test('ticks are strictly ascending with no accumulated drift', () {
      final ticks = LinearScale.fit([0, 1], 10, maxTicks: 11).ticks(11);
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i], greaterThan(ticks[i - 1]));
      }
    });
  });

  group('degenerate domains', () {
    test(
      'all values identical pads around them instead of dividing by zero',
      () {
        final scale = LinearScale.fit([7, 7, 7], 10);
        expect(scale.span, greaterThan(0));
        // A flat series belongs down the middle, not pinned to an edge.
        expect(scale.normalize(7), closeTo(0.5, 0.25));
      },
    );

    test('all zeros still yields a usable domain', () {
      final scale = LinearScale.fit([0, 0], 10);
      expect(scale.span, greaterThan(0));
      expect(scale.normalize(0), isNotNull);
    });

    test('empty input yields a unit domain rather than throwing', () {
      final scale = LinearScale.fit(<num?>[], 10);
      expect(scale.span, greaterThan(0));
      expect(scale.min.isFinite, isTrue);
      expect(scale.max.isFinite, isTrue);
    });

    test('a single point yields a domain containing it', () {
      final scale = LinearScale.fit([42], 10);
      expect(scale.min, lessThanOrEqualTo(42));
      expect(scale.max, greaterThanOrEqualTo(42));
      expect(scale.span, greaterThan(0));
    });
  });

  group('normalize', () {
    final scale = const LinearScale(0, 100, 10);

    test('maps the domain onto zero to one', () {
      expect(scale.normalize(0), 0);
      expect(scale.normalize(50), 0.5);
      expect(scale.normalize(100), 1);
    });

    test('returns null for values that cannot be placed', () {
      // Null, not 0 — a gap must be drawn as a gap, and 0 would plot a fake point
      // at the bottom of the chart.
      expect(scale.normalize(null), isNull);
      expect(scale.normalize(double.nan), isNull);
      expect(scale.normalize(double.infinity), isNull);
      expect(scale.normalize(double.negativeInfinity), isNull);
    });

    test('clamps values outside the domain', () {
      expect(scale.normalize(-50), 0);
      expect(scale.normalize(150), 1);
    });
  });

  group('point versus quantity mapping', () {
    test('a point at the top of the domain reaches the last cell', () {
      // Scaled by size - 1. Using the quantity rule here would put the maximum
      // beyond the last row, so the top value could never be drawn.
      const scale = LinearScale(0, 10, 5);
      expect(scale.pointCell(10), 4);
      expect(scale.pointCell(0), 0);
    });

    test('a quantity at the top of the domain fills every cell', () {
      // Scaled by size. Using the point rule here would leave a full-value bar one
      // cell short of the top.
      const scale = LinearScale(0, 10, 5);
      expect(scale.quantityEighths(10), 5 * 8);
      expect(scale.quantityEighths(0), 0);
      expect(scale.quantityEighths(5), 20);
    });

    test('both report -1 for an unplaceable value', () {
      const scale = LinearScale(0, 10, 5);
      expect(scale.pointCell(double.nan), -1);
      expect(scale.quantityEighths(null), -1);
    });
  });

  group('apportion', () {
    test('parts always sum to the total', () {
      // The property that makes stacked bars correct: no lost cell leaving a gap,
      // no extra cell overflowing the row.
      for (final total in [0, 1, 3, 7, 10, 40, 61]) {
        for (final weights in [
          [1.0],
          [1.0, 1.0],
          [1.0, 2.0, 3.0],
          [0.1, 0.1, 0.1],
          [99.0, 0.5, 0.5],
          [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        ]) {
          final parts = apportion(total, weights);
          expect(
            parts.fold<int>(0, (a, b) => a + b),
            total,
            reason: 'total $total weights $weights gave $parts',
          );
          expect(parts.every((p) => p >= 0), isTrue);
        }
      }
    });

    test('three equal weights over ten cells give 4/3/3, not 3/3/3', () {
      expect(apportion(10, [1, 1, 1]), [4, 3, 3]);
    });

    test('a zero total row apportions nothing', () {
      // The 100%-stacked trap: dividing by a zero row total makes the first share
      // NaN, and `NaN.floor()` plus a leftover pass can hand it the entire row.
      expect(apportion(10, [0, 0, 0]), [0, 0, 0]);
      expect(apportion(0, [1, 2]), [0, 0]);
    });

    test('non-finite weights are ignored, not propagated', () {
      final parts = apportion(10, [double.nan, 1, double.infinity, 1]);
      expect(parts.fold<int>(0, (a, b) => a + b), 10);
      expect(parts[0], 0);
      expect(parts[2], 0);
    });

    test('is deterministic when remainders tie', () {
      expect(apportion(10, [1, 1, 1]), apportion(10, [1, 1, 1]));
      expect(apportion(4, [1, 1, 1]), [2, 1, 1]);
    });
  });
}
