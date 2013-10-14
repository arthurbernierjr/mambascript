ok = require 'assert'

x :: Number = 3
y :: String = "hello"
z :: Boolean = false
# z :: String = 4 #=> Error
# y = x #=> Error
# a :: Any = 3
# a = 'fadfa'
# b = 'a'
# fn :: Function = ->
#   x = 3
#   n = ->
#     i = ''

# f2 :: Function = (a :: Number) ->
#   a + 3

# class X
#   f: ->
#     n = 3
obj :: { x :: Number } = { x : 3 }
obj.x = 5
# obj.x = ""
console.log 'finish'
