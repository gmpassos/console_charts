/// Axes, labels, and the shared pipeline behind every two-dimensional chart.
///
/// Axis decoration is a *decorator*: it measures how much room it needs, the chart
/// draws its data into whatever is left, and the decoration is then applied around
/// the result. So no chart in this package contains any axis code, and all of them
/// label their axes identically.
library;

import 'canvas.dart';
import 'format.dart';
import 'plot.dart';
import 'scale.dart';
import 'theme.dart';
import 'width.dart';

/// How much room axis decoration takes on each side of the plot area.
class AxisInsets {
  /// Creates a set of insets.
  const AxisInsets({
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
  });

  /// Columns taken on the left, by the tick labels and the axis itself.
  final int left;

  /// Columns taken on the right.
  final int right;

  /// Rows taken above, by a title.
  final int top;

  /// Rows taken below, by the x-axis rule and its labels.
  final int bottom;

  /// Total columns consumed.
  int get horizontal => left + right;

  /// Total rows consumed.
  int get vertical => top + bottom;
}

/// Axis decoration for a two-dimensional plot.
class Axes {
  /// Creates axis decoration.
  const Axes({
    this.showY = true,
    this.showX = true,
    this.showYLabels = true,
    this.yTickCount,
    this.yFormat,
    this.xLabelEvery,
  });

  /// No axes at all — a bare plot area.
  static const Axes none = Axes(showY: false, showX: false, showYLabels: false);

  /// Whether to draw the vertical axis.
  final bool showY;

  /// Whether to draw the horizontal axis.
  final bool showX;

  /// Whether to label the vertical axis' ticks.
  final bool showYLabels;

  /// How many y ticks to aim for. Defaults to about one every three rows.
  final int? yTickCount;

  /// How tick values are formatted. Defaults to the theme's formatter.
  final NumberFormatter? yFormat;

  /// Draw every nth x label; null fits as many as will not collide.
  final int? xLabelEvery;

  /// Tick values mapped to the levels they fall on, with their labels.
  ///
  /// Two ticks can round to the same level on a short axis. The first wins, which
  /// keeps the top and bottom labels — the two a reader actually uses — and silently
  /// drops a middle one rather than overprinting.
  Map<int, String> yTickLabels(LinearScale scale, ChartTheme theme, int rows) {
    if (rows <= 0) return const {};
    final count = yTickCount ?? maxTicksForHeight(rows);
    final step = scale.tickStep(count);
    final format = yFormat ?? _formatterFor(step, theme);
    final out = <int, String>{};
    for (final value in scale.ticks(count)) {
      final level = scale.withSize(rows).pointCell(value);
      if (level < 0) continue;
      out.putIfAbsent(level, () => format(value));
    }
    return out;
  }

  /// A formatter showing exactly as many decimals as the step needs.
  ///
  /// Derived from the step's exponent, so an axis stepping by 0.01 shows two
  /// decimals on every label and none of them can be `0.30000000000000004`.
  NumberFormatter _formatterFor(NiceStep step, ChartTheme theme) {
    // Beyond about ten decimals fixed notation is unreadable and far too wide for a
    // gutter, so hand such domains back to the theme's formatter, which switches to
    // exponential at extreme magnitudes.
    if (step.decimals == 0 || step.decimals > 10) return theme.format;
    final fixed = formatFixed(step.decimals);
    return (num v) {
      final s = fixed(v);
      // A tick just below zero formats as '-0' at this precision, which is not a
      // number anyone wants on an axis.
      return s.startsWith('-') && double.tryParse(s) == 0 ? s.substring(1) : s;
    };
  }

  /// How much room this decoration needs.
  AxisInsets measure({
    required LinearScale yScale,
    required ChartTheme theme,
    required int plotHeight,
    List<String>? xLabels,
    bool hasTitle = false,
  }) {
    var left = 0;
    if (showY) {
      left += 1; // the axis column itself
      if (showYLabels) {
        var widest = 0;
        for (final label in yTickLabels(yScale, theme, plotHeight).values) {
          final w = theme.width(label);
          if (w > widest) widest = w;
        }
        left += widest + 1; // labels plus one space before the axis
      }
    }
    return AxisInsets(
      left: left,
      top: hasTitle ? 1 : 0,
      bottom: (showX ? 1 : 0) + (xLabels != null && xLabels.isNotEmpty ? 1 : 0),
    );
  }

  /// Draws this decoration around [plot], returning the complete canvas.
  Canvas wrap(
    Canvas plot, {
    required LinearScale yScale,
    required ChartTheme theme,
    required AxisInsets insets,
    List<String>? xLabels,
    String? title,
  }) {
    final chars = theme.charset;
    final total = Canvas(
      plot.width + insets.horizontal,
      plot.height + insets.vertical,
    );
    final axisStyle = theme.color ? theme.axisStyle : null;
    final labelStyle = theme.color ? theme.labelStyle : null;

    if (title != null && title.isNotEmpty) {
      total.drawText(
        0,
        0,
        truncateToWidth(title, total.width, ellipsis: '…', width: theme.width),
        style: theme.color ? theme.titleStyle : null,
        measure: theme.width,
      );
    }

    total.blit(plot, insets.left, insets.top);

    if (showY) {
      final axisColumn = insets.left - 1;
      final ticks = yTickLabels(yScale, theme, plot.height);
      final labelWidth = insets.left - 2;
      for (var row = 0; row < plot.height; row++) {
        final level = plot.height - 1 - row;
        final label = ticks[level];
        final zeroHere =
            yScale.spansZero &&
            yScale.withSize(plot.height).pointCell(0) == level;
        total.set(
          axisColumn,
          insets.top + row,
          zeroHere
              ? chars.axisOrigin
              : (label != null ? chars.teeLeft : chars.vertical),
          style: axisStyle,
        );
        if (label != null && showYLabels && labelWidth > 0) {
          total.drawText(
            0,
            insets.top + row,
            padToWidth(
              truncateToWidth(
                label,
                labelWidth,
                ellipsis: '…',
                width: theme.width,
              ),
              labelWidth,
              align: TextAlign.right,
              width: theme.width,
            ),
            style: labelStyle,
            measure: theme.width,
          );
        }
      }
    }

    if (showX) {
      final row = insets.top + plot.height;
      total.hLine(
        insets.left,
        row,
        plot.width,
        chars.horizontal,
        style: axisStyle,
      );
      if (showY) {
        total.set(insets.left - 1, row, chars.axisOrigin, style: axisStyle);
      }
    }

    if (xLabels != null && xLabels.isNotEmpty) {
      _drawXLabels(total, xLabels, insets, plot.width, theme);
    }
    return total;
  }

