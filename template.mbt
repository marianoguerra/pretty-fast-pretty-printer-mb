///|
/// One piece of a [`pretty`] template: either literal text (which may contain
/// newlines) or an embedded document.
pub(all) enum Piece {
  /// Literal text. Every `\n` in it starts a new line of the template.
  Str(String)
  /// An already-built document, spliced in at this position.
  Val(Doc)
} derive(Debug)

///|
/// Builds a document from a sequence of literal-text and document pieces, the
/// way a string template would: the pieces are cut into lines at every newline
/// in the literal text, the lines are joined with [`vert`], and the pieces of
/// each line are joined with [`horz`].
///
/// This is the MoonBit stand-in for the JavaScript library's tagged
/// `` pretty`...` `` template.
///
/// ```mbt check
/// test {
///   let c = @pp.txt("a == b")
///   let t = @pp.txt("a << 2")
///   let e = @pp.txt("a + b")
///   let doc = @pp.pretty([
///     Str("if ("),
///     Val(c),
///     Str(") {\n  "),
///     Val(t),
///     Str("\n} else {\n  "),
///     Val(e),
///     Str("\n}"),
///   ])
///   inspect(
///     doc.display_string(),
///     content=(
///       #|if (a == b) {
///       #|  a << 2
///       #|} else {
///       #|  a + b
///       #|}
///     ),
///   )
/// }
/// ```
///
/// Because every line is a [`horz`], an embedded document that spans several
/// lines is indented to line up with where it started.
pub fn pretty(pieces : Array[Piece]) -> Doc {
  let lines = []
  let line_parts = []
  for piece in pieces {
    match piece {
      Val(doc) => line_parts.push(doc)
      Str(text) =>
        for i, part in text.split("\n").collect() {
          // Every newline in the literal text closes off the current line.
          if i != 0 {
            lines.push(horz(line_parts))
            line_parts.clear()
          }
          line_parts.push(txt(part.to_owned()))
        }
    }
  }
  lines.push(horz(line_parts))
  vert(lines)
}

///|
/// Like [`txt`], but accepts newlines: the text is split into lines which are
/// joined with [`vert`].
///
/// ```mbt check
/// test {
///   inspect(
///     @pp.horz([@pp.txt("> "), @pp.txt_lines("one\ntwo")]).display_string(),
///     content=(
///       #|> one
///       #|  two
///     ),
///   )
/// }
/// ```
pub fn txt_lines(text : String) -> Doc {
  pretty([Str(text)])
}

///|
#deprecated(skip_current_package=true)
#doc(hidden)
pub extend Piece with Debug::{to_repr}
