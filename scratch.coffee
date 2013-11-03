# arr1 :: Number[] = [1,2,3]
# arr2 :: Number[] = (i for i in [1,2,3])

# arr3 = (i for i in [1,2,3])
# list :: String[] = [1..10]

# a :: Number = if true then 3 else ""

struct Hoge {
  arr :: Number[]
  name :: String
}

# arr :: Number[] = ("" for i in [1,2,3])

v :: Hoge = { arr : [1,2,3], name: 'hoge'}
v2 :: Hoge = { arr : [1,2,''], name: 'hoge'}