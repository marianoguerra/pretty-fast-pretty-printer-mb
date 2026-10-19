// Tests for the combinators added on top of the upstream JavaScript API:
// `txt_as`, `txt_raw`, `nest`, `Doc::flat_width`, `Doc::write_to`, the binary
// concatenations and `if_flat`'s `reserve`.

///|
test "txt_as states the width text occupies" {
  let cjk = @pp.txt_as("世界", 4)
  assert_eq(cjk.flat_width(), Some(4))
  // The text still renders in full; only the accounting changes.
  assert_eq(cjk.display(), ["世界"])
  // txt would have measured 2 and wrongly kept this flat at width 3.
  assert_eq(@pp.if_flat(cjk, @pp.txt("BROKEN")).display(width=3), ["BROKEN"])
  assert_eq(@pp.if_flat(cjk, @pp.txt("BROKEN")).display(width=4), ["世界"])
  assert_eq(
    @pp.if_flat(@pp.txt("世界"), @pp.txt("BROKEN")).display(width=3),
    ["世界"],
  )
}

///|
test "txt_as makes zero-width escapes free" {
  let red = @pp.txt_as("\u{1b}[31m", 0)
  let reset = @pp.txt_as("\u{1b}[0m", 0)
  let plain = @pp.txt("abcdefgh")
  let coloured = @pp.horz([red, plain, reset])
  // Colour costs nothing, so the two lay out identically...
  assert_eq(coloured.flat_width(), plain.flat_width())
  assert_eq(@pp.if_flat(coloured, @pp.txt("BROKEN")).display(width=8), [
    "\u{1b}[31mabcdefgh\u{1b}[0m",
  ])
  assert_eq(@pp.if_flat(plain, @pp.txt("BROKEN")).display(width=8), ["abcdefgh"])
  // ...and both break at the same width.
  assert_eq(@pp.if_flat(coloured, @pp.txt("BROKEN")).display(width=7), [
    "BROKEN",
  ])
  assert_eq(@pp.if_flat(plain, @pp.txt("BROKEN")).display(width=7), ["BROKEN"])
}

///|
test "txt_as follows the column, so later text lines up" {
  let doc = @pp.horz([
    @pp.txt_as("世界", 4),
    @pp.vert([@pp.txt("x"), @pp.txt("y")]),
  ])
  assert_eq(doc.display(), ["世界x", "    y"])
}

///|
test "panic txt_as rejects newlines" {
  ignore(@pp.txt_as("a\nb", 3))
}

///|
test "txt_raw passes text through verbatim" {
  let comment = @pp.txt_raw("/* one\n   two */")
  assert_eq(comment.display(), ["/* one", "   two */"])
  // Unlike txt_lines, continuation lines are not re-indented.
  assert_eq(@pp.horz([@pp.txt("x = "), @pp.txt_lines("a\nb")]).display(), [
    "x = a", "    b",
  ])
  assert_eq(@pp.horz([@pp.txt("x = "), @pp.txt_raw("a\nb")]).display(), [
    "x = a", "b",
  ])
}

///|
test "txt_raw with a newline can never be flattened" {
  let comment = @pp.txt_raw("a\nb")
  assert_eq(comment.flat_width(), None)
  assert_eq(@pp.if_flat(comment, @pp.txt("BROKEN")).display(width=999), [
    "BROKEN",
  ])
}

///|
test "txt_raw without a newline behaves exactly like txt" {
  assert_eq(@pp.txt_raw("abc").flat_width(), @pp.txt("abc").flat_width())
  assert_eq(@pp.txt_raw("abc").display(), @pp.txt("abc").display())
  assert_eq(@pp.txt_raw("").display(), @pp.txt("").display())
}

///|
test "the column follows txt_raw's last line" {
  assert_eq(@pp.horz([@pp.txt_raw("aa\nbbb"), @pp.txt("!")]).display(), [
    "aa", "bbb!",
  ])
  // A trailing newline leaves the column at 0.
  assert_eq(@pp.horz([@pp.txt_raw("aa\n"), @pp.txt("!")]).display(), ["aa", "!"])
}

///|
test "nest indents the lines a document breaks onto" {
  let doc = @pp.vert([@pp.txt("a"), @pp.txt("b")])
  assert_eq(@pp.nest(2, doc).display(), ["a", "  b"])
  assert_eq(@pp.nest(0, doc).display(), doc.display())
  // Nesting accumulates.
  assert_eq(@pp.nest(2, @pp.nest(3, doc)).display(), ["a", "     b"])
}

