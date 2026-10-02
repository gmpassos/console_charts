## 0.2.0

Five features, every one of them from actually using 0.1.0 to chart a training run
rather than from a wishlist.

**A logarithmic y axis** — `LineChart(logY: true)`, `LinearScale.log`,
`LinearScale.fitLog`. The one whose absence actively misleads: a series falling
2.4 → 0.004 puts more than half its samples on the *bottom row* of a linear chart, so
a plateau in the tail is invisible. Ticks are powers of ten, with 2 and 5 mantissas
added when a narrow domain would otherwise get one tick. Values at or below zero are
*off* the axis rather than at the bottom of it and render as gaps — on a
multiplicative scale a zero is not a small number. Ignored for a filled area, whose
whole meaning is its distance from zero.

**Braille plotting** — `LineStyle.braille`. A 2×4 dot grid per cell: twice the
horizontal and four times the vertical resolution for the same space, drawn with
Bresenham so segments are connected rather than staircased. Opt-in, because font
coverage for U+2800–U+28FF is good but not universal and a replacement box is worse
than a coarse glyph. Empty cells are left untouched rather than written as U+2800,
which is not a space and would survive trailing-whitespace trimming as an invisible
tail.

**Annotations** — `ReferenceLine` draws a horizontal rule at a value, with an optional
label the rule stops short of rather than running through. `EventMarker` draws a
vertical rule at a **data index**, so it stays attached to its event however the chart
is resampled, and only into empty cells so it never erases the series.

**`RingSeries`** — a bounded series for live data, since charts in a console usually
watch something happen. Two strategies: `RingDecimation.drop` keeps the last N ticks
at full resolution (the default — it is what "live" means), and `RingDecimation.fold`
keeps the whole history at falling resolution by folding four samples into their
minimum and maximum. `fold` sounds strictly better and is not: a preserved outlier
keeps setting the scale forever, so recent detail flattens against it. Both are
documented with that trade.

**`xCaption`** — captions the two ends of an index axis, which is the only place an
index axis is meaningful; spread tick labels imply the samples are evenly spaced in
time, which for a training run they are not.

### Fixed

* `reset` is now `ansiReset`, and the dead, misleading `indexScale` is gone. Both were
  renamed before the first publish; this note is for anyone who read the 0.1.0 source.

### Notes on three bugs these features started out with

Recorded because each was caught by a test that existed for a different reason, which
is the argument for having them.

* The x-axis caption located the plot area by **scanning the rendered axis row** — and
  with colour on, that row starts with an escape sequence, so the caption landed in a
  different column than in the plain render. The colour-equivalence invariant caught
  it. It is exactly the failure the cell-grid design exists to prevent, committed by
  the one piece of code that stepped outside the grid.
* `RingSeries` originally folded *pairs* into their minimum and maximum, which is a
  no-op — the min and max of two values are those two values — so it discarded nothing
  and the series grew without bound. It folds four into two now, with a regression test.
* The log axis' first "it spreads the data" test measured the count of distinct rows
  used, which linear can legitimately win: a fast early decay touches many rows once
  each. The real claim is about pile-up, and the test now measures that.

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
