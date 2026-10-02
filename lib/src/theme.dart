/// Everything presentational, bundled so a chart takes one argument for it.
library;

import 'charset.dart';
import 'format.dart';
import 'style.dart';
import 'width.dart';

/// Turns a value into the text that labels it.
typedef NumberFormatter = String Function(num value);

/// The glyphs, colours, number format and width rules a chart draws with.
///
/// Without this, every chart constructor would carry a character set, a colour
/// flag, a palette, four or five semantic styles, a number formatter and a width
/// function — and a dashboard would have to thread all of them through every
/// child. One object travels instead, and [copyWith] restyles a whole tree.
///
/// Colour is **off** in every built-in theme except [ChartTheme.colorful], so the
/// default output is plain text.
class ChartTheme {
  /// Creates a theme. Every argument has a default, so `const ChartTheme()` is a
  /// complete, usable theme.
  const ChartTheme({
    this.charset = CharSets.unicode,
    this.color = false,
    this.palette = AnsiColor.palette,
    this.titleStyle = const AnsiStyle(bold: true),
    this.labelStyle = AnsiStyle.none,
    this.axisStyle = const AnsiStyle(foreground: AnsiColor.brightBlack),
    this.valueStyle = AnsiStyle.none,
    this.trackStyle = const AnsiStyle(foreground: AnsiColor.brightBlack),
    this.format = formatAuto,
    this.width = DisplayWidth.standard,
    this.defaultWidth = 60,
    this.defaultHeight = 12,
  });

  /// The glyphs to draw with.
  final CharSet charset;

  /// Whether to emit ANSI colour.
  ///
  /// When false, every style in this theme is ignored at render time and the
  /// output is plain text. Styles are still carried through the canvas, so turning
  /// this on changes nothing but the final string — which is the property the
  /// colour test relies on.
  final bool color;

  /// Colours cycled by series index when a series does not specify its own.
  final List<AnsiColor> palette;

  /// Chart and panel titles.
  final AnsiStyle titleStyle;

  /// Category and axis-tick labels.
  final AnsiStyle labelStyle;

  /// Axis rules and frames.
  final AnsiStyle axisStyle;

  /// Numeric values printed beside a bar or sparkline.
  final AnsiStyle valueStyle;

  /// The unfilled remainder of a gauge or progress bar.
  final AnsiStyle trackStyle;

  /// How numbers become labels. Defaults to [formatAuto].
  final NumberFormatter format;

  /// How text width is measured. See [DisplayWidth].
  final DisplayWidth width;

  /// The width a chart uses when given none.
  final int defaultWidth;

  /// The height a two-dimensional chart uses when given none.
  final int defaultHeight;

  /// Unicode glyphs, no colour. The default.
  static const ChartTheme plain = ChartTheme();

  /// Pure ASCII, no colour — for terminals or log pipelines that mangle Unicode.
  static const ChartTheme ascii = ChartTheme(charset: CharSets.ascii);

  /// Unicode glyphs with ANSI colour enabled.
  static const ChartTheme colorful = ChartTheme(color: true);

  /// Rounded frames and curves, no colour.
  static const ChartTheme rounded = ChartTheme(charset: CharSets.rounded);

  /// The colour for series [index], cycling the [palette].
  ///
  /// Returns [AnsiStyle.none] when the palette is empty, so a theme can switch
  /// colour off per-series by supplying no palette at all.
  AnsiStyle seriesStyle(int index) => palette.isEmpty
      ? AnsiStyle.none
      : AnsiStyle.of(palette[index % palette.length]);

  /// This theme with the given properties replaced.
  ChartTheme copyWith({
    CharSet? charset,
    bool? color,
    List<AnsiColor>? palette,
    AnsiStyle? titleStyle,
    AnsiStyle? labelStyle,
    AnsiStyle? axisStyle,
    AnsiStyle? valueStyle,
    AnsiStyle? trackStyle,
    NumberFormatter? format,
    DisplayWidth? width,
    int? defaultWidth,
    int? defaultHeight,
  }) => ChartTheme(
    charset: charset ?? this.charset,
    color: color ?? this.color,
    palette: palette ?? this.palette,
    titleStyle: titleStyle ?? this.titleStyle,
    labelStyle: labelStyle ?? this.labelStyle,
    axisStyle: axisStyle ?? this.axisStyle,
    valueStyle: valueStyle ?? this.valueStyle,
    trackStyle: trackStyle ?? this.trackStyle,
    format: format ?? this.format,
    width: width ?? this.width,
    defaultWidth: defaultWidth ?? this.defaultWidth,
    defaultHeight: defaultHeight ?? this.defaultHeight,
  );

  @override
  String toString() => 'ChartTheme(${charset.name}${color ? ', color' : ''})';
}
