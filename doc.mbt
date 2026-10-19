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
  /// `vert`, a `full_line` or a `txt_raw` with a newline in it.
  ///
  /// This is precomputed at construction time. It is the whole trick behind the
  /// algorithm: `if_flat` can decide which branch to take without ever
  /// rendering the branch it discards.
  ///
  /// Exposed to callers as `Doc::flat_width`.
  flat_width : Int32?
  node : Node
} derive(Debug)

///|
priv enum Node {
  /// Literal text, together with the width it occupies on screen. The width is
  /// carried explicitly because it is not always the length of the string: see
  /// [`txt_as`].
  Text(String, Int32)
  /// Literal text passed through verbatim, newlines and all. See [`txt_raw`].
  Raw(String)
  Horz(Doc, Doc)
  Concat(Doc, Doc)
  Vert(Doc, Doc)
  FullLine(Doc)
  /// The third field is the number of columns to keep free for whatever
  /// follows. See [`if_flat`].
  IfFlat(Doc, Doc, Int32)
  Nest(Int32, Doc)
} derive(Debug)

///|
/// The empty document. Equivalent to `txt("")`.
pub let empty : Doc = { flat_width: Some(0), node: Text("", 0), }

///|
/// `txt(s)` simply displays `s`.
///
/// All other combinators take `Doc`s, so this is how plain text enters a
/// document. Use [`txt_lines`] when the text may contain newlines.
///
/// ```mbt check
/// test {
///   inspect(@pp.txt("Hello, world").display_string(), content="Hello, world")
/// }
/// ```
///
/// The text is assumed to occupy one column per UTF-16 code unit. When that is
/// wrong — CJK, emoji, terminal escape sequences — use [`txt_as`].
///
/// # Panics
///
/// Panics if `text` contains a newline. A `Doc` describes layout, and layout is
/// this library's job; embed line breaks with [`vert`] or [`txt_lines`], or
/// pass the text through untouched with [`txt_raw`].
pub fn txt(text : String) -> Doc {
  guard !text.contains("\n") else {
    abort("txt does not accept text with newlines, but was given: \{text}")
  }
  txt_as(text, text.length())
}

///|
/// `txt_as(text, width)` displays `text`, telling the layout algorithm that it
/// occupies `width` columns.
///
/// [`txt`] measures text in UTF-16 code units, which is exact for ASCII and
/// wrong for everything whose screen width differs from its encoded length.
/// The two cases that matter in practice are double-width characters and
/// zero-width escape sequences:
///
/// ```mbt check
/// test {
///   // A CJK character is one UTF-16 unit wide but occupies two columns.
///   let cjk = @pp.txt_as("世界", 4)
///   assert_eq(cjk.flat_width(), Some(4))
///   // An ANSI colour escape is five UTF-16 units and occupies none.
///   let red = @pp.txt_as("\u{1b}[31m", 0)
///   let reset = @pp.txt_as("\u{1b}[0m", 0)
///   assert_eq(@pp.horz([red, @pp.txt("hello"), reset]).flat_width(), Some(5))
/// }
/// ```
///
/// Because the width is what every layout decision is made from, a coloured
/// document lays out exactly like the same document without colour.
///
/// # Panics
///
/// Panics if `text` contains a newline, for the same reason [`txt`] does.
pub fn txt_as(text : String, width : Int32) -> Doc {
  guard !text.contains("\n") else {
    abort("txt_as does not accept text with newlines, but was given: \{text}")
  }
  { flat_width: Some(width), node: Text(text, width), }
}

///|
/// `txt_raw(text)` writes `text` through verbatim. Newlines in it start a new
/// line at column 0, and nothing is re-indented.
///
/// This is the escape hatch for text whose layout is already decided and must
/// not be touched — block comments, here-documents, multi-line string literals.
/// [`txt_lines`] re-indents continuation lines to line up with where the text
/// started; `txt_raw` does not:
///
/// ```mbt check
/// test {
///   assert_eq(@pp.horz([@pp.txt("x = "), @pp.txt_lines("a\nb")]).display(), [
///     "x = a", "    b",
///   ])
///   assert_eq(@pp.horz([@pp.txt("x = "), @pp.txt_raw("a\nb")]).display(), [
///     "x = a", "b",
///   ])
/// }
/// ```
///
/// Text containing a newline has no flat width, so — like [`vert`] and
/// [`full_line`] — it can never be chosen as the flat branch of an [`if_flat`].
/// Text without one behaves exactly like [`txt`].
pub fn txt_raw(text : String) -> Doc {
  let flat_width = if text.contains("\n") { None } else { Some(text.length()) }
  { flat_width, node: Raw(text), }
}

