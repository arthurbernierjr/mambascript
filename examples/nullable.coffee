a :: Int?
a = 1
a = null

b :: Int = 1
# b = a # can't assign nullable to non-nullable
a = b

listWithNull :: Int?[] = [1, 2, 3, null, 5]
listMaybeNull :: Int?[]? = null
listMaybeNull = listWithNull

intByConditional :: Int =
  if Math.random() > 0.5
    1
  else
    2

# can't be Int
nullableIntByConditional :: Int? =
  if Math.random() > 0.5
    1

intBySwitch :: Int =
  switch ~~(Math.random()* 10)
    when 1
      1
    when 2
      2
    else
      3

# can't be Int
nullableIntBySwitch :: Int? =
  switch ~~(Math.random()* 10)
    when 1
      1
    when 2
      2
