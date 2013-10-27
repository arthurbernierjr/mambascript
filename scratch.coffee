struct Point {
  x :: Number
  y :: Number
}

# p :: Point = {x: 3, y: 2}
# tarr :: Point[]  = [{x : 3, y: 3}, {x : 3, y: 3}, p]

# obj :: Point = { x : 3, z: 5 } #=> throw

rp :: () -> Point = () -> { x : 3, y : 5}
# rp()

console.log 'done'