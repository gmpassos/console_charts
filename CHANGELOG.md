## 0.1.0

First release.

Text charts as pure string computation: no `dart:io`, no dependencies, so the same
chart works in a CLI, a CI log, a worker isolate with no terminal, or a browser.

**Charts.** `sparkline` and `SparklineGroup`; `LineChart` (multi-series, `smooth:`,
`fill:`) and `AreaChart`; `BarChart` (plain, grouped, stacked, 100%-stacked) and
`ColumnChart` (vertical, stacked, negative values); `Histogram`, `BlockChart`;
`Gauge`, `ProgressBar`, `BulletChart`; `BoxPlot`; `ScatterChart`;
`CandlestickChart`, `WaterfallChart`; `Heatmap`, `CalendarHeatmap`.

**Layout.** `Panel`, `Dashboard`, `Table`, `rule`, `hstack`, `vstack` — anything
`Renderable` composes, including a chart inside a panel inside a dashboard.

**Character sets.** `CharSets.unicode`, `rounded`, `ascii` and `blocks`, with every
glyph read from the set rather than embedded, so one switch restyles everything. The
ASCII fallback is a real fallback: a chart drawn with it occupies exactly the same
rows and columns as the Unicode one, cell for cell.

**Colour.** Opt-in per theme, SGR only — never cursor movement — so charts coexist
with terminal UIs that manage the screen. Colour cannot change layout by
construction: the canvas stores a glyph and a style per cell and escape sequences are
synthesised only at the end, so nothing that measures text can see one.

**Extension points.** `renderPlotFrame` and `renderRowFrame` are exported, so a new
chart type is a few lines of "paint the body" with the layout, degradation and colour
handling inherited.

Tested with a sweep of every chart type against fourteen awkward inputs — empty,
single-valued, all-equal, NaN, infinite, all-negative, gap-ridden, 1e300, 1e-300,
five thousand points — at five sizes down to 1×1, asserting that nothing throws,
nothing exceeds its width, and nothing emits a stray control character. Every
rendered sample in the README is pinned by a test, and a test reads `lib/` to prove
no file imports `dart:io`.
