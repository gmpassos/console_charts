/// Measuring how much horizontal space text occupies in a terminal.
///
/// Every chart in this package aligns things in columns, so it needs to know how
/// wide a label is. `String.length` is the wrong answer twice over: it counts UTF-16
/// code units, so an emoji counts 2, and it assumes every character occupies one
/// column, which CJK text and combining accents both violate.
library;

/// How many terminal columns [text] occupies.
///
/// Supply your own to [DisplayWidth.custom] if the built-in rules are not enough
/// for your data — see [measureWidth] for exactly what the default covers.
typedef WidthFn = int Function(String text);

/// The width function a chart uses to lay out text.
///
/// Defaults to [measureWidth]. The indirection exists because full Unicode width
/// handling needs grapheme-cluster segmentation, which needs a dependency this
/// package deliberately does not have; see [measureWidth] for the consequence and
/// [DisplayWidth.custom] for the escape hatch.
extension type const DisplayWidth(WidthFn measure) {
  /// The built-in rules: [measureWidth].
  static const DisplayWidth standard = DisplayWidth(measureWidth);

  /// One column per UTF-16 code unit — `String.length`.
  ///
  /// Only correct for pure ASCII, but it is the fastest option and charts whose
  /// labels are known to be ASCII lose nothing by it.
  static const DisplayWidth ascii = DisplayWidth(_asciiWidth);

  /// Your own measurement, for text the default handles badly.
  ///
  /// The obvious use is wiring in `package:characters` so that grapheme clusters
  /// are measured as units:
  ///
  /// ```dart
  /// DisplayWidth.custom((s) => s.characters.length);
  /// ```
  const DisplayWidth.custom(WidthFn fn) : this(fn);

  /// The width of [text] under these rules.
  int call(String text) => measure(text);
}

int _asciiWidth(String text) => text.length;

/// How many terminal columns [text] occupies, by inspecting each code point.
///
/// Three outcomes per code point:
///
/// * **0** — combining marks, zero-width joiners and spaces, variation selectors
///   and other formatting characters. These modify a neighbour rather than
///   occupying space of their own, so counting them would over-measure.
/// * **2** — East Asian Wide and Fullwidth characters, and emoji. A terminal
///   renders these over two columns.
/// * **1** — everything else.
///
/// ## What this deliberately gets wrong
///
/// Width is computed per *code point*, not per *grapheme cluster*. For a
/// ZWJ emoji sequence such as a family emoji the parts are counted separately, so
/// the result over-measures even though every individual rule above is applied
/// correctly. Getting that right requires grapheme segmentation, which means a
/// dependency; this package has none by design. If your labels contain such
/// sequences, pass a [DisplayWidth.custom] backed by `package:characters`.
///
/// Control characters count 0, which is a measurement rather than an endorsement:
/// a chart should not be fed them, because a terminal's response to one is its own
/// business and no width is right.
int measureWidth(String text) {
  var total = 0;
  for (final rune in text.runes) {
    total += runeWidth(rune);
  }
  return total;
}

/// The column count of a single code point — 0, 1 or 2. See [measureWidth].
int runeWidth(int rune) {
  // Fast path. Everything printable below U+0300 is one column, which covers all
  // ASCII and Latin-1 and so the overwhelming majority of real labels.
  if (rune < 0x0300) return rune < 0x20 || rune == 0x7F ? 0 : 1;
  if (_isZeroWidth(rune)) return 0;
  if (_isWide(rune)) return 2;
  return 1;
}

/// Combining marks and format characters, which attach to a neighbour.
bool _isZeroWidth(int r) =>
    // Combining diacriticals, and the three later extension blocks.
    (r >= 0x0300 && r <= 0x036F) ||
    (r >= 0x1AB0 && r <= 0x1AFF) ||
    (r >= 0x1DC0 && r <= 0x1DFF) ||
    (r >= 0x20D0 && r <= 0x20F0) ||
    // Hebrew points and Arabic marks — common enough in real text to matter.
    (r >= 0x0591 && r <= 0x05BD) ||
    (r >= 0x0610 && r <= 0x061A) ||
    (r >= 0x064B && r <= 0x065F) ||
    // Devanagari and Thai combining signs.
    (r >= 0x0900 && r <= 0x0903) ||
    (r >= 0x093A && r <= 0x094F && r != 0x093B && r != 0x093D) ||
    (r >= 0x0E31 && r <= 0x0E3A) ||
    (r >= 0x0E47 && r <= 0x0E4E) ||
    // Zero-width space/joiners and the bidi marks.
    (r >= 0x200B && r <= 0x200F) ||
    (r >= 0x202A && r <= 0x202E) ||
    (r >= 0x2060 && r <= 0x2064) ||
    // Variation selectors, both planes, and the byte-order mark.
    (r >= 0xFE00 && r <= 0xFE0F) ||
    (r >= 0xE0100 && r <= 0xE01EF) ||
    r == 0xFEFF ||
    // Combining half marks.
    (r >= 0xFE20 && r <= 0xFE2F);