///|
test "nest works on a document it did not build" {
  // The point of nest: `horz` prefixing would indent the first line too.
  let given = @pp.vert([@pp.txt("first"), @pp.txt("second")])
  assert_eq(@pp.nest(2, given).display(), ["first", "  second"])
  assert_eq(@pp.horz([@pp.txt("  "), given]).display(), ["  first", "  second"])
}

///|
test "nest composes with vert and concat" {
  let inner = @pp.vert([@pp.txt("b"), @pp.txt("c")])
  assert_eq(@pp.vert([@pp.txt("a"), @pp.nest(2, inner)]).display(), [
    "a", "b", "  c",
  ])
  assert_eq(@pp.concat([@pp.txt("a"), @pp.nest(2, inner)]).display(), [
    "ab", "  c",
  ])
}

///|
test "horz re-indents past an enclosing nest" {
  let inner = @pp.vert([@pp.txt("b"), @pp.txt("c")])
  // `horz` indents its right operand to where the left one ended, which
  // overrides the nest entirely.
  assert_eq(@pp.nest(4, @pp.horz([@pp.txt("a"), inner])).display(), ["ab", " c"])
  // A nest *inside* the right operand still applies, on top of that column.
  assert_eq(@pp.horz([@pp.txt("a"), @pp.nest(4, inner)]).display(), [
    "ab", "     c",
  ])
}

///|
test "nest does not change the flat width" {
  let doc = @pp.horz([@pp.txt("ab"), @pp.txt("cd")])
  assert_eq(@pp.nest(4, doc).flat_width(), doc.flat_width())
  assert_eq(@pp.if_flat(@pp.nest(4, doc), @pp.txt("BROKEN")).display(width=4), [
    "abcd",
  ])
}

///|
test "flat_width reports what if_flat decides from" {
  assert_eq(@pp.empty.flat_width(), Some(0))
  assert_eq(@pp.txt("abcd").flat_width(), Some(4))
  assert_eq(@pp.horz([@pp.txt("ab"), @pp.txt("cd")]).flat_width(), Some(4))
  assert_eq(@pp.concat([@pp.txt("ab"), @pp.txt("cd")]).flat_width(), Some(4))
  // Anything that forces a break has no flat width.
  assert_eq(@pp.vert([@pp.txt("ab"), @pp.txt("cd")]).flat_width(), None)
  assert_eq(@pp.full_line(@pp.txt("ab")).flat_width(), None)
  assert_eq(
    @pp.horz([@pp.txt("ab"), @pp.vert([@pp.txt("c"), @pp.txt("d")])]).flat_width(),
    None,
  )
  // if_flat is as wide as the narrower branch it may choose.
  assert_eq(@pp.if_flat(@pp.txt("abcd"), @pp.txt("ab")).flat_width(), Some(2))
  // A branch with no flat width leaves the other one's.
  assert_eq(
    @pp.if_flat(@pp.txt("abcd"), @pp.vert([@pp.txt("a"), @pp.txt("b")])).flat_width(),
    Some(4),
  )
  // A one-element vert is just that element, so it still has a flat width.
  assert_eq(@pp.vert([@pp.txt("a")]).flat_width(), Some(1))
}

///|
test "the binary concatenations agree with the array ones" {
  let (x, y) = (@pp.txt("ab"), @pp.vert([@pp.txt("c"), @pp.txt("d")]))
  assert_eq(@pp.horz2(x, y).display(), @pp.horz([x, y]).display())
  assert_eq(@pp.concat2(x, y).display(), @pp.concat([x, y]).display())
  assert_eq(@pp.vert2(x, y).display(), @pp.vert([x, y]).display())
  // Folding with them is what they are for.
  let docs = ["a", "b", "c"].map(@pp.txt)
  assert_eq(docs.fold(init=@pp.empty, @pp.horz2).display(), ["abc"])
  assert_eq(docs.fold(init=@pp.empty, @pp.concat2).display(), ["abc"])
  assert_eq(docs.fold(init=@pp.empty, @pp.vert2).display(), ["", "a", "b", "c"])
}

