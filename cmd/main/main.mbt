///|
/// A toy s-expression AST, to show what building a `Doc` from a real tree looks
/// like. Run with `moon run cmd/main`.
enum Sexpr {
  Atom(String)
  List(Array[Sexpr])
}

///|
/// Turn an s-expression into a document describing every way it may be laid
/// out. Nothing here mentions widths or indentation levels: the combinators
/// take care of both.
fn Sexpr::to_doc(self : Sexpr) -> @pp.Doc {
  match self {
    Atom(name) => @pp.txt(name)
    List([]) => @pp.txt("()")
    // `(lambda args body)` gets a layout of its own...
    List([Atom("lambda"), defn, body]) =>
      @pp.lambda_like_sexpr(@pp.txt("lambda"), defn.to_doc(), body.to_doc())
    // ...`(begin ...)` always goes vertical...
    List([Atom("begin"), .. bodies]) =>
      @pp.begin_like_sexpr(@pp.txt("begin"), bodies.map(body => body.to_doc()))
    // ...and everything else is a plain call.
    List([func, .. args]) =>
      @pp.standard_sexpr(func.to_doc(), args.map(arg => arg.to_doc()))
  }
}

///|
fn example() -> Sexpr {
  List([
    Atom("begin"),
    List([
      Atom("define"),
      Atom("greet"),
      List([
        Atom("lambda"),
        Atom("(name)"),
        List([
          Atom("string-append"),
          Atom("\"Welcome back, \""),
          Atom("name"),
          Atom("\"! Good to see you again.\""),
        ]),
      ]),
    ]),
    List([Atom("display"), List([Atom("greet"), Atom("\"Ada\"")])]),
  ])
}

///|
fn main {
  let doc = example().to_doc()
  for width in [80, 46, 30] {
    println("--- the same document at width \{width} ---")
    println(doc.display_string(width~))
    println("")
  }
  let words = "the quick brown fox jumps over the lazy dog"
    .split(" ")
    .map(word => @pp.txt(word.to_owned()))
    .collect()
  println("--- wrap at width 20 ---")
  println(@pp.wrap(words).display_string(width=20))
}
