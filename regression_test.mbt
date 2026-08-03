// Guards for bugs that were once real: whitespace-only lines, and documents
// deep enough to exhaust the call stack.

///|
test "blank lines are not padded with their indentation" {
  let doc = horz([txt("ab"), vert([txt("x"), empty, txt("y")])])
  assert_eq(doc.display(), ["abx", "", "  y"])
}

///|
test "a line the user fills with spaces keeps them" {
  let doc = vert([txt("a"), txt("  "), txt("b")])
  assert_eq(doc.display(), ["a", "  ", "b"])
}

///|
/// Rendering walks an explicit stack, so document depth is not call depth.
test "a deep vert does not overflow the stack" {
  let items = []
  for i in 0..<200000 {
    items.push(txt("line \{i}"))
  }
  assert_eq(vert(items).display().length(), 200000)
}

///|
/// `wrap` used to fold its pieces together one at a time, building a chain as
/// deep as the input whatever `concat` did with arrays.
test "a deep wrap does not overflow the stack" {
  let words = []
  for i in 0..<200000 {
    words.push(txt("w\{i}"))
  }
  assert_true(wrap(words).display(width=80).length() > 0)
}

///|
/// `horz`, `vert` and `concat` split their array down the middle, so an
/// array-built document is O(log n) deep and recursive traversals -- including
/// the derived `Debug`, which has no stack of its own -- stay well inside it.
test "debug output of a deep document does not overflow the stack" {
  let items = []
  for _ in 0..<50000 {
    items.push(txt("l"))
  }
  assert_true(@debug.to_string(vert(items)).length() > 0)
  assert_true(@debug.to_string(horz(items)).length() > 0)
  assert_true(@debug.to_string(concat(items)).length() > 0)
  assert_true(@debug.to_string(wrap(items)).length() > 0)
}

///|
/// `wrap` collects its pieces and concatenates them once. This pins that
/// against the fold it replaced, which glued them on one at a time.
test "wrap agrees with gluing the pieces on one at a time" {
  let words = ["This", "is", "a", "sentence", "with", "eight", "words"].map(txt)
  guard! words is [first, .. rest]
  for seps in [(" ", ""), (", ", ",")] {
    let (sep_text, vert_sep_text) = seps
    let sep = txt(sep_text)
    let vert_sep = txt(vert_sep_text)
    let folded = rest.fold(init=first, (paragraph, word) => {
      concat([paragraph, if_flat(horz([sep, word]), vert([vert_sep, word]))])
    })
    let wrapped = wrap(words, sep=sep_text, vert_sep=vert_sep_text)
    for width in [1, 2, 3, 5, 8, 13, 21, 80] {
      assert_eq(wrapped.display(width~), folded.display(width~))
    }
  }
}

///|
/// Regrouping is only safe because all three concatenations are associative.
/// This pins that: the balanced tree must agree with an explicit left fold.
test "balanced grouping agrees with folding from the left" {
  let parts = [
    txt("aaa"),
    vert([txt("b"), txt("bb")]),
    txt("cc"),
    if_flat(txt("dddd"), vert([txt("d"), txt("ddd")])),
    txt("e"),
    vert([txt("ff"), txt("f")]),
    txt("gggg"),
  ]
  let rest = parts[1:].to_owned()
  for width in [1, 2, 3, 5, 8, 13, 21, 80] {
    assert_eq(
      horz(parts).display(width~),
      rest.fold(init=parts[0], horz2).display(width~),
    )
    assert_eq(
      vert(parts).display(width~),
      rest.fold(init=parts[0], vert2).display(width~),
    )
    assert_eq(
      concat(parts).display(width~),
      rest.fold(init=parts[0], concat2).display(width~),
    )
  }
}
