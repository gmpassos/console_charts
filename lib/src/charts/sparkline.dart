/// One-line charts: the whole shape of a series in the width of a word.
library;

import '../canvas.dart';
import '../charset.dart';
import '../renderable.dart';
import '../resample.dart';
import '../scale.dart';
import '../series.dart';
import '../style.dart';
import '../theme.dart';
import '../width.dart';

/// Renders [values] as a single line of block characters.
///
/// ```dart
/// print(sparkline([1, 5, 3, 9, 7, 12, 10]));
/// // ▁▄▂▆▅█▇
/// ```
///
/// One character per value, unless [width] is given — then the series is
/// resampled to fit, by [mode].
///
/// Missing values (null, NaN, an infinity) render as a blank, so a gap in the data
/// reads as a gap rather than as a zero. [min] and [max] pin the scale, which is
/// what makes two sparklines comparable; without them each scales to its own range
/// and equal-looking lines can mean very different numbers.
String sparkline(
  List<num?> values, {
  ChartTheme theme = ChartTheme.plain,
  num? min,
  num? max,
  int? width,
  ResampleMode mode = ResampleMode.mean,
  AnsiStyle? style,
}) {
  if (values.isEmpty) return '';
  final samples = width == null
      ? values.map((v) => v?.toDouble()).toList(growable: false)
      : resample(values, width, mode: mode);
  if (samples.isEmpty) return '';

  // Tight, not nice: a sparkline has one row, so there is nowhere to put a tick
  // and no reason to round the domain outward — rounding would only flatten the
  // shape against the middle of the ramp.
  final scale = LinearScale.fit(
    samples,
    1,
    mode: AxisMode.tight,
    min: min,
    max: max,
  );
  final ramp = theme.charset.verticalRamp;
  final out = StringBuffer();
  for (final sample in samples) {
    final t = scale.normalize(sample);
    out.write(t == null ? theme.charset.blank : levelGlyph(ramp, t));
  }
  final text = out.toString();
  final effective = style ?? AnsiStyle.none;
  return theme.color ? effective.apply(text) : text;
}

/// Several labelled sparklines, aligned into a block.
///
/// ```text
/// loss   █▇▆▅▄▃▃▂▂▁  0.052
/// acc    ▁▂▃▄▅▆▇▇██  91%
/// gpu    ▆▇▇█▇▆▇█▇▇  82%
/// ```
///
/// The labels and the trailing values are padded into columns, so the sparklines
/// themselves line up and can be read against one another.
class SparklineGroup implements Renderable {
  /// Creates a group of labelled sparklines, one per entry of [series].
  const SparklineGroup(
    this.series, {
    this.width,
    this.theme = ChartTheme.plain,
    this.sharedScale = false,
    this.showValues = true,
    this.mode = ResampleMode.mean,
    this.valueFormat,
  });

  /// The series to draw, one row each.
  final List<Series> series;

  /// Total width of the block, labels and values included.
  ///
  /// Defaults to [ChartTheme.defaultWidth].
  final int? width;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// Whether every row shares one scale.
  ///
  /// Off by default, because rows usually hold unrelated quantities and each is
  /// most readable against its own range. Turn it on when the rows *are*
  /// comparable — several latency percentiles, say — since separate scales would
  /// then make a small series look identical to a large one.
  final bool sharedScale;

  /// Whether to print each series' latest value after its sparkline.
  final bool showValues;

  /// How several samples in one column are reduced.
  final ResampleMode mode;

  /// How the trailing value is formatted. Defaults to the theme's formatter.
  final NumberFormatter? valueFormat;

  @override
  List<String> renderLines() {
    if (series.isEmpty) return const [];
    final total = width ?? theme.defaultWidth;
    final measure = theme.width;
    final format = valueFormat ?? theme.format;

    final labels = series.map((s) => s.label ?? '').toList(growable: false);
    final labelWidth = labels.fold<int>(0, (w, l) {
      final lw = measure(l);
      return lw > w ? lw : w;
    });

    final values = <String>[];
    if (showValues) {
      for (final s in series) {
        final latest = s.latestFinite;
        values.add(latest == null ? '' : format(latest));
      }
    }
    final valueWidth = values.fold<int>(0, (w, v) {
      final vw = measure(v);
      return vw > w ? vw : w;
    });

    // Label, gap, sparkline, gap, value. Each gap is one column, and only present
    // when the thing beside it is.
    final overhead =
        (labelWidth > 0 ? labelWidth + 1 : 0) +
        (valueWidth > 0 ? valueWidth + 1 : 0);
    final sparkWidth = total - overhead;
    if (sparkWidth < 1) {
      // Not enough room for a chart at all. Degrade to labels and values, which is
      // still useful, rather than returning nothing.
      return [
        for (var i = 0; i < series.length; i++)
          [
            if (labelWidth > 0)
              padToWidth(labels[i], labelWidth, width: measure),
            if (valueWidth > 0) values[i],
          ].join(' ').trimRight(),
      ];
    }

    // One scale across every row, or one per row. Computed once either way.
    LinearScale? shared;
    if (sharedScale) {
      shared = LinearScale.fit(
        series.expand((s) => s.values),
        1,
        mode: AxisMode.tight,
      );
    }

    final lines = <String>[];
    for (var i = 0; i < series.length; i++) {
      final s = series[i];
      final spark = sparkline(
        s.values,
        theme: theme,
        width: sparkWidth,
        mode: mode,
        min: shared?.min,
        max: shared?.max,
        style: s.style ?? (theme.color ? theme.seriesStyle(i) : null),
      );
      final row = StringBuffer();
      if (labelWidth > 0) {
        final label = truncateToWidth(
          labels[i],
          labelWidth,
          ellipsis: '…',
          width: measure,
        );
        row.write(padToWidth(label, labelWidth, width: measure));
        row.write(' ');
      }
      row.write(spark);
      if (valueWidth > 0) {
        row.write(' ');
        row.write(
          padToWidth(
            values[i],
            valueWidth,
            align: TextAlign.right,
            width: measure,
          ),
        );
      }
      lines.add(row.toString().trimRight());
    }
    return lines;
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A sparkline drawn on a [Canvas] at ([x], [y]).
///
/// For charts that embed one in a larger layout rather than emitting it as text.
void drawSparkline(
  Canvas canvas,
  int x,
  int y,
  List<num?> values, {
  required int width,
  ChartTheme theme = ChartTheme.plain,
  num? min,
  num? max,
  ResampleMode mode = ResampleMode.mean,
  AnsiStyle? style,
}) {
  if (width <= 0 || values.isEmpty) return;
  final samples = resample(values, width, mode: mode);
  final scale = LinearScale.fit(
    samples,
    1,
    mode: AxisMode.tight,
    min: min,
    max: max,
  );
  final ramp = theme.charset.verticalRamp;
  for (var i = 0; i < samples.length; i++) {
    final t = scale.normalize(samples[i]);
    if (t == null) continue;
    canvas.set(x + i, y, levelGlyph(ramp, t), style: style);
  }
}
