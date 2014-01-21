class X
  f: -> console.log arguments...
class Y extends X
  g: ->
    super.f ""
