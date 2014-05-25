class LimitedValue
  current :: Number
  max     :: Number

  constructor: (current :: Number, max :: Number) ->
    @current = current
    @max = max

class Entity
  id :: String

  constructor: ->
    @id = Math.random().toString()

class Battler extends Entity
  wp :: LimitedValue
  hp :: LimitedValue

  constructor: ->
    super
    @hp = new LimitedValue 30, 30
    @wp = new LimitedValue 0, 30

  updateByEachTurn: ->
    @wp.current += 1
    @wp.current = ''

battler = new Battler
battler.updateByEachTurn()
console.log battler
