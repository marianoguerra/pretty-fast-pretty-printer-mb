///|
/// `wrap(words)` does word wrapping: it joins the `words` with `sep` when they
/// fit on the same line, and with `vert_sep` followed by a newline when they
/// don't.
///
/// For plain word wrapping use the defaults; for wrapping a comma-separated
/// list use `sep=", "` and `vert_sep=","`.
///
/// Neither `sep` nor `vert_sep` may contain a newline.
///
/// ```mbt check
/// test {
///   let words = ["This", "is", "a", "sentence", "with", "eight", "words"].map(txt)
///   inspect(
///     wrap(words).display_string(width=20),
///     content=(
///       #|This is a sentence
///       #|with eight words
///     ),
///   )
/// }
/// ```
pub fn wrap(
  words : Array[Doc],
  sep? : String = " ",
  vert_sep? : String = "",
) -> Doc {
  guard words is [first, .. rest] else { empty }
  let sep = txt(sep)
  let vert_sep = txt(vert_sep)
  // Each word is glued on with a choice: stay on this line after `sep`, or
  // start a new one after `vert_sep`. The choices are independent, which is
  // what makes this a greedy, linear-time wrap.
  rest.fold(init=first, (paragraph, word) => {
    concat([paragraph, if_flat(horz([sep, word]), vert([vert_sep, word]))])
  })
}

///|
/// `sep_by(items)` displays either
///
/// ```text
/// items[0] sep items[1] sep ... items[n]
/// ```
///
/// if the whole thing fits on one line, or
///
/// ```text
/// items[0] vert_sep
/// items[1] vert_sep
/// ...
/// items[n]
/// ```
///
/// otherwise. Unlike [`wrap`], the choice is all-or-nothing.
///
/// Neither `sep` nor `vert_sep` may contain a newline.
///
/// ```mbt check
/// test {
///   let items = ["alpha", "beta", "gamma"].map(txt)
///   let doc = sep_by(items, sep=", ", vert_sep=",")
///   inspect(doc.display_string(width=40), content="alpha, beta, gamma")
///   inspect(
///     doc.display_string(width=10),
///     content=(
///       #|alpha,
///       #|beta,
///       #|gamma
///     ),
///   )
/// }
/// ```
pub fn sep_by(
  items : Array[Doc],
  sep? : String = " ",
  vert_sep? : String = "",
) -> Doc {
  let vert_sep = txt(vert_sep)
  let last = items.length() - 1
  let vert_items = items.mapi((i, item) => {
    if i == last {
      item
    } else {
      horz([item, vert_sep])
    }
  })
  if_flat(horz(intersperse(txt(sep), items)), vert(vert_items))
}

///|
/// `parens(center)` wraps `center` in parentheses, keeping the closing paren
/// glued to the end of the last line.
///
/// ```mbt check
/// test {
///   inspect(parens(txt("a b")).display_string(), content="(a b)")
/// }
/// ```
pub fn parens(center : Doc) -> Doc {
  horz([txt("("), center, txt(")")])
}

///|
/// `standard_sexpr(func, args)` renders as
///
/// ```text
/// (func args ... args)
/// ```
///
/// or, when that does not fit, as
///
/// ```text
/// (func
///  args
///  ...
///  args)
/// ```
///
/// ```mbt check
/// test {
///   let doc = standard_sexpr(txt("function"), [txt("very-long-argument")])
///   inspect(doc.display_string(), content="(function very-long-argument)")
///   inspect(
///     doc.display_string(width=20),
///     content=(
///       #|(function
///       #| very-long-argument)
///     ),
///   )
/// }
/// ```
pub fn standard_sexpr(func : Doc, args : Array[Doc]) -> Doc {
  let items = [func]
  items.append(args)
  parens(sep_by(items))
}

///|
/// `lambda_like_sexpr(keyword, defn, body)` renders as
///
/// ```text
/// (keyword defn body)
/// ```
///
/// or, when that does not fit, as
///
/// ```text
/// (keyword defn
///   body)
/// ```
///
/// ```mbt check
/// test {
///   let doc = lambda_like_sexpr(
///     txt("lambda"),
///     txt("(number)"),
///     txt("(* number number)"),
///   )
///   inspect(doc.display_string(), content="(lambda (number) (* number number))")
///   inspect(
///     doc.display_string(width=25),
///     content=(
///       #|(lambda (number)
///       #|  (* number number))
///     ),
///   )
/// }
/// ```
pub fn lambda_like_sexpr(keyword : Doc, defn : Doc, body : Doc) -> Doc {
  if_flat(
    parens(sep_by([keyword, defn, body])),
    parens(vert([horz([keyword, txt(" "), defn]), horz([txt(" "), body])])),
  )
}

///|
/// `begin_like_sexpr(keyword, bodies)` always breaks, rendering as
///
/// ```text
/// (keyword
///   bodies
///   ...
///   bodies)
/// ```
///
/// ```mbt check
/// test {
///   let doc = begin_like_sexpr(txt("begin"), ["1", "2", "3"].map(txt))
///   inspect(
///     doc.display_string(),
///     content=(
///       #|(begin
///       #|  1
///       #|  2
///       #|  3)
///     ),
///   )
/// }
/// ```
pub fn begin_like_sexpr(keyword : Doc, bodies : Array[Doc]) -> Doc {
  parens(vert([keyword, horz([txt(" "), vert(bodies)])]))
}

///|
/// `[a, b, c]` with `sep` -> `[a, sep, b, sep, c]`.
fn intersperse(sep : Doc, items : Array[Doc]) -> Array[Doc] {
  let result = []
  for i, item in items {
    if i != 0 {
      result.push(sep)
    }
    result.push(item)
  }
  result
}
