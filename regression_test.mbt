// Guards for bugs that were once real: whitespace-only lines, and documents
// deep enough to exhaust the call stack.

///|
test "blank lines are not padded with their indentation" {
  let doc = @pp.horz([
    @pp.txt("ab"),
    @pp.vert([@pp.txt("x"), @pp.empty, @pp.txt("y")]),
  ])
  assert_eq(doc.display(), ["abx", "", "  y"])
}

///|
test "a line the user fills with spaces keeps them" {
  let doc = @pp.vert([@pp.txt("a"), @pp.txt("  "), @pp.txt("b")])
  assert_eq(doc.display(), ["a", "  ", "b"])
}

///|
/// Rendering walks an explicit stack, so document depth is not call depth.
test "a deep vert does not overflow the stack" {
  let items = []
  for i in 0..<200000 {
    items.push(@pp.txt("line \{i}"))
  }
  assert_eq(@pp.vert(items).display().length(), 200000)
}

///|
/// `wrap` used to fold its pieces together one at a time, building a chain as
/// deep as the input whatever `concat` did with arrays.
test "a deep wrap does not overflow the stack" {
  let words = []
  for i in 0..<200000 {
    words.push(@pp.txt("w\{i}"))
  }
  assert_true(@pp.wrap(words).display(width=80).length() > 0)
}

///|
/// `horz`, `vert` and `concat` split their array down the middle, so an
/// array-built document is O(log n) deep and recursive traversals -- including
/// the derived `Debug`, which has no stack of its own -- stay well inside it.
test "debug output of a deep document does not overflow the stack" {
  let items = []
  for _ in 0..<50000 {
    items.push(@pp.txt("l"))
  }
  assert_true(@debug.to_string(@pp.vert(items)).length() > 0)
  assert_true(@debug.to_string(@pp.horz(items)).length() > 0)
  assert_true(@debug.to_string(@pp.concat(items)).length() > 0)
  assert_true(@debug.to_string(@pp.wrap(items)).length() > 0)
}

///|
/// `wrap` collects its pieces and concatenates them once. This pins that
/// against the fold it replaced, which glued them on one at a time.
test "wrap agrees with gluing the pieces on one at a time" {
  let words = ["This", "is", "a", "sentence", "with", "eight", "words"].map(
    @pp.txt,
  )
  guard! words is [first, .. rest]
  for seps in [(" ", ""), (", ", ",")] {
    let (sep_text, vert_sep_text) = seps
    let sep = @pp.txt(sep_text)
    let vert_sep = @pp.txt(vert_sep_text)
    let folded = rest.fold(init=first, (paragraph, word) => {
      @pp.concat([
        paragraph,
        @pp.if_flat(@pp.horz([sep, word]), @pp.vert([vert_sep, word])),
      ])
    })
    let wrapped = @pp.wrap(words, sep=sep_text, vert_sep=vert_sep_text)
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
    @pp.txt("aaa"),
    @pp.vert([@pp.txt("b"), @pp.txt("bb")]),
    @pp.txt("cc"),
    @pp.if_flat(@pp.txt("dddd"), @pp.vert([@pp.txt("d"), @pp.txt("ddd")])),
    @pp.txt("e"),
    @pp.vert([@pp.txt("ff"), @pp.txt("f")]),
    @pp.txt("gggg"),
  ]
  let rest = parts[1:].to_owned()
  for width in [1, 2, 3, 5, 8, 13, 21, 80] {
    assert_eq(
      @pp.horz(parts).display(width~),
      rest.fold(init=parts[0], @pp.horz2).display(width~),
    )
    assert_eq(
      @pp.vert(parts).display(width~),
      rest.fold(init=parts[0], @pp.vert2).display(width~),
    )
    assert_eq(
      @pp.concat(parts).display(width~),
      rest.fold(init=parts[0], @pp.concat2).display(width~),
    )
  }
}
