import 'dart:math' as math;

import 'package:console_charts/console_charts.dart';

void main() {
  final loss = List<num>.generate(
    120,
    (i) => 2.4 * math.exp(-i / 40) + 0.05 + math.sin(i / 3) * 0.04,
  );
  final accuracy = List<num>.generate(
    120,
    (i) => 0.42 + 0.49 * (1 - math.exp(-i / 35)),
  );
  final throughput = List<num>.generate(
    120,
    (i) => 138000 + math.sin(i / 7) * 9000 + (i % 11) * 600,
  );

  print('── sparkline ────────────────────────────────────────────────');
  print('');
  print('  one call, one line:');
  print('    ${sparkline(loss)}');
  print('');
  print('  resampled to 24 columns:');
  print('    ${sparkline(loss, width: 24)}');
  print('');
  print('  a gap stays a gap, not a zero:');
  print('    ${sparkline([5, 6, 7, null, null, 7, 6, 5])}');
  print('');
  print('  ascii, for a terminal that mangles anything else:');
  print('    ${sparkline(loss, width: 24, theme: ChartTheme.ascii)}');
  print('');

  print('── grouped, labelled and aligned ────────────────────────────');
  print('');
  print(
    SparklineGroup(
      [
        Series(loss, label: 'loss'),
        Series(accuracy, label: 'accuracy'),
        Series(throughput, label: 'tokens/s'),
      ],
      width: 46,
      valueFormat: formatCompact,
    ).render(),
  );
  print('');

  print('── the same rows on one shared scale ────────────────────────');
  print('');
  print('  p50 and p99 are comparable, so they belong on one scale:');
  print('');
  print(
    SparklineGroup(
      [
        Series(
          List<num>.generate(60, (i) => 12 + math.sin(i / 5) * 3),
          label: 'p50',
        ),
        Series(
          List<num>.generate(60, (i) => 48 + math.sin(i / 4) * 22),
          label: 'p99',
        ),
      ],
      width: 46,
      sharedScale: true,
      valueFormat: formatWithUnit('ms'),
    ).render(),
  );
  print('');

  print('── a framed panel ───────────────────────────────────────────');
  print('');
  final canvas = Canvas(50, 7)..drawBox(CharSets.unicode, title: 'Training');
  drawSparkline(canvas, 12, 2, loss, width: 34);
  drawSparkline(canvas, 12, 4, accuracy, width: 34);
  canvas
    ..drawText(2, 2, 'loss')
    ..drawText(2, 4, 'acc');
  print(canvas.render());
  print('');
}
