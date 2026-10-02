/// The glyphs a chart is drawn with, as data rather than as literals.
///
/// Every chart in this package asks a [CharSet] for its characters instead of
/// embedding them. That is what makes [CharSets.ascii] possible: the same layout
/// code produces a chart for a UTF-8 terminal and for one that would print mojibake,
/// with no branches in the chart itself.
library;

/// A complete set of drawing glyphs.
///
/// Construct one to restyle every chart at once, or start from a built-in and use
/// [copyWith]. The built-ins are [CharSets.unicode], [CharSets.rounded],
/// [CharSets.ascii] and [CharSets.blocks].
///
/// ## On the ramps
///
/// [verticalRamp] and [horizontalRamp] must be ordered lightest to heaviest and
/// may be any length — a chart divides by `length`, so a 4-entry ramp simply gives
/// coarser output than an 8-entry one, and [CharSets.ascii] exploits that. Neither
/// includes an empty cell: the blank is [blank], so that a ramp's first entry is a
/// visible smallest mark rather than nothing.
class CharSet {
  /// Creates a character set. Every glyph must be supplied; use [copyWith] on a
  /// built-in to change only some.
  const CharSet({
    required this.name,
    required this.horizontal,
    required this.vertical,
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.cornerUpRight,
    required this.cornerUpLeft,
    required this.cornerDownRight,
    required this.cornerDownLeft,
    required this.teeUp,
    required this.teeDown,
    required this.teeLeft,
    required this.teeRight,
    required this.cross,
    required this.axisOrigin,
    required this.diagonalUp,
    required this.diagonalDown,
    required this.full,
    required this.verticalRamp,
    required this.horizontalRamp,
    required this.shades,
    required this.point,
    required this.pointHollow,
    required this.pointSmall,
    required this.blank,
    required this.heavyHorizontal,
    required this.dottedHorizontal,
  });

  /// A short identifier, for error messages and test names.
  final String name;

  /// A horizontal run: `─`.
  final String horizontal;

  /// A vertical run: `│`.
  final String vertical;

  /// Box corner, top-left: `┌` or `╭`.
  final String topLeft;

  /// Box corner, top-right: `┐` or `╮`.
  final String topRight;

  /// Box corner, bottom-left: `└` or `╰`.
  final String bottomLeft;

  /// Box corner, bottom-right: `┘` or `╯`.
  final String bottomRight;

  /// A line turning to leave upward and rightward: `╰`.
  ///
  /// The four `corner*` glyphs are named for the *motion* of a plotted line, not
  /// for a position in a box, because that is how a line chart picks them: a series
  /// that rises between two columns needs the glyph that leaves upward. They
  /// coincide with the box corners in most sets but are kept separate so a set can
  /// use sharp box corners with rounded curves.
  final String cornerUpRight;

  /// A line turning to leave upward and leftward: `╯`.
  final String cornerUpLeft;

  /// A line turning to leave downward and rightward: `╭`.
  final String cornerDownRight;

  /// A line turning to leave downward and leftward: `╮`.
  final String cornerDownLeft;

  /// A T-junction opening upward: `┴`.
  final String teeUp;

  /// A T-junction opening downward: `┬`.
  final String teeDown;

  /// A T-junction opening leftward: `┤`.
  final String teeLeft;

  /// A T-junction opening rightward: `├`.
  final String teeRight;

  /// A four-way crossing: `┼`.
  final String cross;

  /// Where the axes meet, bottom-left of a plot: `┼`.
  ///
  /// Separate from [cross] because the examples this package was built from use
  /// `┼` at the origin and `┤` up the y-axis, and a set may want to distinguish them.
  final String axisOrigin;

  /// A diagonal rising to the right: `╱`.
  final String diagonalUp;

  /// A diagonal falling to the right: `╲`.
  final String diagonalDown;

  /// A completely filled cell: `█`.
  final String full;

  /// Partial cells filling from the bottom up, lightest first: `▁▂▃▄▅▆▇█`.
  ///
  /// Used by sparklines and column charts, where a value's fractional part picks a
  /// glyph. Ordered lightest to heaviest; see the class doc.
  final List<String> verticalRamp;

  /// Partial cells filling from the left, lightest first: `▏▎▍▌▋▊▉█`.
  ///
  /// Gives horizontal bars sub-character precision, so a bar can end at `▊`
  /// instead of rounding to a whole cell.
  final List<String> horizontalRamp;

  /// Density shades, lightest first: `░▒▓█`.
  ///
  /// For heatmaps and stacked series, where the distinction is category or
  /// intensity rather than magnitude along an axis.
  final List<String> shades;

  /// A plotted point: `•`.
  final String point;

  /// An unfilled point, for a second series: `○`.
  final String pointHollow;

  /// A minimal point, for dense scatter plots: `·`.
  final String pointSmall;

