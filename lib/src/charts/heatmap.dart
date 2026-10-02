/// Heatmaps and calendar heatmaps.
library;

import '../canvas.dart';
import '../charset.dart';
import '../renderable.dart';
import '../scale.dart';
import '../theme.dart';
import '../width.dart';

/// A labelled grid of values.
class GridData {
  /// Creates a grid. [rows] is row-major.
  const GridData(
    this.rows, {
    this.rowLabels = const [],
    this.columnLabels = const [],
  });

  /// The values, one list per row.
  final List<List<num?>> rows;

  /// Names for the rows, in order.
  final List<String> rowLabels;

  /// Names for the columns, in order.
  final List<String> columnLabels;

  /// The widest row's length.
  int get columnCount => rows.fold(0, (m, r) => r.length > m ? r.length : m);

  /// Every value in the grid.
  Iterable<num?> get values => rows.expand((r) => r);
}

/// A heatmap: intensity as shade, over a labelled grid.
///
/// ```text
///        Mon Tue Wed Thu Fri Sat Sun
///   00h   ░   ░   ▒   ▓   ▓   █   ▓
///   04h   ░   ▒   ▒   ▓   █   █   ▓
///   08h   ▒   ▓   █   █   █   ▓   ▒
/// ```
///
/// A missing cell draws as a distinct glyph rather than as the lowest shade, because
/// "no data" and "the minimum" are different facts and a reader cannot recover the
/// difference once it is lost.
///
/// ## Sized by its content
///
/// Unlike most charts here, this one takes no width: its size is
/// `rowLabels + columns × cellWidth`, because a heatmap's cells *are* its data and
/// there is no honest way to fit more columns into fewer. Give it fewer columns, or
/// put it in a [Panel], which sizes itself to whatever it holds.
class Heatmap implements Renderable {
  /// Creates a heatmap of [data].
  const Heatmap(
    this.data, {
    this.theme = ChartTheme.plain,
    this.cellWidth = 2,
    this.title,
    this.min,
    this.max,
    this.showLegend = false,
    this.missingGlyph = ' ',
  });

  /// The grid to draw.
  final GridData data;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// How many columns each cell occupies.
  ///
  /// Two by default: a terminal cell is about twice as tall as it is wide, so a
  /// one-column cell makes the grid look vertically stretched.
  final int cellWidth;

  /// A heading above the grid.
  final String? title;

  /// Pins the bottom of the intensity scale.
  final num? min;

  /// Pins the top of the intensity scale.
  final num? max;

  /// Whether to print the shade ramp and its range underneath.
  final bool showLegend;

  /// What to draw for a missing cell.
  final String missingGlyph;

