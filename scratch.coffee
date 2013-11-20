class Point
  x :: Int
  y :: Int

struct Size {
  width  :: Int
  height :: Int
}

# class Entity extends Point implements Z
class Entity extends Object implements Point, Size

e :: {x :: Int, width :: Int} = new Entity