///|
/// `horz([doc1, doc2, ...])` *horizontally* concatenates documents: each
/// document begins where the previous one left off, and is indented to line up
/// with the last line of the previous one.
///
/// ```mbt check
/// test {
///   let doc = @pp.horz([
///     @pp.txt("BEGIN "),
///     @pp.vert([@pp.txt("first line"), @pp.txt("second line")]),
///   ])
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
///     @pp.vert([@pp.txt("Hello,"), @pp.txt("world!")]).display_string(),
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
///   let doc = @pp.concat([
///     @pp.txt("BEGIN "),
///     @pp.vert([@pp.txt("first line"), @pp.txt("second line")]),
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
/// `horz2(doc1, doc2)` is [`horz`] on two documents, without building an array.
///
/// The array forms are the ones to reach for when you have an array. This is
/// for folding: `docs.fold(init=empty, horz2)` allocates nothing per step,
/// where `horz([acc, doc])` allocates a throwaway pair every time.
///
/// ```mbt check
/// test {
///   let docs = ["a", "b", "c"].map(@pp.txt)
///   inspect(docs.fold(init=@pp.empty, @pp.horz2).display_string(), content="abc")
/// }
/// ```
pub fn horz2(doc1 : Doc, doc2 : Doc) -> Doc {
  {
    flat_width: add_widths(doc1.flat_width, doc2.flat_width),
    node: Horz(doc1, doc2),
  }
}

///|
/// `concat2(doc1, doc2)` is [`concat`] on two documents. See [`horz2`].
///
/// ```mbt check
/// test {
///   let docs = ["a", "b", "c"].map(@pp.txt)
///   inspect(
///     docs.fold(init=@pp.empty, @pp.concat2).display_string(),
///     content="abc",
///   )
/// }
/// ```
pub fn concat2(doc1 : Doc, doc2 : Doc) -> Doc {
  {
    flat_width: add_widths(doc1.flat_width, doc2.flat_width),
    node: Concat(doc1, doc2),
  }
}

