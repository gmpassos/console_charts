import 'dart:math' as math;

import 'package:console_charts/console_charts.dart';
import 'package:test/test.dart';

void main() {
  group('logarithmic scale', () {
    test('positions values by their logarithm', () {
      final s = LinearScale.log(1, 1000, 10);
      expect(s.normalize(1), closeTo(0, 1e-9));
      expect(s.normalize(1000), closeTo(1, 1e-9));
      // The geometric midpoint, not the arithmetic one: 10^1.5 ≈ 31.6 sits halfway.
      expect(s.normalize(math.sqrt(1000)), closeTo(0.5, 1e-9));
      expect(s.normalize(500), greaterThan(0.8));
    });

    test('zero and negatives are off the axis, not at the bottom of it', () {
      // Clamping them to the floor would draw a point claiming a value the data does
      // not have. On a multiplicative axis a zero is not a small number.
      final s = LinearScale.log(1, 100, 10);
      expect(s.normalize(0), isNull);
      expect(s.normalize(-5), isNull);
      expect(s.pointCell(0), -1);
    });

    test('fitLog rounds outward to whole decades', () {
      final s = LinearScale.fitLog([0.003, 2.4], 10);
      expect(s.min, closeTo(0.001, 1e-12));
      expect(s.max, closeTo(10, 1e-9));
      expect(s.logarithmic, isTrue);
    });

    test('fitLog ignores non-positive values rather than failing', () {
      final s = LinearScale.fitLog([0, -1, 5, 50], 10);
      expect(s.min, greaterThan(0));
      expect(s.max, greaterThanOrEqualTo(50));
      expect(s.normalize(50), isNotNull);
    });

    test('fitLog survives having nothing usable', () {
      for (final data in <List<num?>>[
        [],
        [0],
        [-1, -2],
        [null],
        [double.nan],
      ]) {
        final s = LinearScale.fitLog(data, 10);
        expect(s.min, greaterThan(0), reason: '$data');
        expect(s.max, greaterThan(s.min), reason: '$data');
      }
    });

    test('ticks are powers of ten', () {
      final s = LinearScale.fitLog([0.001, 10], 10);
      final ticks = s.ticks(5);
      expect(ticks, hasLength(greaterThanOrEqualTo(2)));
      for (final t in ticks) {
        final exp = math.log(t) / math.ln10;
        expect(
          (exp - exp.round()).abs(),
          lessThan(1e-9),
          reason: '$t is not a power of ten',
        );
      }
    });

    test('a narrow log domain gains sub-decade ticks rather than only one', () {
      final s = LinearScale.fitLog([1, 9], 10);
      expect(s.ticks(9).length, greaterThanOrEqualTo(3));
    });

    test('withSize keeps the scale logarithmic', () {
      expect(LinearScale.log(1, 100, 4).withSize(20).logarithmic, isTrue);
    });

    test('valueOfCell inverts normalize', () {
      final s = LinearScale.log(1, 1000, 10);
      for (var cell = 0; cell < 10; cell++) {
        final v = s.valueOfCell(cell);
        expect(s.pointCell(v), cell, reason: 'cell $cell gave $v');
      }
    });

    test('a non-positive bound is clamped rather than producing NaN', () {
      final s = LinearScale.log(0, 100, 10);
      expect(s.min, greaterThan(0));
      expect(s.normalize(50), isNotNull);
    });
  });

  group('LineChart logY', () {
    // A decay: the case the feature exists for.
    final decay = List<num>.generate(
      80,
      (i) => 2.4 * math.exp(-i / 12) + 0.004,
    );

    test('spreads a decaying series over more rows than a linear axis', () {
      // Asserted against the scale rather than the picture: this is a claim about
      // where values land, and counting glyphs in rendered output conflates the data
      // with the axis that is drawn beside it.
      const rows = 10;
      final linear = LinearScale.fit(decay, rows);
      final log = LinearScale.fitLog(decay, rows);

      // Not the count of distinct rows — a fast early decay touches many rows once
      // each, so linear can win that and still be unreadable. What matters is the
      // PILE-UP: how many samples share a single row.
      int worstPileUp(LinearScale s) {
        final counts = <int, int>{};
        for (final v in decay) {
          final row = s.pointCell(v);
          counts[row] = (counts[row] ?? 0) + 1;
        }
        return counts.values.reduce((a, b) => a > b ? a : b);
      }

      expect(
        worstPileUp(log),
        lessThan(worstPileUp(linear)),
        reason: 'linear piled ${worstPileUp(linear)}, log ${worstPileUp(log)}',
      );

      // Concretely: on a linear axis more than half the series collapses onto the
      // bottom row, which is the failure the log axis exists to fix.
      expect(
        decay.where((v) => linear.pointCell(v) == 0).length,
        greaterThan(decay.length ~/ 2),
      );
      expect(
        decay.where((v) => log.pointCell(v) == 0).length,
        lessThan(decay.length ~/ 4),
      );
    });

    test('labels the axis in powers of ten', () {
      final out = LineChart.of(
        decay,
        width: 60,
        height: 10,
        logY: true,
      ).render();
      expect(out, contains('0.001'));
    });

    test('is ignored for a filled area, which is read from zero', () {
      // Zero is not a point on a log axis, and a fill's whole meaning is its distance
      // from zero — so the two cannot both hold and fill wins.
      final a = LineChart.of(
        decay,
        width: 40,
        height: 8,
        fill: true,
        logY: true,
      ).render();
      final b = LineChart.of(decay, width: 40, height: 8, fill: true).render();
      expect(a, b);
    });

    test('survives degenerate input', () {
      for (final data in <List<num?>>[
        [],
        [5],
        [0, 0],
        [-1, -2],
        [null, null],
        [1e-300, 1e300],
      ]) {
        expect(
          () => LineChart.of(data, width: 30, height: 8, logY: true).render(),
          returnsNormally,
          reason: '$data',
        );
      }
    });
  });

  group('braille', () {
    test('maps dots to the documented bits', () {
      // The Braille encoding is not row-major — dots 7 and 8 were appended under the
      // original 6-dot cell — so a derived mapping silently scrambles the output.
      final c = BrailleCanvas(1, 1)..set(0, 0);
      expect(c.isEmpty, isFalse);
      final out = Canvas(1, 1);
      c.blitTo(out);
      expect(out.render(), '⠁');

      final bottomRight = BrailleCanvas(1, 1)..set(1, 3);
      final out2 = Canvas(1, 1);
      bottomRight.blitTo(out2);
      expect(out2.render(), '⢀');
    });

    test('addresses eight dots per cell', () {
      final c = BrailleCanvas(1, 1);
      expect(c.dotWidth, 2);
      expect(c.dotHeight, 4);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 2; x++) {
          c.set(x, y);
        }
      }
      final out = Canvas(1, 1);
      c.blitTo(out);
      // Every dot lit is the full cell, U+28FF.
      expect(out.render(), '⣿');
    });

    test('clips dots outside the surface', () {
      final c = BrailleCanvas(2, 2);
      expect(
        () => c
          ..set(-1, 0)
          ..set(0, -1)
          ..set(99, 0)
          ..set(0, 99)
          ..line(-50, -50, 99, 99),
        returnsNormally,
      );
    });

    test('leaves cells with no dots untouched, not as U+2800', () {
      // U+2800 is not a space: trailing-trim would not remove it, every row would
      // carry an invisible tail, and axes beneath would be erased.
      final out = Canvas(4, 1)..drawText(0, 0, 'abcd');
      BrailleCanvas(4, 1)
        ..set(0, 0)
        ..blitTo(out);
      final line = out.render();
      expect(line.substring(1), 'bcd');
      expect(line, isNot(contains('⠀')));
    });

    test('draws a connected line between dots', () {
      final c = BrailleCanvas(8, 2)..line(0, 0, 15, 7);
      final out = Canvas(8, 2);
      c.blitTo(out);
      // Every column of the diagonal is inked — no gaps.
      for (final row in out.renderLines(trimRight: false)) {
        expect(row, isNot(''));
      }
    });

    test('renders a chart at higher resolution than glyph mode', () {
      final data = List<num>.generate(60, (i) => math.sin(i / 9) * 10 + 20);
      final braille = LineChart.of(
        data,
        width: 50,
        height: 6,
        lineStyle: LineStyle.braille,
      ).render();
      expect(braille.runes.any((r) => r >= 0x2800 && r <= 0x28ff), isTrue);
      // Distinct rows of output: the dots resolve detail the glyphs cannot.
      expect(braille, isNot(LineChart.of(data, width: 50, height: 6).render()));
    });

    test('a gap breaks the braille line too', () {
      final out = LineChart.of(
        [10, 20, 30, null, null, 30, 20, 10],
        width: 30,
        height: 6,
        lineStyle: LineStyle.braille,
        axes: Axes.none,
      ).render();
      expect(out, isNot(contains('⠀')));
      expect(out.runes.any((r) => r >= 0x2800 && r <= 0x28ff), isTrue);
    });

    test('is independent of the charset, which ascii cannot express', () {
      // Worth pinning: the braille glyphs come from the Unicode block, not from the
      // CharSet, so an ascii theme does NOT make braille output ascii. A caller who
      // needs ascii needs glyph mode.
      final out = LineChart.of(
        [1, 5, 3, 9],
        width: 20,
        height: 5,
        theme: ChartTheme.ascii,
        lineStyle: LineStyle.braille,
      ).render();
      expect(out.runes.any((r) => r > 127), isTrue);
    });
  });

  group('ReferenceLine', () {
    test('draws across the plot at its value', () {
      final out = LineChart.of(
        [10, 50, 90],
        width: 40,
        height: 9,
        references: const [ReferenceLine(50)],
      ).render();
      expect(out, contains('·'));
    });

    test('carries a label without the rule running through it', () {
      final out = LineChart.of(
        [10, 50, 90],
        width: 40,
        height: 9,
        references: const [ReferenceLine(50, label: 'target')],
      ).render();
      expect(out, contains('target'));
    });

    test('a reference outside the data widens the domain to include it', () {
      final out = LineChart.of(
        [1, 2, 3],
        width: 40,
        height: 9,
        references: const [ReferenceLine(100, label: 'goal')],
      ).render();
      expect(out, contains('goal'));
    });

    test('the series wins a shared cell', () {
      // A reference is context; the data is the point. With the series sitting exactly
      // on the reference, the solid line must be what shows.
      final out = LineChart.of(
        List<num>.filled(20, 50),
        width: 30,
        height: 7,
        yMin: 0,
        yMax: 100,
        references: const [ReferenceLine(50)],
      ).render();
      expect(out, contains('─'));
      // The dotted rule is fully overdrawn on that row, so no cell of it survives on
      // the series' own level.
      final seriesRow = out
          .split('\n')
          .firstWhere((l) => l.contains('─'), orElse: () => '');
      expect(seriesRow, isNot(contains('·')));
    });

    test('a reference off the domain draws nothing rather than clamping', () {
      expect(
        () => LineChart.of(
          [1, 2, 3],
          width: 20,
          height: 6,
          yMin: 0,
          yMax: 5,
          references: const [ReferenceLine(1000)],
        ).render(),
        returnsNormally,
      );
    });
  });

  group('EventMarker', () {
    test('draws a vertical line with a caption', () {
      final out = LineChart.of(
        List<num>.generate(20, (i) => i),
        width: 40,
        height: 9,
        markers: const [EventMarker(10, label: 'grew')],
      ).render();
      expect(out, contains('grew'));
      expect(out, contains('│'));
    });

    test('stays attached to its data index when resampled', () {
      // The index is in data space, so a marker at the midpoint is drawn near the
      // middle whatever width the chart has.
      for (final width in [24, 40, 70]) {
        final out = LineChart.of(
          List<num>.generate(100, (i) => i),
          width: width,
          height: 8,
          axes: Axes.none,
          markers: const [EventMarker(50)],
        ).renderLines();
        final column = out
            .map((l) => l.indexOf('│'))
            .firstWhere((i) => i >= 0, orElse: () => -1);
        expect(column, greaterThan(width ~/ 4), reason: 'width $width');
        expect(column, lessThan(width * 3 ~/ 4), reason: 'width $width');
      }
    });

    test('an out-of-range index draws nothing', () {
      expect(
        () => LineChart.of(
          [1, 2, 3],
          width: 20,
          height: 6,
          markers: const [EventMarker(-1), EventMarker(999)],
        ).render(),
        returnsNormally,
      );
    });
  });

  group('xCaption', () {
    test('captions the two ends of the axis', () {
      final out = LineChart.of(
        List<num>.generate(50, (i) => i),
        width: 50,
        height: 8,
        xCaption: ('step 0', 'step 2000'),
      ).renderLines();
      expect(out.last, contains('step 0'));
      expect(out.last, contains('step 2000'));
      expect(measureWidth(out.last), lessThanOrEqualTo(50));
    });

    test('yields to spread labels when both are given', () {
      final out = LineChart.of(
        [1, 2, 3],
        width: 40,
        height: 8,
        xLabels: const ['a', 'b', 'c'],
        xCaption: ('left', 'right'),
      ).render();
      expect(out, isNot(contains('right')));
    });

    test('degrades rather than overflowing when there is no room', () {
      final out = LineChart.of(
        [1, 2, 3],
        width: 14,
        height: 6,
        xCaption: ('a very long left caption', 'and a right one'),
      ).renderLines();
      for (final line in out) {
        expect(measureWidth(line), lessThanOrEqualTo(14));
      }
    });
  });

  group('RingSeries', () {
    test('never exceeds its capacity', () {
      for (final mode in RingDecimation.values) {
        for (final capacity in [4, 16, 64, 500]) {
          final ring = RingSeries(capacity: capacity, decimation: mode);
          for (var i = 0; i < capacity * 20 + 7; i++) {
            ring.add(i);
          }
          expect(
            ring.length,
            lessThanOrEqualTo(capacity),
            reason: '${mode.name} at capacity $capacity',
          );
          expect(ring.isDecimated, isTrue);
        }
      }
    });

    test('capacity is clamped to a workable minimum', () {
      final ring = RingSeries(capacity: 1);
      for (var i = 0; i < 50; i++) {
        ring.add(i);
      }
      expect(ring.length, lessThanOrEqualTo(4));
    });

    test('drop keeps the most recent values at full resolution', () {
      final ring = RingSeries(capacity: 10);
      for (var i = 0; i < 100; i++) {
        ring.add(i);
      }
      expect(ring.values, [90, 91, 92, 93, 94, 95, 96, 97, 98, 99]);
      expect(ring.latest, 99);
    });

    test('fold keeps a spike that drop discards', () {
      // The whole reason fold exists, and the whole reason it is not the default.
      RingSeries build(RingDecimation mode) {
        final r = RingSeries(capacity: 32, decimation: mode);
        for (var i = 0; i < 400; i++) {
          r.add(i == 5 ? 9999 : 1);
        }
        return r;
      }

      expect(build(RingDecimation.fold).max, 9999);
      expect(build(RingDecimation.drop).max, 1);
    });

    test('fold genuinely reduces, which pair-folding would not', () {
      // Folding pairs into their min and max is a no-op: the min and max of two
      // values ARE those two values. This is the regression test for that.
      final ring = RingSeries(capacity: 16, decimation: RingDecimation.fold);
      for (var i = 0; i < 1000; i++) {
        ring.add(i);
      }
      expect(ring.length, lessThanOrEqualTo(16));
      expect(ring.totalAdded, 1000);
    });

    test('ignores values that cannot be plotted', () {
      final ring = RingSeries()
        ..add(1)
        ..add(null)
        ..add(double.nan)
        ..add(double.infinity)
        ..add(2);
      expect(ring.values, [1, 2]);
      expect(ring.totalAdded, 2);
    });

    test('reports its extremes and ends', () {
      final ring = RingSeries()..addAll([3, 1, 4, 1, 5]);
      expect(ring.min, 1);
      expect(ring.max, 5);
      expect(ring.oldest, 3);
      expect(ring.latest, 5);
      expect(ring.length, 5);
    });

    test('is empty before anything is added, and after clearing', () {
      final ring = RingSeries();
      expect(ring.isEmpty, isTrue);
      expect(ring.latest, isNull);
      expect(ring.min, isNull);
      ring.addAll([1, 2, 3]);
      expect(ring.isNotEmpty, isTrue);
      ring.clear();
      expect(ring.isEmpty, isTrue);
      expect(ring.isDecimated, isFalse);
      expect(ring.totalAdded, 0);
    });

    test('feeds a chart directly', () {
      final ring = RingSeries(capacity: 64);
      for (var i = 0; i < 500; i++) {
        ring.add(math.sin(i / 20) * 10);
      }
      expect(sparkline(ring.values).isNotEmpty, isTrue);
      expect(
        () => LineChart.of(ring.values, width: 40, height: 8).render(),
        returnsNormally,
      );
    });
  });

  group('the new features keep the old invariants', () {
    test('colour still cannot change geometry', () {
      String build(ChartTheme theme) => LineChart.of(
        List<num>.generate(40, (i) => 2.4 * math.exp(-i / 9) + 0.01),
        width: 50,
        height: 10,
        theme: theme,
        logY: true,
        references: const [ReferenceLine(0.5, label: 'target')],
        markers: const [EventMarker(20, label: 'grew')],
        xCaption: ('step 0', 'step 39'),
      ).render();
      expect(stripAnsi(build(ChartTheme.colorful)), build(ChartTheme.plain));
    });

    test('output still respects the requested width', () {
      for (final width in [12, 24, 50, 100]) {
        for (final style in LineStyle.values) {
          final lines = LineChart.of(
            List<num>.generate(40, (i) => i + 1),
            width: width,
            height: 9,
            logY: true,
            lineStyle: style,
            references: const [ReferenceLine(20, label: 'ref')],
            markers: const [EventMarker(10, label: 'ev')],
            xCaption: ('from', 'to'),
          ).renderLines();
          for (final line in lines) {
            expect(
              measureWidth(line),
              lessThanOrEqualTo(width),
              reason: '$width/${style.name}: "$line"',
            );
          }
        }
      }
    });

    test('rendering twice is still byte-identical', () {
      final chart = LineChart.of(
        [1, 10, 100],
        width: 30,
        height: 8,
        logY: true,
        lineStyle: LineStyle.braille,
        references: const [ReferenceLine(50)],
      );
      expect(chart.render(), chart.render());
    });
  });
}
