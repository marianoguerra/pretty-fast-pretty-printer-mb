// Ported from the upstream JavaScript test suite
// (brownplt/pretty-fast-pretty-printer, index.test.js), so the two
// implementations can be checked against each other line for line.

///|
test "render nothing and literal text" {
  assert_eq(@pp.txt("").display(width=10), [""])
  assert_eq(@pp.txt("literal text").display(width=20), ["literal text"])
  assert_eq(@pp.empty.display(width=10), [""])
}

///|
test "vertical concatenation" {
  assert_eq(@pp.vert([@pp.txt("aaaa"), @pp.txt("bbb")]).display(width=20), [
    "aaaa", "bbb",
  ])
}

///|
test "horizontal concatenation" {
  let doc = @pp.horz([@pp.txt("aaaa"), @pp.vert([@pp.txt("bb"), @pp.txt("cc")])])
  assert_eq(doc.display(width=20), ["aaaabb", "    cc"])
}

///|
test "simple concatenation" {
  let doc = @pp.concat([
    @pp.txt("aaaa"),
    @pp.vert([@pp.txt("bb"), @pp.txt("cc")]),
  ])
  assert_eq(doc.display(width=20), ["aaaabb", "cc"])
}

///|
test "concatenation is associative" {
  let (x, y, z) = (
    @pp.txt("aaaa"),
    @pp.vert([@pp.txt("bb"), @pp.txt("cc")]),
    @pp.txt("dd"),
  )
  assert_eq(
    @pp.horz([x, y, z]).display(width=20),
    @pp.horz([x, @pp.horz([y, z])]).display(width=20),
  )
  assert_eq(
    @pp.horz([x, y, z]).display(width=20),
    @pp.horz([@pp.horz([x, y]), z]).display(width=20),
  )
  assert_eq(
    @pp.vert([x, y, z]).display(width=20),
    @pp.vert([x, @pp.vert([y, z])]).display(width=20),
  )
  assert_eq(
    @pp.vert([x, y, z]).display(width=20),
    @pp.vert([@pp.vert([x, y]), z]).display(width=20),
  )
}

///|
test "empty combinator arguments" {
  assert_eq(@pp.horz([]).display(width=10), [""])
  assert_eq(@pp.vert([]).display(width=10), [""])
  assert_eq(@pp.concat([]).display(width=10), [""])
  assert_eq(@pp.wrap([]).display(width=10), [""])
  assert_eq(@pp.sep_by([]).display(width=10), [""])
}

///|
test "templates" {
  let one = @pp.txt("1")
  let two = @pp.txt("2")
  let doc = @pp.pretty([Str("aaaa "), Val(one), Str("\nb\n  "), Val(two)])
  assert_eq(doc.display(width=10), ["aaaa 1", "b", "  2"])
}

///|
test "the example template from the docs" {
  let c = @pp.txt("a == b")
  let t = @pp.txt("a << 2")
  let e = @pp.txt("a + b")
  let doc = @pp.pretty([
    Str("if ("),
    Val(c),
    Str(") {\n  "),
    Val(t),
    Str("\n} else {\n  "),
    Val(e),
    Str("\n}"),
  ])
  assert_eq(doc.display(width=80), [
    "if (a == b) {", "  a << 2", "} else {", "  a + b", "}",
  ])
}

///|
/// `left op right`, breaking before the operator when it does not fit.
fn binop(left : @pp.Doc, op : @pp.Doc, right : @pp.Doc) -> @pp.Doc {
  @pp.if_flat(
    @pp.pretty([Val(left), Str(" "), Val(op), Str(" "), Val(right)]),
    @pp.pretty([Val(left), Str("\n"), Val(op), Str(" "), Val(right)]),
  )
}

///|
test "the example from the old documentation" {
  fn ifte2(c, t, e) {
    @pp.if_flat(
      @pp.pretty([
        Str("if ("),
        Val(c),
        Str(") { "),
        Val(t),
        Str(" } else { "),
        Val(e),
        Str(" }"),
      ]),
      @pp.pretty([
        Str("if ("),
        Val(c),
        Str(") {\n  "),
        Val(t),
        Str("\n} else {\n  "),
        Val(e),
        Str("\n}"),
      ]),
    )
  }

  let doc = ifte2(
    binop(@pp.txt("a"), @pp.txt("=="), @pp.txt("b")),
    binop(@pp.txt("a"), @pp.txt("<<"), @pp.txt("2")),
    binop(@pp.txt("a"), @pp.txt("+"), @pp.txt("b")),
  )
  assert_eq(doc.display(width=37), ["if (a == b) { a << 2 } else { a + b }"])
  assert_eq(doc.display(width=35), [
    "if (a == b) {", "  a << 2", "} else {", "  a + b", "}",
  ])
}

///|
test "Pyret-style functions from the docs" {
  fn show_func(name, args, body) {
    let header = @pp.horz([
      @pp.txt("fun "),
      name,
      @pp.txt("("),
      args,
      @pp.txt("):"),
    ])
    let on_one_line = @pp.horz([header, @pp.txt(" "), body, @pp.txt(" end")])
    let on_multiple_lines = @pp.vert([
      header,
      @pp.horz([@pp.txt("    "), body]),
      @pp.txt("end"),
    ])
    @pp.if_flat(on_one_line, on_multiple_lines)
  }

  let doc = show_func(
    @pp.txt("greet"),
    @pp.txt("name"),
    @pp.txt("\"Welcome back, \" + name"),
  )
  assert_eq(doc.display(width=80), [
    "fun greet(name): \"Welcome back, \" + name end",
  ])
  assert_eq(doc.display(width=40), [
    "fun greet(name):", "    \"Welcome back, \" + name", "end",
  ])
}

