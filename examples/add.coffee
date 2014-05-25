add1 :: Number * Number -> Number = (x :: Number, y :: Number) :: Number -> x + y

add2 = (x :: Number, y :: Number) :: Number -> x + y

add3 :: Number * Number -> Number = (x, y) -> x + y

add4 = (x, y) -> x + y

console.log add4 3, 5