///|
test "reserve keeps columns free for what follows" {
  let flat = @pp.txt("[1, 2]")
  let broken = @pp.vert([@pp.txt("[1,"), @pp.txt(" 2]")])
  // Without reserve the group fits in 7 and the trailing `))` overflows.
  assert_eq(
    @pp.horz([@pp.if_flat(flat, broken), @pp.txt("))")]).display(width=7),
    ["[1, 2]))"],
  )
  // With it, the group breaks and the whole thing fits.
  assert_eq(
    @pp.horz([@pp.if_flat(flat, broken, reserve=2), @pp.txt("))")]).display(
      width=7,
    ),
    ["[1,", " 2]))"],
  )
  // reserve=0 is the default and changes nothing.
  assert_eq(
    @pp.if_flat(flat, broken, reserve=0).display(width=7),
    @pp.if_flat(flat, broken).display(width=7),
  )
  // reserve does not enter the resulting document's own flat width.
  assert_eq(@pp.if_flat(flat, broken, reserve=2).flat_width(), Some(6))
}

///|
test "max_indent caps how far a line may be indented" {
  let doc = @pp.horz([
    @pp.txt("(let ((x "),
    @pp.vert([@pp.txt("first"), @pp.txt("second")]),
  ])
  assert_eq(doc.display(), ["(let ((x first", "         second"])
  assert_eq(doc.display(max_indent=4), ["(let ((x first", "    second"])
  // A cap no line reaches changes nothing, and neither does leaving it unset.
  assert_eq(doc.display(max_indent=9), doc.display())
  assert_eq(doc.display(max_indent=999), doc.display())
  // Zero pulls every broken line back to the left margin.
  assert_eq(doc.display(max_indent=0), ["(let ((x first", "second"])
}

///|
/// The cap moves lines the printer starts. It cannot move text that is already
/// on a line: the column that line continues from is settled by then.
test "max_indent does not shorten a line that is already long" {
  let doc = @pp.horz([
    @pp.txt("x".repeat(40)),
    @pp.vert([@pp.txt("a"), @pp.txt("b")]),
  ])
  let lines = doc.display(width=20, max_indent=4)
  assert_eq(lines[0].length(), 41)
  assert_eq(lines[1], "    b")
}

///|
/// Every source of indentation goes through the same break, so the cap applies
/// to `nest` and to the column `horz` picks up alike.
test "max_indent applies to nest as well as horz" {
  let doc = @pp.nest(30, @pp.vert([@pp.txt("a"), @pp.txt("b")]))
  assert_eq(doc.display(), ["a", "                              b"])
  assert_eq(doc.display(max_indent=3), ["a", "   b"])
  // Levels past the cap collapse onto it, so this nesting stops being visible.
  let inner = @pp.vert([
    @pp.txt("b"),
    @pp.nest(10, @pp.vert([@pp.txt("c"), @pp.txt("d")])),
  ])
  assert_eq(
    @pp.nest(30, @pp.vert([@pp.txt("a"), inner])).display(max_indent=3),
    ["a", "   b", "   c", "   d"],
  )
}

///|
/// Pulling a line back leaves more columns free on it, and the layout that
/// follows is decided from the column the line actually starts at.
test "max_indent gives the layout that follows more room" {
  let group = @pp.if_flat(
    @pp.txt("[1, 2, 3]"),
    @pp.vert([@pp.txt("[1,"), @pp.txt(" 2,"), @pp.txt(" 3]")]),
  )
  let doc = @pp.horz([
    @pp.txt(" ".repeat(8)),
    @pp.vert([@pp.txt("xs ="), group]),
  ])
  assert_eq(doc.display(width=16), [
    "        xs =", "        [1,", "         2,", "         3]",
  ])
  assert_eq(doc.display(width=16, max_indent=2), ["        xs =", "  [1, 2, 3]"])
}

///|
test "max_indent reaches display_string and write_to too" {
  let doc = @pp.horz([@pp.txt("ab"), @pp.vert([@pp.txt("x"), @pp.txt("y")])])
  assert_eq(doc.display_string(max_indent=0), "abx\ny")
  let buf = StringBuilder()
  doc.write_to(buf, max_indent=0)
  assert_eq(buf.to_string(), "abx\ny")
}

///|
test "write_to appends into an existing buffer" {
  let buf = StringBuilder()
  buf.write_string("> ")
  @pp.vert([@pp.txt("one"), @pp.txt("two")]).write_to(buf)
  assert_eq(buf.to_string(), "> one\ntwo")
  // Same output as display_string, and it keeps appending.
  let buf = StringBuilder()
  let doc = @pp.wrap(["a", "b", "c"].map(@pp.txt))
  doc.write_to(buf, width=1)
  assert_eq(buf.to_string(), doc.display_string(width=1))
  doc.write_to(buf, width=1)
  assert_eq(buf.to_string(), doc.display_string(width=1).repeat(2))
}
