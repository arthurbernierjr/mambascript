id1 :: Any -> Any = (x :: Any) :: Any -> x
id2 = (x :: Any) :: Any -> x
id3 :: String -> String = (x :: String) :: String -> x
# id3e :: String -> String = (x :: String) :: Number -> x
id4 = (x :: Any) -> x
id5 = (x) -> x
id6 :: Any -> Any = (x) -> x

id7 :: String -> String = (x :: String) :: String ->
  ''
  x
  1

add :: Int * Int -> Int
add = (x, y) -> x + y
console.log add 3, 5
ret :: Int = add 3, 5

add1 :: Int * Int -> Int
add1 = (x :: Int, y) -> x + y
# add1 = (x :: String, y) -> x + y

add2 = (x :: Int, y :: Int) :: Int -> x + y
# add2 = (x :: Int, y :: Int) :: Int -> ''
ret2 :: Int = add2 3, 5
# ret2 :: String = add2 3, 5
# add2 "", 5
