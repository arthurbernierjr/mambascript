class X
  num :: Number
  constructor :: Number * String -> ()
  constructor: (num, fuga) ->
    @num = num

x :: X = new X 3, ""
# x.num = ""
