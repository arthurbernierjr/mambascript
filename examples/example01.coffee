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
