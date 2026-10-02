/// The one thing every chart in this package is.
library;

/// Something that renders itself as lines of text.
///
/// Charts return lines rather than printing them, and rather than writing to a
/// sink. Three reasons, and the first two are hard requirements this package was
/// built around:
///
/// * Printing needs `dart:io`, which rules out the web.
/// * A caller may need to route each line somewhere individually — across an
///   isolate boundary, into a log framework, into its own frame.
/// * A chart that returns lines can be *composed*: a panel can wrap one, a
///   dashboard can place several side by side, and neither needs to know what it
///   is holding.
abstract interface class Renderable {
  /// This object as individual lines, with no trailing newline.
  List<String> renderLines();

  /// This object as one string, lines joined by newlines.
  String render();
}
