# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-08-03

Two crashes and one whitespace bug fixed, and the API grown to cover the cases
the four original combinators could not express: text whose width is not its
length, text that must not be re-indented, and indentation applied from the
outside.

### Fixed

- **Rendering no longer recurses once per document node.** `Doc::render` now
  walks the document with an explicit work stack. Document *depth* is unbounded
  in practice — combining N pieces builds an N-deep spine — so any sufficiently
  long document used to exhaust the call stack. A single `vert` of a few
  thousand lines was enough: it failed at around 8000 elements on `js` and 4000
  on `wasm-gc`. `wrap` was affected the same way, and by its own construction
  rather than the caller's. Documents of 200 000 elements now render on every
  backend.

- **Blank lines are no longer padded with their indentation.** A line that
  nothing is written to used to be emitted as a run of indentation spaces, so a
  `vert` step whose document rendered empty produced a whitespace-only line —
  including, at the end of a document, a whitespace-only final line.
  Indentation is now written lazily, on the first non-empty write to a line.

  ```moonbit
  horz([txt("ab"), vert([txt("x"), empty, txt("y")])]).display()
  // was: ["abx", "  ", "  y"]
  // now: ["abx", "",   "  y"]
  ```

  Spaces you write yourself are untouched: `vert([txt("a"), txt("  ")])` still
  renders its second line as `"  "`. **This changes output.** If you compare
  rendered documents against stored expectations, or post-process output to
  strip trailing whitespace, review those.

### Added

- **`txt_as(text, width)`** — like `txt`, but states the number of columns the
  text occupies rather than assuming one per UTF-16 code unit. `txt` is exact
  for ASCII and wrong for anything whose screen width differs from its encoded
  length. The two cases that matter: double-width characters (`txt_as("世界", 4)`)
  and escape sequences that occupy no columns (`txt_as("\u{1b}[31m", 0)`).
  Because every layout decision is made from the recorded width, a
  syntax-highlighted document now lays out exactly like the same document
  without colour.

- **`txt_raw(text)`** — writes text through verbatim. Newlines in it start a new
  line at column 0 and nothing is re-indented, unlike `txt_lines`, which lines
  continuations up with where the text started. For block comments,
  here-documents and multi-line string literals: text whose layout was already
  decided elsewhere. Text containing a newline has no flat width, so like `vert`
  it can never be chosen as the flat branch of an `if_flat`. Text without one
  behaves exactly like `txt`.

- **`nest(n, doc)`** — indents every line `doc` breaks onto by `n` further
  columns, leaving the line it starts on alone. This is the only way to indent a
  document you did not build yourself; prefixing spaces with `horz` indents the
  first line too, which is a different thing. Note that `horz` re-indents its
  right operand to the column its left operand ended at, so an enclosing `nest`
  has no effect there — though a `nest` applied inside that operand does.

- **`Doc::flat_width() -> Int?`** — reads the width a document occupies when
  rendered flat, or `None` when it cannot be flattened. This is the number the
  algorithm already caches at construction time and decides from, so asking is
  free; it was simply not readable from outside the package.

- **`Doc::write_to(buf, width~)`** — renders into a `StringBuilder` you already
  have, appending to whatever is in it.

- **`horz2`, `vert2`, `concat2`** — the two-document forms of the
  concatenations, for folding without allocating a throwaway array per step.
  They already existed internally.

- **`if_flat(flat, broken, reserve~)`** — `reserve` is the number of columns to
  keep free for whatever follows the choice. The layout is chosen in a single
  left-to-right pass, so `if_flat` cannot see its trailing context; when the
  caller knows that, say, two closing parens come next, `reserve=2` says so.
  Defaults to `0`, which is the previous behaviour. It does not enter the
  resulting document's own `flat_width` — it describes the context of that one
  choice, not how wide the document is.

### Changed

- **`if_flat` takes an optional `reserve` parameter.** Existing calls are
  unaffected. MoonBit does not allow a function with an optional parameter to be
  used as a first-class value, so `if_flat` can no longer be passed bare where a
  `(Doc, Doc) -> Doc` is expected; write `(a, b) => if_flat(a, b)`. (This is
  also why the text width is a separate `txt_as` rather than an optional
  parameter on `txt`: adding one would have broken every `.map(txt)`.)

- **`display_string` is now the primitive and `display` splits its result.**
  Rendering builds a single `StringBuilder` rather than one per line, so
  `display_string` allocates once instead of once per line plus a join. Output
  is unchanged for both.

- **`horz`, `vert` and `concat` combine their array by splitting it down the
  middle** rather than folding from one end, and **`wrap` collects its pieces
  and concatenates them once** rather than gluing them on one at a time. All
  three concatenations are associative, so the resulting layout is identical;
  what changes is that an array-built document is now O(log n) deep instead of
  O(n). Recursive traversals that have no stack of their own — notably the
  derived `Debug` — no longer overflow on large documents.

### Notes

- No change to the layout algorithm itself. Aside from the blank-line fix, every
  document renders exactly as it did before, at every width.
- The port's difference list in the README has been updated: `nest`, `txt_as`,
  `txt_raw`, `flat_width`, `write_to`, `if_flat`'s `reserve` and the binary
  concatenations have no upstream JavaScript equivalent.

## [0.1.0]

Initial release: a port of Brown PLT's JavaScript
[pretty-fast-pretty-printer](https://github.com/brownplt/pretty-fast-pretty-printer),
with the same layout algorithm and observable output, and an API reshaped to fit
MoonBit.
