/// Waterfall charts: how a running total got from one value to another.
library;

import '../plot_frame.dart';
import '../renderable.dart';
import '../scale.dart';
import '../style.dart';
import '../theme.dart';

/// One step of a waterfall.
class WaterfallStep {
  /// A change of [value], positive or negative.
  const WaterfallStep(this.label, this.value) : isTotal = false;

  /// A checkpoint showing the running total so far, drawn from the baseline.
  const WaterfallStep.total(this.label, [this.value = 0]) : isTotal = true;

  /// A short name, used as the x label.
  final String label;

  /// The change this step contributes, or the total's value when [isTotal].
  final num value;

  /// Whether this bar is an absolute total rather than a change.
  final bool isTotal;

  @override
  String toString() =>
      'WaterfallStep($label, $value${isTotal ? ', total' : ''})';
}

/// A waterfall chart.
///
/// ```text
/// 100 ┤ ████
///  80 ┤ ████      ████
///  60 ┤ ████  ▓▓  ████
///  40 ┤ ████  ▓▓  ░░  ████
///   0 ┼──────────────────────
///      Start +A  -B  End
/// ```
///
/// Each bar floats: it starts where the previous one ended and spans only its own
/// contribution. A step that takes the running total across zero flips which side of
/// the baseline its bar sits on, which is the case most worth checking.
class WaterfallChart implements Renderable {
  /// Creates a waterfall chart.
  const WaterfallChart(
    this.steps, {
    this.width,
    this.height,
    this.theme = ChartTheme.plain,
    this.title,
    this.axes = const Axes(),
    this.increaseStyle,
    this.decreaseStyle,
    this.totalStyle,
    this.showConnectors = true,
  });

  /// The steps, in order.
  final List<WaterfallStep> steps;

  /// Total width. Defaults to the theme's.
  final int? width;

  /// Total height. Defaults to the theme's.
  final int? height;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// A heading above the chart.
  final String? title;

  /// Axis decoration.
  final Axes axes;

  /// Colour for a rising step. Defaults to green.
  final AnsiStyle? increaseStyle;

  /// Colour for a falling step. Defaults to red.
  final AnsiStyle? decreaseStyle;

  /// Colour for a total. Defaults to the first palette entry.
  final AnsiStyle? totalStyle;

  /// Whether to join each bar's end to the next bar's start.
  final bool showConnectors;

  /// The running total before and after each step.
  List<(double, double)> get _spans {
    final out = <(double, double)>[];
    var running = 0.0;
    for (final step in steps) {
      final v = step.value.toDouble();
      if (step.isTotal) {
        // A total is drawn from the baseline. When no explicit value is given it
        // shows whatever the running total has reached.
        final target = step.value == 0 ? running : v;
        out.add((0, target));
        running = target;
      } else {
        final next = running + (v.isFinite ? v : 0);
        out.add((running, next));
        running = next;
      }
    }
    return out;
  }

  @override
  List<String> renderLines() {
    if (steps.isEmpty) return const [];
    final w = width ?? theme.defaultWidth;
    final h = height ?? theme.defaultHeight;
    final chars = theme.charset;
    final spans = _spans;

    final yScale = LinearScale.fit(
      spans.expand((s) => [s.$1, s.$2]),
      h,
      includeZero: true,
      mode: axes.showYLabels ? AxisMode.nice : AxisMode.tight,
    );

    return renderPlotFrame(
      width: w,
      height: h,
      theme: theme,
      axes: axes,
      title: title,
      xLabels: [for (final s in steps) s.label],
      yScale: yScale,
      xScale: (plotWidth) => LinearScale.index(steps.length, plotWidth),
      draw: (plot) {
        final rise = increaseStyle ?? const AnsiStyle.of(AnsiColor.green);
        final fall = decreaseStyle ?? const AnsiStyle.of(AnsiColor.red);
        final total = totalStyle ?? AnsiStyle.of(theme.palette.first);

        final slot = (plot.width / steps.length).floor().clamp(1, plot.width);
        final barWidth = (slot - 1).clamp(1, slot);

        for (var i = 0; i < steps.length; i++) {
          final (from, to) = spans[i];
          final left = ((i * plot.width) / steps.length).round();
          final style = theme.color
              ? (steps[i].isTotal ? total : (to >= from ? rise : fall))
              : null;
          final glyph = steps[i].isTotal
              ? chars.full
              : chars.shades[(to >= from ? 2 : 1) % chars.shades.length];

          final fromLevel = plot.levelOf(from);
          final toLevel = plot.levelOf(to);
          if (fromLevel < 0 || toLevel < 0) continue;
          // A zero-length step still deserves a mark, or the chart silently omits a
          // step that genuinely happened and contributed nothing.
          for (var dx = 0; dx < barWidth; dx++) {
            plot.fillColumn(
              left + dx,
              fromLevel,
              toLevel,
              glyph: glyph,
              style: style,
            );
          }

          if (showConnectors && i < steps.length - 1) {
            final nextLeft = (((i + 1) * plot.width) / steps.length).round();
            for (var x = left + barWidth; x < nextLeft; x++) {
              plot.putLevel(
                x,
                toLevel,
                chars.horizontal,
                style: theme.color ? theme.axisStyle : null,
              );
            }
          }
        }
        plot.drawBaseline(0, style: theme.color ? theme.axisStyle : null);
      },
    );
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}