  /// The empty cell. A space in every built-in set.
  final String blank;

  /// A heavier horizontal run for section rules: `═`.
  final String heavyHorizontal;

  /// A dotted horizontal run for section rules: `·`.
  final String dottedHorizontal;

  /// This set with the given glyphs replaced.
  CharSet copyWith({
    String? name,
    String? horizontal,
    String? vertical,
    String? topLeft,
    String? topRight,
    String? bottomLeft,
    String? bottomRight,
    String? cornerUpRight,
    String? cornerUpLeft,
    String? cornerDownRight,
    String? cornerDownLeft,
    String? teeUp,
    String? teeDown,
    String? teeLeft,
    String? teeRight,
    String? cross,
    String? axisOrigin,
    String? diagonalUp,
    String? diagonalDown,
    String? full,
    List<String>? verticalRamp,
    List<String>? horizontalRamp,
    List<String>? shades,
    String? point,
    String? pointHollow,
    String? pointSmall,
    String? blank,
    String? heavyHorizontal,
    String? dottedHorizontal,
  }) => CharSet(
    name: name ?? this.name,
    horizontal: horizontal ?? this.horizontal,
    vertical: vertical ?? this.vertical,
    topLeft: topLeft ?? this.topLeft,
    topRight: topRight ?? this.topRight,
    bottomLeft: bottomLeft ?? this.bottomLeft,
    bottomRight: bottomRight ?? this.bottomRight,
    cornerUpRight: cornerUpRight ?? this.cornerUpRight,
    cornerUpLeft: cornerUpLeft ?? this.cornerUpLeft,
    cornerDownRight: cornerDownRight ?? this.cornerDownRight,
    cornerDownLeft: cornerDownLeft ?? this.cornerDownLeft,
    teeUp: teeUp ?? this.teeUp,
    teeDown: teeDown ?? this.teeDown,
    teeLeft: teeLeft ?? this.teeLeft,
    teeRight: teeRight ?? this.teeRight,
    cross: cross ?? this.cross,
    axisOrigin: axisOrigin ?? this.axisOrigin,
    diagonalUp: diagonalUp ?? this.diagonalUp,
    diagonalDown: diagonalDown ?? this.diagonalDown,
    full: full ?? this.full,
    verticalRamp: verticalRamp ?? this.verticalRamp,
    horizontalRamp: horizontalRamp ?? this.horizontalRamp,
    shades: shades ?? this.shades,
    point: point ?? this.point,
    pointHollow: pointHollow ?? this.pointHollow,
    pointSmall: pointSmall ?? this.pointSmall,
    blank: blank ?? this.blank,
    heavyHorizontal: heavyHorizontal ?? this.heavyHorizontal,
    dottedHorizontal: dottedHorizontal ?? this.dottedHorizontal,
  );

  @override
  String toString() => 'CharSet($name)';
}

/// The built-in character sets.
abstract final class CharSets {
  /// Box-drawing with sharp corners and rounded line curves. The default.
  ///
  /// Sharp `┌┐└┘` for frames, because a frame reads as a frame; rounded `╭╮╰╯` for
  /// plotted lines, because a curve reads as a curve. Needs a UTF-8 terminal with
  /// a font covering Box Drawing and Block Elements, which is the common case.
  static const CharSet unicode = CharSet(
    name: 'unicode',
    horizontal: '─',
    vertical: '│',
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
    cornerUpRight: '╰',
    cornerUpLeft: '╯',
    cornerDownRight: '╭',
    cornerDownLeft: '╮',
    teeUp: '┴',
    teeDown: '┬',
    teeLeft: '┤',
    teeRight: '├',
    cross: '┼',
    axisOrigin: '┼',
    diagonalUp: '╱',
    diagonalDown: '╲',
    full: '█',
    verticalRamp: ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'],
    horizontalRamp: ['▏', '▎', '▍', '▌', '▋', '▊', '▉', '█'],
    shades: ['░', '▒', '▓', '█'],
    point: '•',
    pointHollow: '○',
    pointSmall: '·',
    blank: ' ',
    heavyHorizontal: '═',
    dottedHorizontal: '·',
  );

  /// Rounded corners everywhere, frames included.
  static const CharSet rounded = CharSet(
    name: 'rounded',
    horizontal: '─',
    vertical: '│',
    topLeft: '╭',
    topRight: '╮',
    bottomLeft: '╰',
    bottomRight: '╯',
    cornerUpRight: '╰',
    cornerUpLeft: '╯',
    cornerDownRight: '╭',
    cornerDownLeft: '╮',
    teeUp: '┴',
    teeDown: '┬',
    teeLeft: '┤',
    teeRight: '├',
    cross: '┼',
    axisOrigin: '┼',
    diagonalUp: '╱',
    diagonalDown: '╲',
    full: '█',
    verticalRamp: ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'],
    horizontalRamp: ['▏', '▎', '▍', '▌', '▋', '▊', '▉', '█'],
    shades: ['░', '▒', '▓', '█'],
    point: '•',
    pointHollow: '○',
    pointSmall: '·',
    blank: ' ',
    heavyHorizontal: '═',
    dottedHorizontal: '·',
  );