  /// Places x labels under the columns they belong to, dropping any that collide.
  ///
  /// Keeps the first, then walks rightward accepting a label only when it clears the
  /// last accepted one by at least a space. The result is sparse but never
  /// overlapping, which is the only readable outcome when there are more categories
  /// than room.
  void _drawXLabels(
    Canvas canvas,
    List<String> labels,
    AxisInsets insets,
    int plotWidth,
    ChartTheme theme,
  ) {
    final row = insets.top + canvas.height - insets.top - 1;
    final style = theme.color ? theme.labelStyle : null;
    final n = labels.length;
    if (n == 0 || plotWidth <= 0) return;

    var lastEnd = -1;
    for (var i = 0; i < n; i++) {
      if (xLabelEvery != null && i % xLabelEvery! != 0) continue;
      final label = labels[i];
      if (label.isEmpty) continue;
      final centre = n == 1
          ? plotWidth ~/ 2
          : (i * (plotWidth - 1) / (n - 1)).round();
      final w = theme.width(label);
      var start = insets.left + centre - w ~/ 2;
      if (start < insets.left) start = insets.left;
      if (start + w > insets.left + plotWidth) {
        start = insets.left + plotWidth - w;
      }
      if (start <= lastEnd) continue;
      canvas.drawText(start, row, label, style: style, measure: theme.width);
      lastEnd = start + w;
    }
  }
}

/// Builds a complete two-dimensional chart.
///
/// Sizes the plot area to what is left of [width] and [height] after [axes] needs
/// its share, hands a [Plot] to [draw], then decorates the result.
///
/// Every axes-based chart here is a few lines of "paint the body" plus a call to
/// this, which is why they all behave the same at the edges — a narrow width, a
/// degenerate domain, a title too long to fit.
List<String> renderPlotFrame({
  required int width,
  required int height,
  required LinearScale yScale,
  required LinearScale Function(int plotWidth) xScale,
  required void Function(Plot plot) draw,
  ChartTheme theme = ChartTheme.plain,
  Axes axes = const Axes(),
  String? title,
  List<String>? xLabels,
}) {
  if (width <= 0 || height <= 0) return const [];

  // Measured against the full height first, which is approximate — the insets can
  // change the plot height and so the tick count. One correction pass settles it,
  // and a second would not change the answer because the label width is dominated
  // by the domain, not the count.
  var insets = axes.measure(
    yScale: yScale,
    theme: theme,
    plotHeight: height,
    xLabels: xLabels,
    hasTitle: title != null && title.isNotEmpty,
  );
  var plotWidth = width - insets.horizontal;
  var plotHeight = height - insets.vertical;

  if (plotWidth > 0 && plotHeight > 0) {
    insets = axes.measure(
      yScale: yScale,
      theme: theme,
      plotHeight: plotHeight,
      xLabels: xLabels,
      hasTitle: title != null && title.isNotEmpty,
    );
    plotWidth = width - insets.horizontal;
    plotHeight = height - insets.vertical;
  }

  // Degradation ladder, in order: drop the y labels, then the axes entirely, then
  // the title. A chart with no room for decoration is still worth drawing; one that
  // throws is not.
  if (plotWidth < 1 || plotHeight < 1) {
    final bare = Axes(
      showY: false,
      showX: false,
      showYLabels: false,
      yTickCount: axes.yTickCount,
    );
    insets = bare.measure(yScale: yScale, theme: theme, plotHeight: height);
    plotWidth = width - insets.horizontal;
    plotHeight = height - insets.vertical;
    if (plotWidth < 1 || plotHeight < 1) return const [];
    final canvas = Canvas(plotWidth, plotHeight);
    draw(
      Plot(
        canvas,
        xScale(plotWidth),
        yScale.withSize(plotHeight),
        theme.charset,
      ),
    );
    return canvas.renderLines(color: theme.color);
  }

  final plotCanvas = Canvas(plotWidth, plotHeight);
  draw(
    Plot(
      plotCanvas,
      xScale(plotWidth),
      yScale.withSize(plotHeight),
      theme.charset,
    ),
  );

  return axes
      .wrap(
        plotCanvas,
        yScale: yScale.withSize(plotHeight),
        theme: theme,
        insets: insets,
        xLabels: xLabels,
        title: title,
      )
      .renderLines(color: theme.color);
}

/// Levels for each column of [values] under [scale], with -1 for gaps.
List<int> levelsFor(List<num?> values, LinearScale scale) => [
  for (final v in values) scale.pointCell(v),
];

/// Convenience for the x scale of a series plotted against its own indices.
LinearScale indexScale(int count) => LinearScale.index(count, 1);