///|
/// `vert2(doc1, doc2)` is [`vert`] on two documents. See [`horz2`].
///
/// ```mbt check
/// test {
///   inspect(
///     @pp.vert2(@pp.txt("a"), @pp.txt("b")).display_string(),
///     content=(
///       #|a
///       #|b
///     ),
///   )
/// }
/// ```
pub fn vert2(doc1 : Doc, doc2 : Doc) -> Doc {
  { flat_width: None, node: Vert(doc1, doc2), }
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
/// `reserve` is the number of columns to keep free for whatever follows the
/// choice. The algorithm decides in a single left-to-right pass, so it cannot
/// see the trailing context itself; when the caller knows that, say, two
/// closing parens come next, `reserve=2` says so:
///
/// ```mbt check
/// test {
///   let flat = @pp.txt("[1, 2]")
///   let broken = @pp.vert([@pp.txt("[1,"), @pp.txt(" 2]")])
///   // The group fits in seven columns, so it stays flat -- and then the `))`
///   // that follows overflows.
///   let doc = @pp.horz([@pp.if_flat(flat, broken), @pp.txt("))")])
///   inspect(doc.display_string(width=7), content="[1, 2]))")
///   // Told that two more columns follow, it breaks, and the result fits.
///   let doc = @pp.horz([@pp.if_flat(flat, broken, reserve=2), @pp.txt("))")])
///   inspect(
///     doc.display_string(width=7),
///     content=(
///       #|[1,
///       #| 2]))
///     ),
///   )
/// }
/// ```
///
/// ```mbt check
/// test {
///   let doc = @pp.if_flat(
///     @pp.txt("[1, 2, 3]"),
///     @pp.vert([@pp.txt("[1,"), @pp.txt(" 2,"), @pp.txt(" 3]")]),
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
pub fn if_flat(flat : Doc, broken : Doc, reserve~ : Int32 = 0) -> Doc {
  // `reserve` deliberately does not enter `flat_width`: it describes the
  // context of *this* choice, not how wide the resulting document is.
  let flat_width = match (flat.flat_width, broken.flat_width) {
    (Some(a), Some(b)) => Some(if a < b { a } else { b })
    (None, w) => w
    (w, None) => w
  }
  { flat_width, node: IfFlat(flat, broken, reserve), }
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
///   let plain = @pp.horz([
///     @pp.if_flat(@pp.txt("a"), @pp.vert([@pp.txt("a"), @pp.txt("A")])),
///     @pp.txt("b"),
///   ])
///   inspect(plain.display_string(width=20), content="ab")
///   let forced = @pp.horz([
///     @pp.if_flat(
///       @pp.full_line(@pp.txt("a")),
///       @pp.vert([@pp.txt("a"), @pp.txt("A")]),
///     ),
///     @pp.txt("b"),
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
  { flat_width: None, node: FullLine(doc), }
}

///|
/// `nest(n, doc)` renders `doc` with `n` more columns of indentation: every
/// line `doc` breaks onto is indented `n` further, while the line it starts on
/// is left alone.
///
/// ```mbt check
/// test {
///   let doc = @pp.vert([@pp.txt("first line"), @pp.txt("second line")])
///   inspect(
///     @pp.nest(2, doc).display_string(),
///     content=(
///       #|first line
///       #|  second line
///     ),
///   )
/// }
/// ```
///
/// This is the only way to indent a document you did not build yourself.
/// Prefixing spaces with [`horz`] indents the first line too, which is a
/// different thing:
///
/// ```mbt check
/// test {
///   let doc = @pp.vert([@pp.txt("first line"), @pp.txt("second line")])
///   inspect(
///     @pp.horz([@pp.txt("  "), doc]).display_string(),
///     content=(
///       #|  first line
///       #|  second line
///     ),
///   )
/// }
/// ```
///
/// Note that [`horz`] re-indents its right operand to the column its left
/// operand ended at, which overrides any indentation established outside it.
/// So an enclosing `nest` has no effect on the right operand of a `horz`,
/// though a `nest` applied *inside* that operand still does. Nesting always
/// takes effect under [`concat`] and [`vert`].
///
/// Nesting does not change how wide a document is when flat, so it never
/// changes an [`if_flat`] decision.
pub fn nest(n : Int32, doc : Doc) -> Doc {
  { flat_width: doc.flat_width, node: Nest(n, doc), }
}

///|
/// The width this document occupies when rendered flat, i.e. all on one line,
/// or `None` when it cannot be rendered flat at all because it contains a
/// [`vert`], a [`full_line`] or a [`txt_raw`] with a newline in it.
///
/// This is precomputed at construction time rather than measured on demand, so
/// asking is free. It answers the two questions a caller assembling documents
/// keeps needing — "can this be flattened?" and "how wide is it flat?" — which
/// is what [`if_flat`] decides from:
///
/// ```mbt check
/// test {
///   assert_eq(@pp.horz([@pp.txt("ab"), @pp.txt("cd")]).flat_width(), Some(4))
///   assert_eq(@pp.vert([@pp.txt("ab"), @pp.txt("cd")]).flat_width(), None)
/// }
/// ```
pub fn Doc::flat_width(self : Doc) -> Int32? {
  self.flat_width
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
///   let doc = @pp.vert([@pp.txt("one"), @pp.horz([@pp.txt("  "), @pp.txt("two")])])
///   assert_eq(doc.display(), ["one", "  two"])
/// }
/// ```
///
/// `max_indent` caps indentation; see [`Doc::write_to`].
pub fn Doc::display(
  self : Doc,
  width~ : Int32 = 80,
  max_indent? : Int32,
) -> Array[String] {
  self
  .display_string(width~, max_indent?)
  .split("\n")
  .map(line => line.to_owned())
  .collect()
}

///|
/// Like [`Doc::display`], but as a single string with the lines joined by
/// `"\n"`. This is the cheaper of the two: it is what the renderer produces
/// directly, and [`Doc::display`] splits it.
///
/// ```mbt check
/// test {
///   inspect(
///     @pp.vert([@pp.txt("one"), @pp.txt("two")]).display_string(),
///     content=(
///       #|one
///       #|two
///     ),
///   )
/// }
/// ```
///
/// `max_indent` caps indentation; see [`Doc::write_to`].
pub fn Doc::display_string(
  self : Doc,
  width~ : Int32 = 80,
  max_indent? : Int32,
) -> String {
  let buf = StringBuilder()
  self.write_to(buf, width~, max_indent?)
  buf.to_string()
}

///|
/// Pretty print this document into an existing [`StringBuilder`], appending to
/// whatever is already there.
///
/// Use this to assemble output without a string per document:
///
/// ```mbt check
/// test {
///   let buf = StringBuilder()
///   buf.write_string("> ")
///   @pp.vert([@pp.txt("one"), @pp.txt("two")]).write_to(buf)
///   inspect(
///     buf.to_string(),
///     content=(
///       #|> one
///       #|two
///     ),
///   )
/// }
/// ```
///
/// Note that the document is laid out from column 0 regardless of what the
/// buffer already contains — a `StringBuilder` has no notion of a column. Wrap
/// the document in a [`horz`] or [`nest`] if you need it indented.
///
/// ## Capping indentation
///
/// `max_indent` is the furthest column the printer may indent a line to. Left
/// unset, indentation is unbounded: [`horz`] indents to wherever its left
/// operand ended, so deeply nested documents drift right until the width left
/// for their contents is gone.
///
/// ```mbt check
/// test {
///   let doc = @pp.horz([
///     @pp.txt("(let ((x "),
///     @pp.vert([@pp.txt("first"), @pp.txt("second")]),
///   ])
///   assert_eq(doc.display(), ["(let ((x first", "         second"])
///   assert_eq(doc.display(max_indent=4), ["(let ((x first", "    second"])
/// }
/// ```
///
/// The usual reason to want this is to guarantee every line a minimum of usable
/// columns — `display(width=80, max_indent=70)` leaves ten for content, no
/// matter how deep the document goes. It cannot be expressed as part of the
/// document, because a `Doc` has no columns until it is rendered.
///
/// Two things to know about what the cap does:
///
/// - It only moves lines the *printer* starts. Text already written to a line
///   has fixed the column the rest of that line continues from, so a long first
///   line still runs as far right as its contents take it.
/// - Indentation levels past the cap collapse onto it, so nesting that would
///   have been visible in the output no longer is. That is the trade the cap
///   makes: the layout comes out less indented than the document asked for.
///
/// The cap also feeds back into the layout. A line pulled leftwards has more
/// columns free, so groups on it that would have been broken can fit flat:
///
/// ```mbt check
/// test {
///   let group = @pp.if_flat(
///     @pp.txt("[1, 2, 3]"),
///     @pp.vert([@pp.txt("[1,"), @pp.txt(" 2,"), @pp.txt(" 3]")]),
///   )
///   let doc = @pp.horz([@pp.txt("        "), @pp.vert([@pp.txt("xs ="), group])])
///   // At width 16 the group starts in column 8 and does not fit.
///   assert_eq(doc.display(width=16), [
///     "        xs =", "        [1,", "         2,", "         3]",
///   ])
///   // Capped at column 2 it does.
///   assert_eq(doc.display(width=16, max_indent=2), ["        xs =", "  [1, 2, 3]"])
/// }
/// ```
pub fn Doc::write_to(
  self : Doc,
  buf : StringBuilder,
  width~ : Int32 = 80,
  max_indent? : Int32,
) -> Unit {
  ignore(self.render(Out::new(buf), 0, 0, width, max_indent))
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

///|
/// Widths add, unless either side cannot be flattened.
fn add_widths(a : Int32?, b : Int32?) -> Int32? {
  match (a, b) {
    (Some(x), Some(y)) => Some(x + y)
    _ => None
  }
}

///|
/// Combine `docs` with `combine`, treating the empty array as [`empty`].
///
/// This splits down the middle rather than folding from one end, so an array of
/// N documents becomes a tree of depth O(log N) instead of a chain of depth N.
/// All three of [`horz`], [`vert`] and [`concat`] are associative, so the
/// grouping is not observable in the output — but it is very observable in how
/// deeply anything walking the result has to recurse. `Doc::render` uses an
/// explicit stack and does not care; the derived `Debug` does.
fn reduce(docs : Array[Doc], combine : (Doc, Doc) -> Doc) -> Doc {
  guard docs is [_, ..] else { empty }
  reduce_slice(docs, 0, docs.length(), combine)
}

///|
/// Combine `docs[start:end]`, which must not be empty.
fn reduce_slice(
  docs : Array[Doc],
  start : Int32,
  end : Int32,
  combine : (Doc, Doc) -> Doc,
) -> Doc {
  if end - start == 1 {
    docs[start]
  } else {
    let mid = start + (end - start) / 2
    combine(
      reduce_slice(docs, start, mid, combine),
      reduce_slice(docs, mid, end, combine),
    )
  }
}

///|
/// The output being accumulated. Lines are separated by `"\n"` in a single
/// buffer rather than kept apart, so rendering allocates once no matter how
/// many lines come out.
priv struct Out {
  buf : StringBuilder
  /// Spaces owed to the current line, not yet written. Indentation is written
  /// lazily so that a line nothing is ever written to stays genuinely empty
  /// instead of becoming a run of trailing spaces.
  mut pending_indent : Int32
}

///|
fn Out::new(buf : StringBuilder) -> Out {
  { buf, pending_indent: 0, }
}

///|
fn Out::write(self : Out, text : String) -> Unit {
  guard text != "" else { return }
  if self.pending_indent > 0 {
    self.buf.write_string(" ".repeat(self.pending_indent))
    self.pending_indent = 0
  }
  self.buf.write_string(text)
}

///|
/// Start a new line, owing it `indent` spaces.
fn Out::newline(self : Out, indent : Int32) -> Unit {
  self.buf.write_char('\n')
  self.pending_indent = indent
}

///|
/// One entry on [`Doc::render`]'s work stack.
priv enum Work {
  /// Render this document at this indentation, starting at the current column.
  Todo(Doc, Int32)
  /// Render this document indented to wherever the previous one left off. The
  /// indentation is not known until the entry is popped, which is exactly what
  /// makes `horz` follow its left operand.
  Indented(Doc)
  /// Break the line, then render this document at this indentation.
  AfterBreak(Doc, Int32)
}

///|
/// Render the document, returning the column reached afterwards.
///
/// - `indent`: the column to return to when a line breaks.
/// - `column`: the current column.
/// - `width`: the width the printing is allowed to occupy.
/// - `max_indent`: the furthest column a line may be indented to, if capped.
///
/// This walks the document with an explicit work stack rather than recursing.
/// A document's *depth* is unbounded in practice — folding N pieces together
/// with any of the binary combinators builds an N-deep spine — so recursing
/// once per node would overflow the call stack on documents of very ordinary
/// size.
fn Doc::render(
  self : Doc,
  out : Out,
  indent : Int32,
  column : Int32,
  width : Int32,
  max_indent : Int32?,
) -> Int32 {
  let mut column = column
  let stack = [Todo(self, indent)]
  while stack.pop() is Some(work) {
    match work {
      Indented(doc) => stack.push(Todo(doc, column))
      // A break is the only place indentation is ever materialised, so it is
      // the one place the cap has to be applied. The clamped indentation is
      // what the rest of the document sees: levels past the cap collapse onto
      // it, and `column` is the real column the line starts at, so the layout
      // decisions taken further along get the room the cap won back.
      AfterBreak(doc, indent) => {
        let indent = match max_indent {
          Some(cap) if indent > cap => cap
          _ => indent
        }
        out.newline(indent)
        column = indent
        stack.push(Todo(doc, indent))
      }
      Todo(doc, indent) =>
        match doc.node {
          Text(text, text_width) => {
            out.write(text)
            column += text_width
          }
          // Verbatim text: every newline in it drops to column 0 with no
          // indentation, and the column afterwards follows the last segment.
          Raw(text) =>
            for i, segment in text.split("\n").collect() {
              if i != 0 {
                out.newline(0)
                column = 0
              }
              out.write(segment.to_owned())
              column += segment.length()
            }
          // `horz` re-indents to wherever the left document ended.
          Horz(doc1, doc2) => {
            stack.push(Indented(doc2))
            stack.push(Todo(doc1, indent))
          }
          // `concat` keeps the enclosing indentation instead.
          Concat(doc1, doc2) => {
            stack.push(Todo(doc2, indent))
            stack.push(Todo(doc1, indent))
          }
          Vert(doc1, doc2) => {
            stack.push(AfterBreak(doc2, indent))
            stack.push(Todo(doc1, indent))
          }
          FullLine(doc) => stack.push(Todo(doc, indent))
          Nest(n, doc) => stack.push(Todo(doc, indent + n))
          IfFlat(flat, broken, reserve) =>
            // The heart of the algorithm: this decision consults the
            // precomputed flat width instead of rendering `flat`, so no work is
            // ever thrown away.
            match flat.flat_width {
              Some(flat_width) if column + flat_width + reserve <= width =>
                stack.push(Todo(flat, indent))
              _ => stack.push(Todo(broken, indent))
            }
        }
    }
  }
  column
}

///|
#deprecated(skip_current_package=true)
#doc(hidden)
pub extend Doc with Debug::{to_repr}