/// East Asian Wide, Fullwidth, and emoji — two columns in a terminal.
///
/// ## East Asian *Ambiguous* is deliberately absent, and that is load-bearing
///
/// Box drawing (U+2500-257F), block elements (U+2580-259F), geometric shapes
/// (U+25A0-25FF), arrows (U+2190-21FF) and `…` are classed East Asian Ambiguous:
/// one column in a Western locale, two under a CJK one. **This package draws
/// charts out of exactly those code points.** Measuring them as wide would double
/// the width of every frame, axis and bar and align nothing, so they are treated
/// as one column here.
///
/// A caller running a CJK locale whose terminal really does render them doubled
/// wants [CharSets.ascii] rather than a different width rule — ASCII glyphs are
/// unambiguously narrow everywhere.
bool _isWide(int r) =>
    // Hangul Jamo initial consonants.
    (r >= 0x1100 && r <= 0x115F) ||
    // CJK radicals through to the end of the CJK symbols block. U+303F is
    // explicitly Narrow, which is why this stops one short of it.
    (r >= 0x2E80 && r <= 0x303E) ||
    // Hiragana, Katakana, Bopomofo, Hangul compatibility Jamo, Kanbun, and the
    // enclosed CJK letters and months.
    (r >= 0x3041 && r <= 0x33FF) ||
    // CJK Extension A, then the main unified ideographs, then Yi.
    (r >= 0x3400 && r <= 0x4DBF) ||
    (r >= 0x4E00 && r <= 0x9FFF) ||
    (r >= 0xA000 && r <= 0xA4CF) ||
    // Hangul Jamo Extended-A and the Hangul syllables.
    (r >= 0xA960 && r <= 0xA97F) ||
    (r >= 0xAC00 && r <= 0xD7A3) ||
    // CJK compatibility ideographs, vertical forms, CJK compatibility forms.
    (r >= 0xF900 && r <= 0xFAFF) ||
    (r >= 0xFE10 && r <= 0xFE19) ||
    (r >= 0xFE30 && r <= 0xFE6F) ||
    // Fullwidth forms, and the fullwidth currency and bar signs.
    (r >= 0xFF00 && r <= 0xFF60) ||
    (r >= 0xFFE0 && r <= 0xFFE6) ||
    // Emoji: miscellaneous symbols and pictographs, emoticons, transport,
    // supplemental symbols. Terminals render these double-width.
    (r >= 0x1F300 && r <= 0x1F64F) ||
    (r >= 0x1F680 && r <= 0x1F6FF) ||
    (r >= 0x1F900 && r <= 0x1F9FF) ||
    (r >= 0x1FA70 && r <= 0x1FAFF) ||
    // CJK Extension B and beyond.
    (r >= 0x20000 && r <= 0x2FFFD) ||
    (r >= 0x30000 && r <= 0x3FFFD);

/// [text] truncated to at most [max] columns, measured by [width].
///
/// Truncation is by whole code points, so a multi-column character is dropped
/// rather than half-printed. When [ellipsis] is given and [text] does not fit, the
/// result ends with it and still respects [max] — so the ellipsis displaces
/// content instead of overflowing, which is the behaviour a fixed-width column
/// needs. If [ellipsis] alone is wider than [max] the result is empty, because
/// there is no honest way to render it.
String truncateToWidth(
  String text,
  int max, {
  String ellipsis = '',
  DisplayWidth width = DisplayWidth.standard,
}) {
  if (max <= 0) return '';
  if (width(text) <= max) return text;

  final tailWidth = width(ellipsis);
  if (tailWidth > max) return '';
  final budget = max - tailWidth;

  final kept = StringBuffer();
  var used = 0;
  for (final rune in text.runes) {
    final w = runeWidth(rune);
    if (used + w > budget) break;
    kept.writeCharCode(rune);
    used += w;
  }
  return '$kept$ellipsis';
}

/// [text] padded with spaces to exactly [target] columns.
///
/// Padding goes on the right for [align] of [TextAlign.left], the left for
/// [TextAlign.right], and is split for [TextAlign.center] with any odd column
/// going right. Text already at or over [target] is returned unchanged — use
/// [truncateToWidth] first if it must fit.
String padToWidth(
  String text,
  int target, {
  TextAlign align = TextAlign.left,
  DisplayWidth width = DisplayWidth.standard,
}) {
  final deficit = target - width(text);
  if (deficit <= 0) return text;
  return switch (align) {
    TextAlign.left => text + ' ' * deficit,
    TextAlign.right => ' ' * deficit + text,
    TextAlign.center =>
      ' ' * (deficit ~/ 2) + text + ' ' * (deficit - deficit ~/ 2),
  };
}

/// Where text sits within a column wider than itself.
enum TextAlign {
  /// Against the left edge, padding on the right.
  left,

  /// Against the right edge, padding on the left. What numbers usually want.
  right,

  /// Centred, with an odd leftover column going to the right.
  center,
}
