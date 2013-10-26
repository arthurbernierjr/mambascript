# add1 :: (Number, Number) -> Number = (x :: Number, y :: Number) :: Number -> x + y
# console.log add1 3, 5
# add2 = (x :: Number, y :: Number) :: Number -> x + y
# add3 :: (Number, Number) -> Number = (x, y) -> x + y
# add4 = (x, y) -> x + y

# f :: Number -> Number = (n :: Number) :: Number ->  n * n
# (f 3)
# # (f "hello")
# (f 3, 8)
# n = (f 3, 8)

# x :: Number = (f 3)
# console.log 'done'

# fun :: Number -> Number = (n) ->  n * n
# obj :: {a :: Number} = {a: (fun 4)}
# obj2 :: {a :: String} = {a: (fun 4)}

# arr = [1, 'hoge', false]

# tarr :: Array of Point  = [1, 'hoge', false]
struct Point {
  x :: Number
  y :: Number
}

p :: Point = {x: 3, y: 2}
tarr :: Point[]  = [{x : 3, y: 3}, {x : 3, y: 3}, p]

console.log 'done', tarr