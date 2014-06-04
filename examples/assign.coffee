struct A.B.Point
  x :: Int
  y ::
    z :: Int
p :: A.B.Point = {x: 1, y: {z : 2}}
struct User
  name :: String
user :: User = {name: 'hello'}
i :: Int = 3
f :: Float = 3.14
a :: Any = ""
str :: String = ""
p2 :: {a :: Any}  = {a: ''}

i1 :: Int = 3
i2 :: Int = i1

i3 = i1
i4 :: Int = i3
# i4e :: String = i3

n1 :: Int
n1 = 1
# n = '' # err

n2 :: Int
n2 = n1

n3 :: Int = n2
n4 = n2

struct Point
  x :: Int
  y :: Int

point :: Point = {x: 1, y: 2}
point.x = 5
# p.y = ''

global.xxx = 3

struct Edge
  from :: Point
  to :: Point

point1 :: Point = {x: 1, y: 2}
point2 :: Point = {x: 3, y: 5}

edge1 :: Edge =
  from: point1
  to: point2

edge2 :: Edge =
  from:
    x: 1
    y: 2
  to: point2

# edge_error :: Edge =
#  from: point1
#  to: 3

