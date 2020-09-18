eq = (value, test)->
  expect(test is value).toBeTruthy()

test 'can parse simple arrays', ->
  eq 0, [].length
  eq 0, [ ].length
  eq 0, [[]][0].length
  eq 1, [[0]].length
  eq 1, [[0]][0].length
  eq 2, [[0],[1]].length
  eq 0, [[0],[1]][0][0]
  eq 1, [[0],[1]][1][0]
  eq 3, [
    []
    [[], []]
    [ [[], []], [] ]
  ].length

test 'arrays spread over many lines', ->
  eq 0, [
  ].length
  eq 1, [
    0
  ].length
  eq 1, [
    0,
  ].length
  eq 2, [
    0
    0
  ].length
  eq 2, [
    0,
    0
  ].length
  eq 2, [
    0,
    0,
  ].length
  eq 2, [
    -> 5 * 5,
    (x)-> x ** x
  ].length
