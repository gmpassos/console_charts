/// Optional colour, as SGR escape sequences.
///
/// Colour is off unless asked for. Two reasons, and neither is taste: escape
/// sequences are noise in a log file or a browser console, and they make a chart's
/// output impossible to compare against an expected string without filtering.
///
/// ## Only SGR, never cursor motion
///
/// This library emits nothing but `CSI … m` — colour and text attributes. It never
/// moves the cursor, never clears, never emits a carriage return. A chart is a
/// block of lines that a caller prints; it does not own the screen. Terminal UIs
/// that manage a scrolling region or sanitize their output can therefore accept
/// coloured charts without the two fighting over the cursor.
library;

/// A terminal colour.
///
/// The first sixteen are the terminal's own palette, so they match whatever theme
/// the user has chosen. [AnsiColor.indexed] reaches the 256-colour cube and
/// [AnsiColor.rgb] asks for an exact colour, which needs a true-colour terminal.
class AnsiColor {
  const AnsiColor._(this._fg, this._bg);

  /// One of the 256 palette entries.
  ///
  /// 0-7 are the standard colours, 8-15 their bright variants, 16-231 a 6×6×6
  /// cube, and 232-255 a greyscale ramp. Widely supported.
  const AnsiColor.indexed(int index) : _fg = '38;5;$index', _bg = '48;5;$index';

  /// An exact 24-bit colour. Requires a true-colour terminal; others approximate
  /// or ignore it.
  const AnsiColor.rgb(int r, int g, int b)
    : _fg = '38;2;$r;$g;$b',
      _bg = '48;2;$r;$g;$b';

  final String _fg;
  final String _bg;

  /// The SGR parameter that sets this as the foreground colour.
  String get foregroundCode => _fg;

  /// The SGR parameter that sets this as the background colour.
  String get backgroundCode => _bg;

  /// Terminal palette black.
  static const AnsiColor black = AnsiColor._('30', '40');

  /// Terminal palette red.
  static const AnsiColor red = AnsiColor._('31', '41');

  /// Terminal palette green.
  static const AnsiColor green = AnsiColor._('32', '42');

  /// Terminal palette yellow.
  static const AnsiColor yellow = AnsiColor._('33', '43');

  /// Terminal palette blue.
  static const AnsiColor blue = AnsiColor._('34', '44');

  /// Terminal palette magenta.
  static const AnsiColor magenta = AnsiColor._('35', '45');

  /// Terminal palette cyan.
  static const AnsiColor cyan = AnsiColor._('36', '46');

  /// Terminal palette white.
  static const AnsiColor white = AnsiColor._('37', '47');

  /// Bright black, usually rendered as grey.
  static const AnsiColor brightBlack = AnsiColor._('90', '100');

  /// Bright red.
  static const AnsiColor brightRed = AnsiColor._('91', '101');

  /// Bright green.
  static const AnsiColor brightGreen = AnsiColor._('92', '102');

  /// Bright yellow.
  static const AnsiColor brightYellow = AnsiColor._('93', '103');

  /// Bright blue.
  static const AnsiColor brightBlue = AnsiColor._('94', '104');

  /// Bright magenta.
  static const AnsiColor brightMagenta = AnsiColor._('95', '105');

  /// Bright cyan.
  static const AnsiColor brightCyan = AnsiColor._('96', '106');

  /// Bright white.
  static const AnsiColor brightWhite = AnsiColor._('97', '107');

  /// A readable default sequence for multi-series charts.
  ///
  /// Ordered so that adjacent series stay distinguishable, and avoiding black and
  /// white because either disappears against one of the two common backgrounds.
  static const List<AnsiColor> palette = [
    cyan,
    yellow,
    magenta,
    green,
    blue,
    red,
    brightCyan,
    brightYellow,
    brightMagenta,
    brightGreen,
  ];

  @override
  bool operator ==(Object other) =>
      other is AnsiColor && other._fg == _fg && other._bg == _bg;

  @override
  int get hashCode => Object.hash(_fg, _bg);
}

