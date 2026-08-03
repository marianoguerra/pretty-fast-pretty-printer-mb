// Ported from the upstream JavaScript test suite
// (brownplt/pretty-fast-pretty-printer, index.test.js), so the two
// implementations can be checked against each other line for line.

///|
test "render nothing and literal text" {
  assert_eq(txt("").display(width=10), [""])
  assert_eq(txt("literal text").display(width=20), ["literal text"])
  assert_eq(empty.display(width=10), [""])
}

///|
test "vertical concatenation" {
  assert_eq(vert([txt("aaaa"), txt("bbb")]).display(width=20), ["aaaa", "bbb"])
}

///|
test "horizontal concatenation" {
  let doc = horz([txt("aaaa"), vert([txt("bb"), txt("cc")])])
  assert_eq(doc.display(width=20), ["aaaabb", "    cc"])
}

///|
test "simple concatenation" {
  let doc = concat([txt("aaaa"), vert([txt("bb"), txt("cc")])])
  assert_eq(doc.display(width=20), ["aaaabb", "cc"])
}

///|
test "concatenation is associative" {
  let (x, y, z) = (txt("aaaa"), vert([txt("bb"), txt("cc")]), txt("dd"))
  assert_eq(
    horz([x, y, z]).display(width=20),
    horz([x, horz([y, z])]).display(width=20),
  )
  assert_eq(
    horz([x, y, z]).display(width=20),
    horz([horz([x, y]), z]).display(width=20),
  )
  assert_eq(
    vert([x, y, z]).display(width=20),
    vert([x, vert([y, z])]).display(width=20),
  )
  assert_eq(
    vert([x, y, z]).display(width=20),
    vert([vert([x, y]), z]).display(width=20),
  )
}

///|
test "empty combinator arguments" {
  assert_eq(horz([]).display(width=10), [""])
  assert_eq(vert([]).display(width=10), [""])
  assert_eq(concat([]).display(width=10), [""])
  assert_eq(wrap([]).display(width=10), [""])
  assert_eq(sep_by([]).display(width=10), [""])
}

///|
test "templates" {
  let one = txt("1")
  let two = txt("2")
  let doc = pretty([Str("aaaa "), Val(one), Str("\nb\n  "), Val(two)])
  assert_eq(doc.display(width=10), ["aaaa 1", "b", "  2"])
}

///|
test "the example template from the docs" {
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
  assert_eq(doc.display(width=80), [
    "if (a == b) {", "  a << 2", "} else {", "  a + b", "}",
  ])
}

///|
/// `left op right`, breaking before the operator when it does not fit.
fn binop(left : Doc, op : Doc, right : Doc) -> Doc {
  if_flat(
    pretty([Val(left), Str(" "), Val(op), Str(" "), Val(right)]),
    pretty([Val(left), Str("\n"), Val(op), Str(" "), Val(right)]),
  )
}