  @override
  List<String> renderLines() {
    if (data.rows.isEmpty) return const [];
    final chars = theme.charset;
    final measure = theme.width;
    final columns = data.columnCount;
    if (columns == 0) return const [];

    final scale = LinearScale.fit(
      data.values,
      1,
      mode: AxisMode.tight,
      min: min,
      max: max,
    );
    // Every value identical: use the middle shade rather than the lightest, which
    // would imply the data was all at its minimum.
    final extent = dataExtent(data.values);
    final uniform = extent != null && extent.$1 == extent.$2;

    var labelWidth = 0;
    for (final label in data.rowLabels) {
      final w = measure(label);
      if (w > labelWidth) labelWidth = w;
    }
    final gutter = labelWidth > 0 ? labelWidth + 1 : 0;

    final out = <String>[];
    if (title != null && title!.isNotEmpty) out.add(title!);

    if (data.columnLabels.isNotEmpty) {
      final header = StringBuffer(' ' * gutter);
      for (var c = 0; c < columns; c++) {
        final label = c < data.columnLabels.length ? data.columnLabels[c] : '';
        header.write(
          padToWidth(
            truncateToWidth(label, cellWidth, width: measure),
            cellWidth,
            align: TextAlign.center,
            width: measure,
          ),
        );
      }
      out.add(header.toString().trimRight());
    }

    for (var r = 0; r < data.rows.length; r++) {
      final row = StringBuffer();
      if (gutter > 0) {
        final label = r < data.rowLabels.length ? data.rowLabels[r] : '';
        row.write(
          padToWidth(
            truncateToWidth(label, labelWidth, ellipsis: '…', width: measure),
            labelWidth,
            align: TextAlign.right,
            width: measure,
          ),
        );
        row.write(' ');
      }
      for (var c = 0; c < columns; c++) {
        final value = c < data.rows[r].length ? data.rows[r][c] : null;
        final t = scale.normalize(value);
        final glyph = t == null
            ? missingGlyph
            : levelGlyph(chars.shades, uniform ? 0.5 : t);
        row.write(
          padToWidth(glyph, cellWidth, align: TextAlign.center, width: measure),
        );
      }
      out.add(row.toString().trimRight());
    }

    if (showLegend) {
      final ramp = chars.shades.join();
      out.add('${theme.format(scale.min)} $ramp ${theme.format(scale.max)}');
    }
    return out;
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// A calendar heatmap: one cell per day, weeks as columns.
///
/// ```text
///       M T W T F S S
///       ░ ░ ▒ ▓ █ ▓ ░
///       ░ ▒ ▓ █ █ ▓ ▒
/// ```
///
/// A date→grid adapter over [Heatmap]; the only real work is the calendar.
///
/// **Dates are bucketed in UTC.** A local-time day that is 23 or 25 hours long
/// because of a daylight-saving change would otherwise shift part of the grid by a
/// column, which is both wrong and very hard to notice.
class CalendarHeatmap implements Renderable {
  /// Creates a calendar heatmap over [values], keyed by day.
  ///
  /// [from] and [to] bound the range; by default it spans the data. [weekStart] is
  /// a `DateTime.monday`-style constant.
  const CalendarHeatmap(
    this.values, {
    this.from,
    this.to,
    this.theme = ChartTheme.plain,
    this.weekStart = DateTime.monday,
    this.title,
    this.dayLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    this.showLegend = false,
  });

  /// One value per day. Only the date part of each key is used.
  final Map<DateTime, num> values;

  /// The first day to show. Defaults to the earliest key.
  final DateTime? from;

  /// The last day to show. Defaults to the latest key.
  final DateTime? to;

  /// Glyphs, colours and formatting.
  final ChartTheme theme;

  /// Which weekday the first row represents, as a `DateTime` weekday constant.
  final int weekStart;

  /// A heading above the grid.
  final String? title;

  /// Single-letter names for the seven rows.
  final List<String> dayLabels;

  /// Whether to print the shade ramp and range underneath.
  final bool showLegend;

  /// Normalises a timestamp to a UTC day key. See the class note.
  static DateTime dayKey(DateTime t) => DateTime.utc(t.year, t.month, t.day);

  @override
  List<String> renderLines() {
    if (values.isEmpty) return const [];
    final byDay = <DateTime, num>{};
    for (final entry in values.entries) {
      final key = dayKey(entry.key);
      byDay[key] = (byDay[key] ?? 0) + entry.value;
    }

    final days = byDay.keys.toList()..sort();
    final start = from == null ? days.first : dayKey(from!);
    final end = to == null ? days.last : dayKey(to!);
    if (end.isBefore(start)) return const [];

    // Back up to the start of the week so the first column is a whole week and the
    // weekday rows line up throughout.
    var cursor = start;
    while (cursor.weekday != weekStart) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final weeks = <List<num?>>[];
    while (!cursor.isAfter(end)) {
      final week = <num?>[];
      for (var d = 0; d < 7; d++) {
        final day = cursor.add(Duration(days: d));
        week.add(day.isBefore(start) || day.isAfter(end) ? null : byDay[day]);
      }
      weeks.add(week);
      cursor = cursor.add(const Duration(days: 7));
    }

    // Transposed: rows are weekdays, columns are weeks, which is how a calendar
    // heatmap is conventionally read.
    final rows = <List<num?>>[
      for (var d = 0; d < 7; d++) [for (final week in weeks) week[d]],
    ];

    return Heatmap(
      GridData(
        rows,
        rowLabels: [
          for (var d = 0; d < 7; d++) d < dayLabels.length ? dayLabels[d] : '',
        ],
      ),
      theme: theme,
      title: title,
      cellWidth: 2,
      showLegend: showLegend,
    ).renderLines();
  }

  @override
  String render() => renderLines().join('\n');

  @override
  String toString() => render();
}

/// Draws a heatmap row onto [canvas], for embedding in a layout.
void drawHeatmapRow(
  Canvas canvas,
  int x,
  int y,
  List<num?> values, {
  required LinearScale scale,
  CharSet chars = CharSets.unicode,
  int cellWidth = 1,
  String missingGlyph = ' ',
}) {
  for (var i = 0; i < values.length; i++) {
    final t = scale.normalize(values[i]);
    canvas.set(
      x + i * cellWidth,
      y,
      t == null ? missingGlyph : levelGlyph(chars.shades, t),
    );
  }
}
