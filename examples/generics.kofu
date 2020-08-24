# struct
struct Value<T, U>
  value :: U
struct Id<A, B>
  id :: Value<A, B>
obj :: Id<Int, String> =
  id:
    value: ''

# function type arguments
map<T, U> :: T[] * (T -> U) -> U[]
map = (list, fn) ->
  for i in list
    fn(i)
list :: String[] = map<Int, String> [1..10], (n) -> 'i'

# class type arguments
class Class<A>
  f :: Int -> Int
  constructor :: A -> ()
  constructor: (a) ->
c = new Class<Int>(1)
