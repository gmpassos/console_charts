# console_charts

[![pub package](https://img.shields.io/pub/v/console_charts.svg?logo=dart&logoColor=00b9fc)](https://pub.dev/packages/console_charts)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Dart CI](https://github.com/gmpassos/console_charts/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/gmpassos/console_charts/actions/workflows/dart.yml)
[![codecov](https://codecov.io/gh/gmpassos/console_charts/branch/main/graph/badge.svg)](https://codecov.io/gh/gmpassos/console_charts)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/console_charts?logo=git&logoColor=white)](https://github.com/gmpassos/console_charts/releases)
[![New Commits](https://img.shields.io/github/commits-since/gmpassos/console_charts/latest?logo=git&logoColor=white)](https://github.com/gmpassos/console_charts/network)
[![Last Commits](https://img.shields.io/github/last-commit/gmpassos/console_charts?logo=git&logoColor=white)](https://github.com/gmpassos/console_charts/commits/main)
[![Pull Requests](https://img.shields.io/github/issues-pr/gmpassos/console_charts?logo=github&logoColor=white)](https://github.com/gmpassos/console_charts/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/gmpassos/console_charts?logo=github&logoColor=white)](https://github.com/gmpassos/console_charts)
[![License](https://img.shields.io/github/license/gmpassos/console_charts?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/console_charts/blob/main/LICENSE)

Charts for the console and terminal, rendered as plain text.

No `dart:io`, so it works on the web too. No dependencies.

```dart
import 'package:console_charts/console_charts.dart';

void main() {
  print(sparkline([1, 3, 2, 5, 8, 6, 9]));
  // ▁▃▂▄▇▅█
}
```

```text
100 ┤                    ╭──────╮
    │                  ╭─╯      ╰──╮
 80 ┤               ╭──╯           ╰─╮
    │            ╭──╯                ╰─╮
 60 ┤         ╭──╯                     ╰──╮
    │      ╭──╯                           ╰─╮
 40 ┤    ╭─╯                                ╰───╮
    │ ╭──╯                                      ╰───────
 20 ┤─╯
    ┼───────────────────────────────────────────────────
     Jan    Feb      Mar     Apr     May      Jun    Jul
```

## What's in it

| | |
| --- | --- |
| **One line** | `sparkline`, `SparklineGroup` |
| **Lines** | `LineChart` (multi-series, `smooth:`, `fill:`), `AreaChart` |
| **Bars** | `BarChart` (plain, grouped, stacked, 100%-stacked), `ColumnChart` (vertical, stacked, negatives), `Histogram`, `BlockChart` |
| **Meters** | `Gauge`, `ProgressBar`, `BulletChart` |
| **Distributions** | `BoxPlot`, `Histogram` |
| **Points** | `ScatterChart` |
| **Finance** | `CandlestickChart`, `WaterfallChart` |
| **Grids** | `Heatmap`, `CalendarHeatmap` |
| **Layout** | `Panel`, `Dashboard`, `Table`, `rule`, `hstack`, `vstack` |
| **Live data** | `RingSeries` |
| **Annotations** | `ReferenceLine`, `EventMarker` |

Run `dart run example/console_charts_example.dart` for a gallery of all of them.

## Three things to know

### Width is always explicit

No chart detects the terminal's size, because that needs `dart:io` and is
unavailable or misleading exactly where charts are most useful — a web app, a CI
log, a worker isolate whose `stdout` is a pipe. Pass a width:

```dart
BarChart.of([82, 64, 43], labels: ['a', 'b', 'c'], width: 40);
```

On the Dart VM, `stdout.terminalColumns` is the value you want — guarded, because
it *throws* when output is not a terminal:

```dart
int terminalWidth() {
  try {
    return stdout.terminalColumns;
  } on Object {
    return 80;
  }
}
```

### Charts return strings; they never print

Every chart gives you `render()` or `renderLines()`. Nothing is written for you, so
a chart can be logged, sent across an isolate, embedded in a frame, or built on a
platform with no console at all.

### A gap is not a zero

`null`, `NaN` and infinities are **missing data**. A line breaks, a sparkline cell
goes blank, a bar draws nothing. None of them is plotted at the baseline, because a
fabricated zero in a loss curve or an error count is usually the most alarming point
on the chart.

```dart
sparkline([5, 6, 7, null, null, 7, 6, 5]);  // ▁▅█  █▅▁
```

The one deliberate exception, documented where it happens: in a **stacked** bar a
missing value counts as zero, because a stack is a composition and an absent part
contributes nothing.

## A log axis, for anything that decays

A series that falls by *factors* — a training loss, a latency tail — spends most of
its length squashed into the bottom row of a linear chart, so a plateau in the tail
is invisible. On a log axis a constant decay rate is a straight line and a plateau is
a visible bend:

```dart
LineChart.of(loss, width: 60, height: 9, logY: true);
```

```text
linear y — the tail is one flat row        log y — the same data
3 ┤                                           10 ┤
  │╮                                             │────╮
2 ┤╰─╮                                           │    ╰──────────╮
  │  ╰─╮                                     0.1 ┤               ╰──────────╮
1 ┤    ╰──╮                                      │                          ╰───
  │       ╰───╮                                  │
0 ┼           ╰──────────────────────      0.001 ┤
```

Values at or below zero are *off* a log axis rather than at the bottom of it, so they
render as gaps. On a multiplicative scale a zero is not a small number.

## Braille, for 8× the resolution

`LineStyle.braille` plots into a 2×4 dot grid per cell — twice the horizontal and four
times the vertical resolution, same space. Better for *shape*, worse for reading a
value off a row, and opt-in because font coverage is good but not universal:

```text
braille, 8 rows                   glyph, same 8 rows
3 ┤                               3 ┤
  │⠢⡀                               │╮
2 ┤ ⠈⠢⡀                           2 ┤╰─╮
  │   ⠈⠒⢄                           │  ╰──╮
1 ┤      ⠉⠒⠤⣀                     1 ┤     ╰────╮
  │          ⠉⠑⠒⠤⢄⣀⡀                │          ╰─────────╮
0 ┼                ⠈⠉⠉⠒⠒⠢⠤⠤⢄⣀⣀⣀   0 ┼                    ╰──────────
```

## Annotations

A curve says what happened; an annotation says *compared with what*.

```dart
LineChart.of(
  data,
  width: 60, height: 10,
  references: [ReferenceLine(80, label: 'target')],
  markers: [EventMarker(4, label: 'grew')],
  xCaption: ('step 0', 'step 2000'),
);
```

`EventMarker` takes an index in **data** space, so it stays attached to its event when
the chart is resampled to a different width, and it draws only into empty cells so it
never erases the series. `xCaption` labels the two ends of an index axis, which is the
only place an index axis is meaningful — spread tick labels would imply the samples
are evenly spaced in time.

## Live data

Charts in a console usually watch something *happen*, which means appending a value
per tick forever. `RingSeries` is bounded:

```dart
final loss = RingSeries(capacity: 512);
for (final step in steps) {
  loss.add(step.loss);
  print(sparkline(loss.values));
}
```

Two strategies, and the difference is real rather than cosmetic:

| | |
| --- | --- |
| `RingDecimation.drop` | the last N ticks at full resolution — what "live" means. Default. |
| `RingDecimation.fold` | the *whole* history at falling resolution, folding four samples into their min and max, so no spike is ever averaged away |

`fold` sounds strictly better and is not: a preserved outlier keeps setting the scale
forever, so recent detail flattens against it. 5000 samples into a capacity of 64:

```text
drop: max 16.1   █████▇▇▇▇▇▇▆▆▆▆▆▆▅▅▅▅▅▅▄▄▄▄▄▄▃▃▃▃▃▂▂▂▂▂▁▁▁▁▁
fold: max 134.4  ▁█▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁
```

The spike survives `fold` and is lost to `drop`; everything else is legible under
`drop` and flat under `fold`. Pick by the question you are asking.

## Character sets

Every glyph comes from a `CharSet`, so one switch restyles everything — and the
ASCII fallback is a real fallback, not a degraded afterthought. A chart drawn with
`CharSets.ascii` occupies exactly the same rows and columns as the Unicode one,
cell for cell; only the glyphs differ. A test asserts it.

```dart
LineChart.of(data, width: 44, height: 7, theme: ChartTheme.ascii);
```

```text
100 +                  /-\
 80 +              /---/ \-----\
 60 +          /---/           \---\
    |      /---/                   \---\
 40 +  /---/                           \----
 20 +--/
    +---------------------------------------
```

Built in: `CharSets.unicode` (default), `rounded`, `ascii`, `blocks`. Or build your
own, or `copyWith` one.

## Colour

Off by default, and opt-in per theme:

```dart
LineChart.of(data, width: 50, height: 10, theme: ChartTheme.colorful);
```

Only SGR colour sequences are ever emitted — never cursor movement, never `\r` — so
charts coexist with terminal UIs that manage the screen themselves.

Colour cannot change layout, by construction rather than by care: the canvas stores
a glyph and a style per cell and escapes are synthesised only at the end, so nothing
that measures text ever sees one. The test for it is one line, applied to every chart
type:

```dart
expect(stripAnsi(chart(colourful).render()), chart(plain).render());
```

## Dashboards

Anything `Renderable` composes, including a chart inside a panel inside a dashboard:

```dart
Dashboard([
  [Panel(gauge, title: 'System'), Panel(sparks, title: 'Training')],
  [Panel(bars, title: 'Log levels')],
], title: 'Run 1842', framed: true);
```

```text
┌─ Run 1842 ──────────────────────────────────────────────┐
│ ┌─ System ───────────────┐ ┌─ Training ───────────────┐ │
│ │ cpu [████████▏░░░] 68% │ │ loss █▆▅▄▃▃▂▂▂▁▁▁ 0.1806 │ │
│ │ ram [█████████▉░░] 82% │ │ acc  ▁▃▄▅▆▇▇▇████ 0.8948 │ │
│ └────────────────────────┘ └──────────────────────────┘ │
│ ┌─ Log levels ─────────────────────────────────────┐    │
│ │ warn  ███████████████████████████████████████ 12 │    │
│ │ error ██████████████████████▊                  7 │    │
│ │ fatal █████████▊                               3 │    │
│ └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Extending

The parts charts are built from are exported, so a new chart type does not need a
fork. `renderPlotFrame` hands you axes and a `Plot` to draw into;
`renderRowFrame` hands you aligned labelled rows. Either way the layout, the
degradation behaviour and the colour handling come for free:

```dart
class StepChart implements Renderable {
  const StepChart(this.values, {this.width = 40, this.height = 10});

  final List<num?> values;
  final int width;
  final int height;

  @override
  List<String> renderLines() => renderPlotFrame(
    width: width,
    height: height,
    yScale: LinearScale.fit(values, height),
    xScale: (plotWidth) => LinearScale.index(values.length, plotWidth),
    draw: (plot) {
      for (var x = 0; x < plot.width; x++) {
        plot.fillQuantity(x, values[x * values.length ~/ plot.width]);
      }
    },
  );

  @override
  String render() => renderLines().join('\n');
}
```

## Notes on correctness

A text chart is mostly arithmetic about cells, and the ways it goes wrong are
specific. The ones handled here, each with a test:

- **A single `NaN` cannot poison a domain.** `math.max(1.0, double.nan)` is `NaN`,
  so the obvious `reduce(math.max)` would make the scale `NaN`, every position
  `NaN`, and the chart silently blank with no error to explain it.
- **Percentiles filter before sorting.** `double.nan.compareTo(1.0)` is `1`, so NaN
  sorts to the *end* of a list rather than being rejected, and every high percentile
  a box plot draws would be wrong.
- **East Asian Ambiguous characters measure one column.** Box drawing and block
  elements are Ambiguous — and they are what this package draws with. Measuring them
  as wide would double every frame.
- **Points and quantities scale differently.** A plotted point maps over `size - 1`
  so the domain's top reaches the last row; a bar maps over `size` because it fills
  area. Swapping them leaves a full bar one cell short, or a line unable to reach
  the top.
- **Axis ticks round to 1/2/5.** An axis reads `0 20 40 60 80 100`, not
  `0 16.7 33.3`. Decimals come from the step's exponent, so `0.1 + 0.2` cannot reach
  a label as `0.30000000000000004`.
- **Stacked segments sum to exactly the bar width**, by largest-remainder
  apportionment. Rounding each segment alone leaves a one-cell hole in some rows and
  overflows others.
- **A gauge at 100% has no gap.** `(0.9999999 * cells * 8).floor()` misses the last
  eighth; full and empty are exact.
- **The last histogram bin is closed**, so the largest sample is counted rather than
  silently dropped.
- **Smoothing cannot overshoot.** Monotone cubic (Fritsch–Carlson), not a natural
  spline, which would draw a loss curve dipping below zero.
- **Dates bucket in UTC.** A 23-hour local day from a daylight-saving change would
  shift part of a calendar heatmap by a column.

Known limits, stated rather than hidden:

- **Width is measured per code point, not per grapheme cluster**, so a ZWJ emoji
  sequence over-measures. Fixing that needs a dependency; pass
  `DisplayWidth.custom((s) => s.characters.length)` if you need it.
- **Bars cannot have sub-cell precision leftward or downward.** Unicode's partial
  blocks are all anchored left and bottom, so a negative horizontal bar draws
  nothing (use `ColumnChart`, which has a baseline row) and downward column fills
  quantize to whole cells.

## Running the example and tests

```sh
dart pub get
dart analyze
dart test
dart run example/console_charts_example.dart
```

The suite also runs compiled to JavaScript, which is how the web-safety claim is
actually checked rather than merely asserted:

```sh
dart test -p chrome
```

Three tests self-skip there (`@TestOn('vm')` — they read `lib/` from disk to prove no
file imports `dart:io`), so the browser count is lower than the VM's.

That job is not ceremonial. It caught a real divergence: `value is int` means "boxed
as an int" on the VM but "integral-valued" under dart2js, where both `1.2e9 is int`
and `double.infinity is int` are true — so axis labels silently differed between a
CLI and a browser. Nothing else would have found it.

CI runs format, `analyze --fatal-infos --fatal-warnings`, `dependency_validator`,
`dart doc`, `pub publish --dry-run`, the VM suite with coverage, the browser suite,
and a JavaScript compile of the example.

# Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

[Apache License - Version 2.0][apache_license]

[apache_license]: https://www.apache.org/licenses/LICENSE-2.0.txt