  /// Pure ASCII, for terminals and log pipelines that mangle anything else.
  ///
  /// Every glyph is a printable character below U+0080, so the output survives a
  /// latin-1 round trip, a Windows console in a legacy code page, and a CI log
  /// viewer that strips what it does not recognise.
  ///
  /// The ramps are necessarily shorter — ASCII has no eighth-blocks — so charts
  /// quantize more coarsely here. That is a visible loss of resolution and not a
  /// layout change: a chart drawn with this set occupies exactly the same columns
  /// and rows as one drawn with [unicode], which is asserted by a test.
  static const CharSet ascii = CharSet(
    name: 'ascii',
    horizontal: '-',
    vertical: '|',
    topLeft: '+',
    topRight: '+',
    bottomLeft: '+',
    bottomRight: '+',
    cornerUpRight: '\\',
    cornerUpLeft: '/',
    cornerDownRight: '/',
    cornerDownLeft: '\\',
    teeUp: '+',
    teeDown: '+',
    teeLeft: '+',
    teeRight: '+',
    cross: '+',
    axisOrigin: '+',
    diagonalUp: '/',
    diagonalDown: '\\',
    full: '#',
    // Four levels, not eight: `.:+#` reads as increasing ink in a way that an
    // arbitrary eight-character ASCII sequence does not.
    verticalRamp: ['.', ':', '+', '#'],
    horizontalRamp: ['.', ':', '+', '#'],
    shades: ['.', ':', '+', '#'],
    point: '*',
    pointHollow: 'o',
    pointSmall: '.',
    blank: ' ',
    heavyHorizontal: '=',
    dottedHorizontal: '.',
  );

  /// Block elements throughout, for a solid and heavy look.
  ///
  /// Frames are drawn with `▀▄█` rather than box-drawing lines, which suits a
  /// dashboard meant to read as panels of filled area.
  static const CharSet blocks = CharSet(
    name: 'blocks',
    horizontal: '▀',
    vertical: '█',
    topLeft: '█',
    topRight: '█',
    bottomLeft: '█',
    bottomRight: '█',
    cornerUpRight: '▀',
    cornerUpLeft: '▀',
    cornerDownRight: '▄',
    cornerDownLeft: '▄',
    teeUp: '█',
    teeDown: '█',
    teeLeft: '█',
    teeRight: '█',
    cross: '█',
    axisOrigin: '█',
    diagonalUp: '▞',
    diagonalDown: '▚',
    full: '█',
    verticalRamp: ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'],
    horizontalRamp: ['▏', '▎', '▍', '▌', '▋', '▊', '▉', '█'],
    shades: ['░', '▒', '▓', '█'],
    point: '●',
    pointHollow: '○',
    pointSmall: '▪',
    blank: ' ',
    heavyHorizontal: '█',
    dottedHorizontal: '▪',
  );

  /// All built-in sets, for tests that must cover every one.
  static const List<CharSet> all = [unicode, rounded, ascii, blocks];
}

/// The glyph for a cell that is [fraction] full, or null when it is empty.
///
/// For the *partial cell at the tip of a bar*: a bar of length 3.4 cells draws
/// three full cells and then whatever this returns for 0.4.
///
/// Returns null at or below zero, which is the point of having a separate function
/// from [levelGlyph] — an empty tip must draw **nothing**, not the lightest glyph.
/// Treating those as the same is the classic source of bars that appear one cell
/// too long.
///
/// [fraction] is clamped, so values outside 0..1 are safe.
String? partialGlyph(List<String> ramp, double fraction) {
  if (!(fraction > 0)) return null; // also catches NaN
  if (fraction >= 1) return ramp.last;
  final index = (fraction * ramp.length).ceil() - 1;
  return ramp[index.clamp(0, ramp.length - 1)];
}

/// The glyph for level [t] of [ramp], where 0 is the lightest and 1 the heaviest.
///
/// For *choosing one of N levels*: a sparkline column, or a heatmap cell's
/// intensity. Unlike [partialGlyph] this never returns null — level zero is the
/// lightest visible glyph, because a sparkline's minimum sample is still a sample
/// and should be drawn.
///
/// [t] is clamped, and NaN maps to the lightest glyph rather than throwing.
String levelGlyph(List<String> ramp, double t) {
  if (t.isNaN) return ramp.first;
  final index = (t.clamp(0.0, 1.0) * (ramp.length - 1)).round();
  return ramp[index];
}
