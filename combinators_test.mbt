///|
test "wrap an eight-word sentence" {
  let sentence = wrap(
    ["This", "is", "a", "sentence", "with", "eight", "words"].map(txt),
  )
  assert_eq(sentence.display(width=40), ["This is a sentence with eight words"])
  assert_eq(sentence.display(width=30), [
    "This is a sentence with eight", "words",
  ])
  assert_eq(sentence.display(width=20), [
    "This is a sentence", "with eight words",
  ])
  assert_eq(sentence.display(width=10), [
    "This is a", "sentence", "with eight", "words",
  ])
}

///|
test "wrap a hundred-word paragraph" {
  let sentence = [
    "This", "is", "a", "long", "paragraph", "with", "exactly", "one", "hundred",
    "words.",
  ]
  let para = []
  for _ in 0..<10 {
    para.append(sentence.map(txt))
  }
  inspect(
    wrap(para).display_string(width=55),
    content=(
      #|This is a long paragraph with exactly one hundred
      #|words. This is a long paragraph with exactly one
      #|hundred words. This is a long paragraph with exactly
      #|one hundred words. This is a long paragraph with
      #|exactly one hundred words. This is a long paragraph
      #|with exactly one hundred words. This is a long
      #|paragraph with exactly one hundred words. This is a
      #|long paragraph with exactly one hundred words. This is
      #|a long paragraph with exactly one hundred words. This
      #|is a long paragraph with exactly one hundred words.
      #|This is a long paragraph with exactly one hundred
      #|words.
    ),
  )
}

///|
/// The worked word-wrapping example from upstream's `guide.md`.
test "wrap the guide's Lorem ipsum paragraph" {
  let text =
    #|Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
  let words = text.split(" ").map(word => txt(word.to_owned())).collect()
  inspect(
    wrap(words).display_string(),
    content=(
      #|Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
      #|incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
      #|nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
      #|Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
      #|fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
      #|culpa qui officia deserunt mollit anim id est laborum.
    ),
  )
}

///|
test "wrap a comma-separated list" {
  let items = ["alpha", "beta", "gamma", "delta"].map(txt)
  let doc = wrap(items, sep=", ", vert_sep=",")
  assert_eq(doc.display(width=40), ["alpha, beta, gamma, delta"])
  assert_eq(doc.display(width=14), ["alpha, beta,", "gamma, delta"])
  // `vert_sep` is emitted at the current column, so it can overhang the width
  // by its own length: "alpha, beta, gamma" exactly fills 18 columns, and the
  // trailing comma lands in column 19.
  assert_eq(doc.display(width=18), ["alpha, beta, gamma,", "delta"])
}

///|
test "sep_by breaks all or nothing" {
  let items = ["alpha", "beta", "gamma"].map(txt)
  let doc = sep_by(items, sep=", ", vert_sep=",")
  assert_eq(doc.display(width=40), ["alpha, beta, gamma"])
  // `wrap` would keep "alpha, beta," together here; `sep_by` breaks every
  // separator once it breaks any of them.
  assert_eq(doc.display(width=15), ["alpha,", "beta,", "gamma"])
}

///|
test "standard s-expressions" {
  let doc = standard_sexpr(txt("function"), [txt("very-long-argument")])
  assert_eq(doc.display(width=80), ["(function very-long-argument)"])
  assert_eq(doc.display(width=20), ["(function", " very-long-argument)"])
}

///|
test "lambda-like s-expressions" {
  let doc = lambda_like_sexpr(
    txt("lambda"),
    txt("(number)"),
    txt("(* number number)"),
  )
  assert_eq(doc.display(width=80), ["(lambda (number) (* number number))"])
  assert_eq(doc.display(width=25), ["(lambda (number)", "  (* number number))"])
}

///|
test "begin-like s-expressions" {
  let doc = begin_like_sexpr(txt("begin"), ["1", "2", "3"].map(txt))
  assert_eq(doc.display(width=80), ["(begin", "  1", "  2", "  3)"])
}

///|
test "parens" {
  assert_eq(parens(txt("a b")).display(), ["(a b)"])
  assert_eq(parens(vert([txt("aa"), txt("bb")])).display(), ["(aa", " bb)"])
}

///|
test "txt_lines splits on newlines" {
  assert_eq(txt_lines("one\ntwo\nthree").display(), ["one", "two", "three"])
  assert_eq(txt_lines("no newlines").display(), ["no newlines"])
  assert_eq(horz([txt("> "), txt_lines("one\ntwo")]).display(), [
    "> one", "  two",
  ])
}

///|
test "nested s-expressions pick their own layouts" {
  let inner = standard_sexpr(txt("+"), [txt("1"), txt("2")])
  let doc = begin_like_sexpr(txt("begin"), [
    inner,
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