///|
test "horz and concat as documented" {
  let body = @pp.vert([@pp.txt("first line"), @pp.txt("second line")])
  assert_eq(@pp.horz([@pp.txt("BEGIN "), body]).display(width=80), [
    "BEGIN first line", "      second line",
  ])
  assert_eq(@pp.concat([@pp.txt("BEGIN "), body]).display(width=80), [
    "BEGIN first line", "second line",
  ])
}

///|
test "while loops from the docs" {
  let cond = @pp.txt("CONDITION")
  let body = @pp.txt("BODY")
  let doc = @pp.vert([
    @pp.horz([@pp.txt("while ("), cond, @pp.txt(") {")]),
    @pp.horz([@pp.txt("  "), body]),
    @pp.txt("}"),
  ])
  assert_eq(doc.display(width=80), ["while (CONDITION) {", "  BODY", "}"])
}

///|
test "if/then/else the way BLerner likes them" {
  fn opt_break(x, y) {
    @pp.if_flat(
      @pp.pretty([Val(x), Str(" "), Val(y)]),
      @pp.pretty([Val(x), Str("\n  "), Val(y)]),
    )
  }

  fn ifte(c, t, e) {
    @pp.if_flat(
      @pp.pretty([
        Str("if "),
        Val(c),
        Str(" then "),
        Val(t),
        Str(" else "),
        Val(e),
      ]),
      @pp.vert([
        opt_break(@pp.txt("if"), c),
        opt_break(@pp.txt("then"), t),
        opt_break(@pp.txt("else"), e),
      ]),
    )
  }

  let doc = ifte(
    binop(@pp.txt("a"), @pp.txt("=="), @pp.txt("b")),
    binop(@pp.txt("a"), @pp.txt("<<"), @pp.txt("2")),
    binop(@pp.txt("a"), @pp.txt("+"), @pp.txt("b")),
  )
  assert_eq(doc.display(width=32), ["if a == b then a << 2 else a + b"])
  assert_eq(doc.display(width=15), ["if a == b", "then a << 2", "else a + b"])
  assert_eq(doc.display(width=10), [
    "if a == b", "then", "  a << 2", "else a + b",
  ])
}

///|
test "full_line disallows anything later on the same line" {
  let broken = @pp.vert([@pp.txt("a"), @pp.txt("A")])
  assert_eq(
    @pp.horz([@pp.if_flat(@pp.txt("a"), broken), @pp.txt("b")]).display(
      width=20,
    ),
    ["ab"],
  )
  assert_eq(
    @pp.horz([@pp.if_flat(@pp.full_line(@pp.txt("a")), broken), @pp.txt("b")]).display(
      width=20,
    ),
    ["a", "Ab"],
  )
}

///|
test "full_line only vetoes if_flat; it does not itself break a line" {
  assert_eq(@pp.full_line(@pp.txt("abc")).display(width=20), ["abc"])
  // With no enclosing `if_flat` to veto, "b" still lands on the same line.
  assert_eq(
    @pp.horz([@pp.full_line(@pp.txt("a")), @pp.txt("b")]).display(width=20),
    ["ab"],
  )
  assert_eq(
    @pp.full_line(@pp.vert([@pp.txt("a"), @pp.txt("A")])).display(width=20),
    ["a", "A"],
  )
}

///|
test "compared against Bernardy's algorithm" {
  fn plus(d1, d2) {
    binop(d1, @pp.txt("+"), d2)
  }

  fn times(d1, d2) {
    binop(d1, @pp.txt("*"), d2)
  }

  let doc = plus(times(@pp.txt("aaaaaaaaa"), @pp.txt("bb")), @pp.txt("cc"))
  assert_eq(doc.display(width=19), ["aaaaaaaaa * bb + cc"])
  assert_eq(doc.display(width=18), ["aaaaaaaaa * bb", "+ cc"])
  // Bernardy's algorithm would produce "aaaaaaaaa\n* bb + cc" here, which is
  // a little questionable.
  assert_eq(doc.display(width=13), ["aaaaaaaaa", "* bb", "+ cc"])
}

///|
test "display_string joins the lines" {
  let doc = @pp.vert([@pp.txt("aaaa"), @pp.txt("bbb")])
  inspect(
    doc.display_string(width=20),
    content=(
      #|aaaa
      #|bbb
    ),
  )
}

///|
test "the default width is 80" {
  let words = Array::makei(30, i => @pp.txt("word\{i}"))
  assert_eq(@pp.wrap(words).display(), @pp.wrap(words).display(width=80))
}

///|
test "text wider than the width simply overflows" {
  assert_eq(@pp.txt("aaaaaaaaaa").display(width=3), ["aaaaaaaaaa"])
}

///|
test "panic txt rejects newlines" {
  ignore(@pp.txt("a\nb"))
}