/// A colour and attribute combination applied to part of a chart.
///
/// Immutable and cheap to compare, which matters: the renderer coalesces runs of
/// equal styles into a single escape sequence, and equality is how it recognises a
/// run.
class AnsiStyle {
  /// Creates a style. Every argument is optional; the default is no styling at all
  /// and renders as the empty string.
  const AnsiStyle({
    this.foreground,
    this.background,
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = false,
    this.inverse = false,
  });

  /// Text colour, or null to leave it as the terminal's default.
  final AnsiColor? foreground;

  /// Background colour, or null to leave it alone.
  final AnsiColor? background;

  /// Bold, or on many terminals a brighter variant of [foreground].
  final bool bold;

  /// Faint. Not supported everywhere.
  final bool dim;

  /// Italic. Not supported everywhere.
  final bool italic;

  /// Underlined.
  final bool underline;

  /// Swaps foreground and background.
  final bool inverse;

  /// Shorthand for a plain foreground colour.
  const AnsiStyle.of(AnsiColor color) : this(foreground: color);

  /// No styling. Renders as the empty string, so it costs nothing to use.
  static const AnsiStyle none = AnsiStyle();

  /// Whether this style would emit anything.
  bool get isEmpty =>
      foreground == null &&
      background == null &&
      !bold &&
      !dim &&
      !italic &&
      !underline &&
      !inverse;

  /// The SGR sequence that turns this style on, or `''` if [isEmpty].
  String get escape {
    if (isEmpty) return '';
    final codes = <String>[
      if (bold) '1',
      if (dim) '2',
      if (italic) '3',
      if (underline) '4',
      if (inverse) '7',
      if (foreground != null) foreground!.foregroundCode,
      if (background != null) background!.backgroundCode,
    ];
    return '$_csi${codes.join(';')}m';
  }

  /// [text] wrapped in this style and a reset, or unchanged if [isEmpty].
  ///
  /// The reset is unconditional rather than an attempt to restore what was
  /// previously in effect, because a chart cannot know the surrounding state and a
  /// style that leaked would colour whatever the caller printed next.
  String apply(String text) => isEmpty ? text : '$escape$text$ansiReset';

  /// This style with the given attributes replaced.
  AnsiStyle copyWith({
    AnsiColor? foreground,
    AnsiColor? background,
    bool? bold,
    bool? dim,
    bool? italic,
    bool? underline,
    bool? inverse,
  }) => AnsiStyle(
    foreground: foreground ?? this.foreground,
    background: background ?? this.background,
    bold: bold ?? this.bold,
    dim: dim ?? this.dim,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    inverse: inverse ?? this.inverse,
  );

  @override
  bool operator ==(Object other) =>
      other is AnsiStyle &&
      other.foreground == foreground &&
      other.background == background &&
      other.bold == bold &&
      other.dim == dim &&
      other.italic == italic &&
      other.underline == underline &&
      other.inverse == inverse;

  @override
  int get hashCode => Object.hash(
    foreground,
    background,
    bold,
    dim,
    italic,
    underline,
    inverse,
  );
}

const String _csi = '\x1b[';

/// The sequence that clears all styling: `CSI 0 m`.
///
/// Named `ansiReset` rather than `reset` because it is exported into the importing
/// library's namespace, where a bare `reset` is both ambiguous and likely to collide
/// with something the caller already has.
const String ansiReset = '${_csi}0m';

/// [text] with every ANSI escape sequence removed.
///
/// Useful for measuring the width of something already coloured, for writing to a
/// destination that cannot display colour, and for one strong test: stripping a
/// coloured chart must reproduce the plain one exactly, which checks that colour
/// changed no geometry.
///
/// Removes any CSI sequence — not only SGR — so it also cleans input this library
/// would never produce.
String stripAnsi(String text) {
  if (!text.contains('\x1b')) return text;
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    if (text.codeUnitAt(i) == 0x1B) {
      // CSI: ESC [ params… final-byte in 0x40..0x7E.
      if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x5B) {
        var j = i + 2;
        while (j < text.length) {
          final c = text.codeUnitAt(j);
          if (c >= 0x40 && c <= 0x7E) break;
          j++;
        }
        i = j + 1;
        continue;
      }
      // A lone ESC, or a two-character sequence: drop both.
      i += 2;
      continue;
    }
    out.writeCharCode(text.codeUnitAt(i));
    i++;
  }
  return out.toString();
}
