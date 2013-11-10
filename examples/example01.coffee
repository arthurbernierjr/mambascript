ok = require 'assert'

x :: Number = 3
y :: String = "hello"
z :: Boolean = false
# k :: String = 4 #=> Error
# # y = x #=> Error
a :: Any = 3
a = 'fadfa'
b = 'a'
fn :: Function = ->
  x = 3
  n = ->
    i = ''

f2 :: Function = (a :: Number) ->
  a + 3

class X
  f: ->
    n = 3

obj :: { x :: Number, y :: Number } = { x : 3, y : 5}
obj2 :: {
  x :: Number
  y :: Number
} = { x : 3, y : 3} # should throw
# obj2.y = "xxx" # 例外
obj.x = 5
# obj.x = ""

f :: Number -> Number = (n :: Number) :: Number ->  n * n
n :: Number  = f 4

fh :: Function = (n :: Number) :: (Number -> Number) -> (m)-> n * m

struct Point {
  x :: Number
  y :: Number
}

p :: Point = {x: 3, y: 3}

console.log typeof a
console.log 'finish', f n

(x) -> console.log 'x'

nf :: () -> () = -> setTimeout (->), 100
nx :: () -> void = ->
  setTimeout (->), 100



nested :: Nested = {x: 3, y: {a : 1 , b : 'foo'}}

struct B {
  num :: Number
}

struct Point {
  x :: Number
  y :: {
    a :: B
    b :: String
  }
}
pn :: Point = {x: 3, y: {a : {num: 4} , b : 'foo'}}

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
# struct Point {
#   x :: Number
#   y :: Number
# }

# p :: Point = {x: 3, y: 2}
# tarr :: Point[]  = [{x : 3, y: 3}, {x : 3, y: 3}, p]

# obj :: Point = { x : 3, z: 5 } #=> throw

# hoge_list = [1,2,'hoge']
# _xx_ :: String = 'ss'

# list :: Number[] =
#   for i :: Number, n in [1..3]
#     nn :: Number  = 3
#     nn

# list2 :: Number[] =
#   for i :: Number, n in [1..3]
#     i

# list3 :: Number[] =
#   for i :: Number, n in [1..3]
#     n

# list :: Number[] =
#   for key :: String, val :: Number of {x: 77, y: 6}
#     val

# f0 :: () -> Number = () :: Number -> 3

# f0 :: () -> Number = () :: Number -> ''

# f1 :: () -> Number = () :: Number ->
  # 3

# f2 :: () -> Number = ->
#   return ""


# n = 1
# x :: Number =
#   switch 1
#     when 1
#       1
#     when 2
#       2
#     else
#       3
# console.log


# a :: Number = (3 + 3 * 6) / 2
# # b :: String = 3 + 3
# c :: String = {} + ""

# arr1 :: Number[] = [1,2,3]
# arr2 :: Number[] = (i for i in [1,2,3])

# arr3 = (i for i in [1,2,3])
# list :: String[] = [1..10]

# a :: Number = if true then 3 else ""

# struct Hoge {
#   arr :: Number[]
#   name :: String
# }

# arr :: Number[] = ("" for i in [1,2,3])

# v :: Hoge = { arr : [1,2,3], name: 'hoge'}
# v2 :: Hoge = { arr : [1,2,''], name: 'hoge'}
