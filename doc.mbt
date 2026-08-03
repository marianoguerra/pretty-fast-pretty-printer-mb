///|
/// A pretty printing document: a description of *all* the ways a piece of text
/// may be laid out. Build one with the combinators in this package, then call
/// [`Doc::display`] to pick a layout that fits a given width.
///
/// The layout is chosen in a single left-to-right pass, so printing is linear
/// in the size of the document.
struct Doc {
  /// The width this document takes when rendered flat (i.e. on a single line),
  /// or `None` when it cannot be rendered flat at all because it contains a
  /// `vert` or a `full_line`.
  ///
  /// This is precomputed at construction time. It is the whole trick behind the
  /// algorithm: `if_flat` can decide which branch to take without ever
  /// rendering the branch it discards.
  flat_width : Int?
  node : Node
} derive(Debug)

///|
priv enum Node {
  Text(String)
  Horz(Doc, Doc)
  Concat(Doc, Doc)
  Vert(Doc, Doc)
  FullLine(Doc)
  IfFlat(Doc, Doc)
} derive(Debug)

///|
/// The empty document. Equivalent to `txt("")`.
pub let empty : Doc = { flat_width: Some(0), node: Text("") }

///|
/// `txt(s)` simply displays `s`.
///
/// All other combinators take `Doc`s, so this is how plain text enters a
/// document. Use [`txt_lines`] when the text may contain newlines.
///
/// ```mbt check
/// test {
///   inspect(txt("Hello, world").display_string(), content="Hello, world")
/// }
/// ```
///
/// # Panics
///
/// Panics if `text` contains a newline. A `Doc` describes layout, and layout is
/// this library's job; embed line breaks with [`vert`] or [`txt_lines`].
pub fn txt(text : String) -> Doc {
  guard !text.contains("\n") else {
    abort("txt does not accept text with newlines, but was given: \{text}")
  }
  { flat_width: Some(text.length()), node: Text(text) }
}

///|
/// `horz([doc1, doc2, ...])` *horizontally* concatenates documents: each
/// document begins where the previous one left off, and is indented to line up
/// with the last line of the previous one.
///
/// ```mbt check
/// test {
///   let doc = horz([txt("BEGIN "), vert([txt("first line"), txt("second line")])])
///   inspect(
///     doc.display_string(),
///     content=(
///       #|BEGIN first line
///       #|      second line
///     ),
///   )
/// }
/// ```
///
/// Horizontal concatenation is associative, so `horz([x, y, z])`,
/// `horz([x, horz([y, z])])` and `horz([horz([x, y]), z])` all agree.
/// An empty array yields [`empty`].
pub fn horz(docs : Array[Doc]) -> Doc {
  reduce(docs, horz2)
}

///|
/// `vert([doc1, doc2, ...])` *vertically* concatenates documents: it joins them
/// with newlines, indenting every document to the column the first one started
/// at.
///
/// ```mbt check
/// test {
///   inspect(
///     vert([txt("Hello,"), txt("world!")]).display_string(),
///     content=(
///       #|Hello,
///       #|world!
///     ),
///   )
/// }
/// ```
///
/// Vertical concatenation is associative. An empty array yields [`empty`].
pub fn vert(docs : Array[Doc]) -> Doc {
  reduce(docs, vert2)
}

///|
/// `concat([doc1, doc2, ...])` naively concatenates documents from left to
/// right. It is like [`horz`], except the indentation level stays *fixed*
/// instead of following the last line of the previous document.
///
/// ```mbt check
/// test {
///   let doc = concat([
///     txt("BEGIN "),
///     vert([txt("first line"), txt("second line")]),
///   ])
///   inspect(
///     doc.display_string(),
///     content=(
///       #|BEGIN first line
///       #|second line
///     ),
///   )
/// }
/// ```
///
/// You should almost always prefer [`horz`]. An empty array yields [`empty`].
pub fn concat(docs : Array[Doc]) -> Doc {
  reduce(docs, concat2)
}

///|
/// `if_flat(flat, broken)` chooses between two layouts. It uses `flat` if and
/// only if:
///
/// 1. `flat` can be rendered flat, i.e. it contains no [`vert`] and no
///    [`full_line`]; and
/// 2. rendered flat, it fits on the current line without exceeding the width.
///
/// Otherwise it uses `broken`.
///
/// ```mbt check
/// test {
///   let doc = if_flat(
///     txt("[1, 2, 3]"),
///     vert([txt("[1,"), txt(" 2,"), txt(" 3]")]),
///   )
///   inspect(doc.display_string(width=20), content="[1, 2, 3]")
///   inspect(
///     doc.display_string(width=5),
///     content=(
///       #|[1,
///       #| 2,
///       #| 3]
///     ),
///   )
/// }
/// ```
pub fn if_flat(flat : Doc, broken : Doc) -> Doc {
  let flat_width = match (flat.flat_width, broken.flat_width) {
    (Some(a), Some(b)) => Some(if a < b { a } else { b })
    (None, w) => w
    (w, None) => w
  }
  { flat_width, node: IfFlat(flat, broken) }
}

