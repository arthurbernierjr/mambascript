class Point
  x :: Int
  y :: Int

class Entity extends Point implements Z
  width  :: Int
  height :: Int

e :: {x :: Int, y :: Int} = new Entity