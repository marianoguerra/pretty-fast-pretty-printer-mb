# pretty-fast-pretty-printer

A linear-time pretty printing library for MoonBit.

This is a port of Brown PLT's JavaScript
[pretty-fast-pretty-printer](https://github.com/brownplt/pretty-fast-pretty-printer).
The layout algorithm and the observable output are the same; the API has been
reshaped to fit MoonBit.

## Installing

```sh
moon add marianoguerra/pretty-fast-pretty-printer
```

The package name contains dashes, so it cannot be referenced under its default
alias. Give it one in the `moon.pkg` of each package that uses it:

```
import {
  "marianoguerra/pretty-fast-pretty-printer" @pp,
}
```

and then reach for it as `@pp.txt("...")`, `@pp.vert([...])`, and so on. The
examples below drop the prefix for readability, since they run inside this
module's own tests.

## What it is for

Pretty printing is printing source code *nicely*. Walking an AST and emitting
text is easy; the hard part is deciding where to break long lines, and keeping
indentation correct once you do. Doing that by hand is tedious, and it is very
easy to write code that takes exponential time.

With this library you build a `Doc` — a description of **all** the ways your
program may be laid out — and then ask for the one that fits a given width:

```mbt check
///|
test {
  let cond = txt("x > 0")
  let body = txt("print(x)")
  let doc = vert([
    horz([txt("while ("), cond, txt(") {")]),
    horz([txt("  "), body]),
    txt("}"),
  ])
  inspect(
    doc.display_string(width=80),
    content=(
      #|while (x > 0) {
      #|  print(x)
      #|}
    ),
  )
}
```

Choosing the layout takes a single left-to-right pass over the document, so
printing is linear in the size of the document no matter how deeply the choices
nest.

## The four combinators

Almost everything can be built from four of them.

**`txt(s)`** prints `s`. It is the only way plain text enters a document, and
`s` may not contain a newline (use `txt_lines` or `vert` for that).

**`vert([...])`** stacks documents vertically, indenting each one to the column
the first one started at.

```mbt check
///|
test {
  inspect(
    vert([txt("Hello,"), txt("world!")]).display_string(),
    content=(
      #|Hello,
      #|world!
    ),
  )
}
```

**`horz([...])`** joins documents horizontally: the next one starts where the
previous one ended, and lines up with the *last line* of the previous one.

```mbt check
///|
test {
  let doc = horz([txt("BEGIN "), vert([txt("first line"), txt("second line")])])
  inspect(
    doc.display_string(),
    content=(
      #|BEGIN first line
      #|      second line
    ),
  )
}
```

**`if_flat(flat, broken, reserve=0)`** chooses. It uses `flat` if `flat`
contains no line breaks *and* fits in the remaining width; otherwise it uses
`broken`.

```mbt check
///|
test {
  let doc = if_flat(
    txt("[1, 2, 3]"),
    vert([txt("[1,"), txt(" 2,"), txt(" 3]")]),
  )
  inspect(doc.display_string(width=20), content="[1, 2, 3]")
  inspect(
    doc.display_string(width=5),
    content=(
      #|[1,
      #| 2,
      #| 3]
    ),
  )
}
```

The trick that makes this fast: every `Doc` caches the width it would occupy if
rendered flat, computed once when it is built. `if_flat` compares that cached
number against the space left on the line, so it never renders a branch it
throws away. `doc.flat_width()` reads that cached number: `Some(n)` if the
document can be flattened, `None` if it cannot.

Deciding in one left-to-right pass means `if_flat` cannot see what comes *after*
it. When you know — because you are about to append two closing parens, say —
`reserve` tells it:

```mbt check
///|
test {
  let flat = txt("[1, 2]")
  let broken = vert([txt("[1,"), txt(" 2]")])
  // The group fits in seven columns, so it stays flat and the `))` overflows.
  inspect(
    horz([if_flat(flat, broken), txt("))")]).display_string(width=7),
    content="[1, 2]))",
  )
  // Told that two more columns follow, it breaks instead.
  inspect(
    horz([if_flat(flat, broken, reserve=2), txt("))")]).display_string(width=7),
    content=(
      #|[1,
      #| 2]))
    ),
  )
}
```

## The rest of the API

`concat([...])` is like `horz`, but keeps the indentation fixed instead of
following the last line. You will almost always want `horz`.

`nest(n, doc)` indents every line `doc` breaks onto by `n` further columns,
leaving the line it starts on alone. It is how you indent a document you did not
build yourself: prefixing spaces with `horz` would indent the first line too.

```mbt check
///|
test {
  let given = vert([txt("first line"), txt("second line")])
  inspect(
    nest(2, given).display_string(),
    content=(
      #|first line
      #|  second line
    ),
  )
  inspect(
    horz([txt("  "), given]).display_string(),
    content=(
      #|  first line
      #|  second line
    ),
  )
}
```

`full_line(doc)` says nothing may follow `doc` on its line. It works by
declaring `doc` un-flattenable, so any enclosing `if_flat` rejects the branch
containing it.

`horz2`, `vert2` and `concat2` are the two-document forms, for folding without
allocating a throwaway array at every step.

`display(width=...)` returns one string per line; `display_string(width=...)`
returns them joined by newlines, and is the cheaper of the two. `write_to(buf,
width=...)` appends into a `StringBuilder` you already have. All default to a
width of 80.

`empty` is the empty document.

### Measuring text that is not plain ASCII