///|
/// `full_line(doc)` ensures that nothing is placed after `doc` on the same
/// line, if at all possible.
///
/// It does this by declaring that `doc` has no flat width, so any enclosing
/// [`if_flat`] will reject the branch containing it.
///
/// ```mbt check
/// test {
///   let plain = horz([if_flat(txt("a"), vert([txt("a"), txt("A")])), txt("b")])
///   inspect(plain.display_string(width=20), content="ab")
///   let forced = horz([
///     if_flat(full_line(txt("a")), vert([txt("a"), txt("A")])),
///     txt("b"),
///   ])
///   inspect(
///     forced.display_string(width=20),
///     content=(
///       #|a
///       #|Ab
///     ),
///   )
/// }
/// ```
pub fn full_line(doc : Doc) -> Doc {
  { flat_width: None, node: FullLine(doc) }
}

///|
/// Pretty print this document within the given width, returning one string per
/// line. Lines are never padded on the right, but continuation lines carry
/// their indentation as leading spaces.
///
/// `width` is a target, not a guarantee: a document containing text longer than
/// `width` will overflow, because there is nothing else to be done with it.
///
/// ```mbt check
/// test {
///   let doc = vert([txt("one"), horz([txt("  "), txt("two")])])
///   assert_eq(doc.display(), ["one", "  two"])
/// }
/// ```
pub fn Doc::display(self : Doc, width? : Int = 80) -> Array[String] {
  let out = Out::new()
  ignore(self.render(out, 0, 0, width))
  out.finish()
}

///|
/// Like [`Doc::display`], but joins the lines with `"\n"`.
///
/// ```mbt check
/// test {
///   inspect(
///     vert([txt("one"), txt("two")]).display_string(),
///     content=(
///       #|one
///       #|two
///     ),
///   )
/// }
/// ```
pub fn Doc::display_string(self : Doc, width? : Int = 80) -> String {
  self.display(width~).join("\n")
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

///|
/// Widths add, unless either side cannot be flattened.
fn add_widths(a : Int?, b : Int?) -> Int? {
  match (a, b) {
    (Some(x), Some(y)) => Some(x + y)
    _ => None
  }
}

///|
fn horz2(doc1 : Doc, doc2 : Doc) -> Doc {
  {
    flat_width: add_widths(doc1.flat_width, doc2.flat_width),
    node: Horz(doc1, doc2),
  }
}

///|
fn concat2(doc1 : Doc, doc2 : Doc) -> Doc {
  {
    flat_width: add_widths(doc1.flat_width, doc2.flat_width),
    node: Concat(doc1, doc2),
  }
}

///|
fn vert2(doc1 : Doc, doc2 : Doc) -> Doc {
  { flat_width: None, node: Vert(doc1, doc2) }
}

///|
/// Left-fold `docs` with `combine`, treating the empty array as [`empty`].
fn reduce(docs : Array[Doc], combine : (Doc, Doc) -> Doc) -> Doc {
  guard docs is [first, .. rest] else { empty }
  rest.fold(init=first, combine)
}

///|
/// The output being accumulated: one string builder per line produced so far.
priv struct Out {
  lines : Array[StringBuilder]
}

///|
fn Out::new() -> Out {
  { lines: [StringBuilder::new()] }
}

///|
fn Out::write(self : Out, text : String) -> Unit {
  self.lines[self.lines.length() - 1].write_string(text)
}

///|
/// Start a new line, pre-filled with `indent` spaces.
fn Out::newline(self : Out, indent : Int) -> Unit {
  let line = StringBuilder::new()
  line.write_string(" ".repeat(indent))
  self.lines.push(line)
}

///|
fn Out::finish(self : Out) -> Array[String] {
  self.lines.map(line => line.to_string())
}

///|
/// Render the document, returning the column reached afterwards.
///
/// - `indent`: the column to return to when a line breaks.
/// - `column`: the current column.
/// - `width`: the width the printing is allowed to occupy.
fn Doc::render(
  self : Doc,
  out : Out,
  indent : Int,
  column : Int,
  width : Int,
) -> Int {
  match self.node {
    Text(text) => {
      out.write(text)
      column + text.length()
    }
    // `horz` re-indents to wherever the left document ended.
    Horz(doc1, doc2) => {
      let column = doc1.render(out, indent, column, width)
      doc2.render(out, column, column, width)
    }
    // `concat` keeps the enclosing indentation instead.
    Concat(doc1, doc2) => {
      let column = doc1.render(out, indent, column, width)
      doc2.render(out, indent, column, width)
    }
    Vert(doc1, doc2) => {
      ignore(doc1.render(out, indent, column, width))
      out.newline(indent)
      doc2.render(out, indent, indent, width)
    }
    FullLine(doc) => doc.render(out, indent, column, width)
    IfFlat(flat, broken) =>
      // The heart of the algorithm: this decision consults the precomputed
      // flat width instead of rendering `flat`, so no work is ever thrown away.
      match flat.flat_width {
        Some(flat_width) if column + flat_width <= width =>
          flat.render(out, indent, column, width)
        _ => broken.render(out, indent, column, width)
      }
  }
}
