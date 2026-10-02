/// Charts for the console and terminal, rendered as plain text.
///
/// Sparklines, line and bar charts, gauges, heatmaps, box plots and composed
/// dashboards. Every chart is a value object that renders to a `String` or a
/// `List<String>` — nothing is printed, nothing is measured against a live
/// terminal, and nothing imports `dart:io`, so the same chart works in a CLI, in a
/// log pipeline, in an isolate with no terminal attached, and on the web.
///
/// ```dart
/// import 'package:console_charts/console_charts.dart';
///
/// void main() {
///   print(sparkline([1, 3, 2, 5, 8, 6, 9]));
/// }
/// ```
///
/// ## Width is always explicit
///
/// No chart detects the terminal's size, because that needs `dart:io` and is
/// unavailable or misleading in several of the places charts are most useful. Pass
/// a width; on the Dart VM `stdout.terminalColumns` is the value you want, guarded,
/// since it throws when output is not a terminal.
///
/// ## Colour is opt-in
///
/// Rendering is plain text unless the theme says otherwise — use
/// [ChartTheme.colorful], or `copyWith(color: true)`. Only SGR colour sequences
/// are ever emitted, never cursor movement, so charts coexist with terminal UIs
/// that manage the screen themselves.
library;

export 'src/canvas.dart' show Canvas;
export 'src/charset.dart' show CharSet, CharSets, levelGlyph, partialGlyph;
export 'src/format.dart'
    show
        NumberFormat,
        formatAuto,
        formatCompact,
        formatFixed,
        formatPercent,
        formatWithUnit;
export 'src/style.dart' show AnsiColor, AnsiStyle, reset, stripAnsi;
export 'src/theme.dart' show ChartTheme, NumberFormatter;
export 'src/width.dart'
    show
        DisplayWidth,
        TextAlign,
        WidthFn,
        measureWidth,
        padToWidth,
        runeWidth,
        truncateToWidth;