`txt` measures text in UTF-16 code units. That is exact for ASCII, and wrong
whenever a string's width on screen differs from its encoded length —
double-width characters, or escape sequences that occupy no columns at all.
`txt_as(text, width)` states the width instead of guessing it:

```mbt check
///|
test {
  // A CJK character is one UTF-16 unit but occupies two columns.
  assert_eq(txt_as("世界", 4).flat_width(), Some(4))
  // An ANSI colour escape is five UTF-16 units and occupies none, so a
  // syntax-highlighted document lays out exactly like the plain one.
  let red = txt_as("\u{1b}[31m", 0)
  let reset = txt_as("\u{1b}[0m", 0)
  assert_eq(horz([red, txt("hello"), reset]).flat_width(), Some(5))
}
```

### Text whose layout is already decided

`txt_raw(s)` writes `s` through verbatim: newlines in it start a new line at
column 0 and nothing is re-indented. Use it for block comments, here-documents
and multi-line string literals — text that came from elsewhere and must survive
unchanged. Contrast `txt_lines(s)`, which lines continuations up with where the
text started:

```mbt check
///|
test {
  inspect(
    horz([txt("x = "), txt_lines("a\nb")]).display_string(),
    content=(
      #|x = a
      #|    b
    ),
  )
  inspect(
    horz([txt("x = "), txt_raw("a\nb")]).display_string(),
    content=(
      #|x = a
      #|b
    ),
  )
}
```

A `txt_raw` containing a newline has no flat width, so like `vert` it can never
be chosen as the flat branch of an `if_flat`.

### Building documents from templates

The JavaScript original uses a tagged template literal. MoonBit has no such
thing, so `pretty` takes the pieces explicitly: literal text is cut at every
newline, the lines are joined with `vert`, and each line's pieces with `horz`.

```mbt check
///|
test {
  let c = txt("a == b")
  let t = txt("a << 2")
  let e = txt("a + b")
  let doc = pretty([
    Str("if ("),
    Val(c),
    Str(") {\n  "),
    Val(t),
    Str("\n} else {\n  "),
    Val(e),
    Str("\n}"),
  ])
  inspect(
    doc.display_string(),
    content=(
      #|if (a == b) {
      #|  a << 2
      #|} else {
      #|  a + b
      #|}
    ),
  )
}
```

`txt_lines(s)` is the one-piece shorthand: a `txt` that accepts newlines.

### Utility constructors

`wrap(words, sep=..., vert_sep=...)` does word wrapping. Each gap is an independent
choice, so it fills lines greedily.

```mbt check
///|
test {
  let words = ["This", "is", "a", "sentence", "with", "eight", "words"].map(txt)
  inspect(
    wrap(words).display_string(width=20),
    content=(
      #|This is a sentence
      #|with eight words
    ),
  )
}
```

`sep_by(items, sep=..., vert_sep=...)` is all-or-nothing: either everything fits on
one line joined by `sep`, or every item goes on its own line.

```mbt check
///|
test {
  let doc = sep_by(["alpha", "beta", "gamma"].map(txt), sep=", ", vert_sep=",")
  inspect(doc.display_string(width=40), content="alpha, beta, gamma")
  inspect(
    doc.display_string(width=10),
    content=(
      #|alpha,
      #|beta,
      #|gamma
    ),
  )
}
```

Note that `vert_sep` is written at the current column *before* the line breaks,
so it can overhang the width by its own length. This matches the original.

`parens(doc)`, `standard_sexpr(func, args)`, `lambda_like_sexpr(keyword, defn,
body)` and `begin_like_sexpr(keyword, bodies)` cover common s-expression
layouts:

```mbt check
///|
test {
  let doc = begin_like_sexpr(txt("begin"), [
    standard_sexpr(txt("+"), [txt("1"), txt("2")]),
    standard_sexpr(txt("display"), [txt("a-fairly-long-variable-name")]),
  ])
  inspect(
    doc.display_string(width=30),
    content=(
      #|(begin
      #|  (+ 1 2)
      #|  (display
      #|   a-fairly-long-variable-name))
    ),
  )
}
```

## Differences from the JavaScript version

- No variadic functions, so `horz`, `vert` and `concat` take an `Array[Doc]`
  rather than a spread of arguments. The `horzArray` / `vertArray` /
  `concatArray` variants are therefore unnecessary and do not exist.
- No implicit coercion. JavaScript accepts a bare string (or any object with a
  `.pretty()` method) anywhere a document is expected; here you write
  `txt("...")`. Give your own types a `to_doc` method and call it.
- The `` pretty`...` `` tagged template becomes `pretty([Str(...), Val(...)])`.
- `txt` panics on embedded newlines instead of throwing, and `concat([])`
  returns `empty` instead of raising.
- `parens` is public here; upstream keeps it internal.
- `txt` measures widths in UTF-16 code units, as in JavaScript, which is exact
  for ASCII source code. Unlike upstream, `txt_as` lets you override that when
  it is not.
- `nest`, `txt_as`, `txt_raw`, `flat_width`, `write_to`, `if_flat`'s `reserve`
  and the `horz2` / `vert2` / `concat2` forms have no upstream equivalent.

## Running it

```sh
moon test          # unit tests, including the ported upstream suite
moon run cmd/main  # a small s-expression printer, shown at three widths
```

## License

MIT, matching the original JavaScript library (© 2019 Brown University PLT).