///|
test "the example from the old documentation" {
  fn ifte2(c, t, e) {
    if_flat(
      pretty([
        Str("if ("),
        Val(c),
        Str(") { "),
        Val(t),
        Str(" } else { "),
        Val(e),
        Str(" }"),
      ]),
      pretty([
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
    binop(txt("a"), txt("=="), txt("b")),
    binop(txt("a"), txt("<<"), txt("2")),
    binop(txt("a"), txt("+"), txt("b")),
  )
  assert_eq(doc.display(width=37), ["if (a == b) { a << 2 } else { a + b }"])
  assert_eq(doc.display(width=35), [
    "if (a == b) {", "  a << 2", "} else {", "  a + b", "}",
  ])
}

///|
test "Pyret-style functions from the docs" {
  fn show_func(name, args, body) {
    let header = horz([txt("fun "), name, txt("("), args, txt("):")])
    let on_one_line = horz([header, txt(" "), body, txt(" end")])
    let on_multiple_lines = vert([header, horz([txt("    "), body]), txt("end")])
    if_flat(on_one_line, on_multiple_lines)
  }

  let doc = show_func(
    txt("greet"),
    txt("name"),
    txt("\"Welcome back, \" + name"),
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
  let body = vert([txt("first line"), txt("second line")])
  assert_eq(horz([txt("BEGIN "), body]).display(width=80), [
    "BEGIN first line", "      second line",
  ])
  assert_eq(concat([txt("BEGIN "), body]).display(width=80), [
    "BEGIN first line", "second line",
  ])
}

///|
test "while loops from the docs" {
  let cond = txt("CONDITION")
  let body = txt("BODY")
  let doc = vert([
    horz([txt("while ("), cond, txt(") {")]),
    horz([txt("  "), body]),
    txt("}"),
  ])
  assert_eq(doc.display(width=80), ["while (CONDITION) {", "  BODY", "}"])
}

///|
test "if/then/else the way BLerner likes them" {
  fn opt_break(x, y) {
    if_flat(
      pretty([Val(x), Str(" "), Val(y)]),
      pretty([Val(x), Str("\n  "), Val(y)]),
    )
  }

  fn ifte(c, t, e) {
    if_flat(
      pretty([Str("if "), Val(c), Str(" then "), Val(t), Str(" else "), Val(e)]),
      vert([
        opt_break(txt("if"), c),
        opt_break(txt("then"), t),
        opt_break(txt("else"), e),
      ]),
    )
  }

  let doc = ifte(
    binop(txt("a"), txt("=="), txt("b")),
    binop(txt("a"), txt("<<"), txt("2")),
    binop(txt("a"), txt("+"), txt("b")),
  )
  assert_eq(doc.display(width=32), ["if a == b then a << 2 else a + b"])
  assert_eq(doc.display(width=15), ["if a == b", "then a << 2", "else a + b"])
  assert_eq(doc.display(width=10), [
    "if a == b", "then", "  a << 2", "else a + b",
  ])
}

///|
test "full_line disallows anything later on the same line" {
  let broken = vert([txt("a"), txt("A")])
  assert_eq(horz([if_flat(txt("a"), broken), txt("b")]).display(width=20), [
    "ab",
  ])
  assert_eq(
    horz([if_flat(full_line(txt("a")), broken), txt("b")]).display(width=20),
    ["a", "Ab"],
  )
}

///|
test "full_line only vetoes if_flat; it does not itself break a line" {
  assert_eq(full_line(txt("abc")).display(width=20), ["abc"])
  // With no enclosing `if_flat` to veto, "b" still lands on the same line.
  assert_eq(horz([full_line(txt("a")), txt("b")]).display(width=20), ["ab"])
  assert_eq(full_line(vert([txt("a"), txt("A")])).display(width=20), ["a", "A"])
}

///|
test "compared against Bernardy's algorithm" {
  fn plus(d1, d2) {
    binop(d1, txt("+"), d2)
  }

  fn times(d1, d2) {
    binop(d1, txt("*"), d2)
  }

  let doc = plus(times(txt("aaaaaaaaa"), txt("bb")), txt("cc"))
  assert_eq(doc.display(width=19), ["aaaaaaaaa * bb + cc"])
  assert_eq(doc.display(width=18), ["aaaaaaaaa * bb", "+ cc"])
  // Bernardy's algorithm would produce "aaaaaaaaa\n* bb + cc" here, which is
  // a little questionable.
  assert_eq(doc.display(width=13), ["aaaaaaaaa", "* bb", "+ cc"])
}

///|
test "display_string joins the lines" {
  let doc = vert([txt("aaaa"), txt("bbb")])
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
  let words = Array::makei(30, i => txt("word\{i}"))
  assert_eq(wrap(words).display(), wrap(words).display(width=80))
}

///|
test "text wider than the width simply overflows" {
  assert_eq(txt("aaaaaaaaaa").display(width=3), ["aaaaaaaaaa"])
}

///|
test "panic txt rejects newlines" {
  ignore(txt("a\nb"))
}
