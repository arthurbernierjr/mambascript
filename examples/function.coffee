# basic function
add :: Int * Int -> Int
add = (x, y) -> x + y
add 3, 5
ret :: Int = add 3, 5

# partial application
partial :: Int -> Int -> Int
partial = (m) -> (n) -> m + n
partial(3)(2)

# generics
map<T, U> :: T[] * (T -> U) -> U[]
map = (list, fn) ->
  for i in list
    fn(i)
list :: String[] = map<Int, String> [1..10], (n) -> ''

# nullable return with null
nullableFunc :: Int -> Int?
nullableFunc = (n) ->
  if n > 10
    return n
  else
    return null
  3
nullableFunc 5