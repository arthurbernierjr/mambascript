struct Singleton<T> {
  getInstance :: () -> T
}
struct Point {
  x :: Number
  y :: Number
}

origin :: Singleton<Point> =
  getInstance: () :: Point -> {x: 0, y: 0}

s :: Point = origin.getInstance()

struct Hash<K, V> {
  get :: K -> V
  set :: K * V -> ()
}

hash :: Hash<String, Number> = {
  get: (key) -> @[key]
  set: (key, val) -> @[key] = val
}

hash.set "", 1
hash.get 1
a :: Object = hash.get 1
