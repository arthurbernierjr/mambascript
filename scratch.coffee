# struct Hash<K, V> {
#   get :: K -> V
#   set :: K * V -> ()
# }

# hash :: Hash<String, Number> =
#   get: (key) -> @[key]
#   set: (key, val) -> @[key] = val
# # hash :: Hash<String, Number>
# # hash =
# #   get: (key) -> @[key]
# #   set: (key, val) -> @[key] = val

# hash.set "", 1
# hash.get 1

struct Hash<K, V> {
  get :: K -> V
  set :: K * V -> ()
}
hash :: Hash<String, Number> = {
  get: (key) -> @[key]
  set: (key, val) -> @[key] = val
}
hash.set "a", 1
hash.get 3