///|
test "wrap an eight-word sentence" {
  let sentence = @pp.wrap(
    ["This", "is", "a", "sentence", "with", "eight", "words"].map(@pp.txt),
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
    para.append(sentence.map(@pp.txt))
  }
  inspect(
    @pp.wrap(para).display_string(width=55),
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
  let words = text.split(" ").map(word => @pp.txt(word.to_owned())).collect()
  inspect(
    @pp.wrap(words).display_string(),
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
  let items = ["alpha", "beta", "gamma", "delta"].map(@pp.txt)
  let doc = @pp.wrap(items, sep=", ", vert_sep=",")
  assert_eq(doc.display(width=40), ["alpha, beta, gamma, delta"])
  assert_eq(doc.display(width=14), ["alpha, beta,", "gamma, delta"])
  // `vert_sep` is emitted at the current column, so it can overhang the width
  // by its own length: "alpha, beta, gamma" exactly fills 18 columns, and the
  // trailing comma lands in column 19.
  assert_eq(doc.display(width=18), ["alpha, beta, gamma,", "delta"])
}

///|
test "sep_by breaks all or nothing" {
  let items = ["alpha", "beta", "gamma"].map(@pp.txt)
  let doc = @pp.sep_by(items, sep=", ", vert_sep=",")
  assert_eq(doc.display(width=40), ["alpha, beta, gamma"])
  // `wrap` would keep "alpha, beta," together here; `sep_by` breaks every
  // separator once it breaks any of them.
  assert_eq(doc.display(width=15), ["alpha,", "beta,", "gamma"])
}

///|
test "standard s-expressions" {
  let doc = @pp.standard_sexpr(@pp.txt("function"), [
    @pp.txt("very-long-argument"),
  ])
  assert_eq(doc.display(width=80), ["(function very-long-argument)"])
  assert_eq(doc.display(width=20), ["(function", " very-long-argument)"])
}

///|
test "lambda-like s-expressions" {
  let doc = @pp.lambda_like_sexpr(
    @pp.txt("lambda"),
    @pp.txt("(number)"),
    @pp.txt("(* number number)"),
  )
  assert_eq(doc.display(width=80), ["(lambda (number) (* number number))"])
  assert_eq(doc.display(width=25), ["(lambda (number)", "  (* number number))"])
}

///|
test "begin-like s-expressions" {
  let doc = @pp.begin_like_sexpr(@pp.txt("begin"), ["1", "2", "3"].map(@pp.txt))
  assert_eq(doc.display(width=80), ["(begin", "  1", "  2", "  3)"])
}

///|
test "parens" {
  assert_eq(@pp.parens(@pp.txt("a b")).display(), ["(a b)"])
  assert_eq(@pp.parens(@pp.vert([@pp.txt("aa"), @pp.txt("bb")])).display(), [
    "(aa", " bb)",
  ])
}

///|
test "txt_lines splits on newlines" {
  assert_eq(@pp.txt_lines("one\ntwo\nthree").display(), ["one", "two", "three"])
  assert_eq(@pp.txt_lines("no newlines").display(), ["no newlines"])
  assert_eq(@pp.horz([@pp.txt("> "), @pp.txt_lines("one\ntwo")]).display(), [
    "> one", "  two",
  ])
}

///|
test "nested s-expressions pick their own layouts" {
  let inner = @pp.standard_sexpr(@pp.txt("+"), [@pp.txt("1"), @pp.txt("2")])
  let doc = @pp.begin_like_sexpr(@pp.txt("begin"), [
    inner,
    @pp.standard_sexpr(@pp.txt("display"), [
      @pp.txt("a-fairly-long-variable-name"),
    ]),
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
