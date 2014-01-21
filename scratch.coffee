struct Point {
  x :: Int
  y :: Int
}

struct Region {
  x :: Int
  y :: Int
  width :: Int
  height :: Int
}

struct Model<T> {
  attributes :: T
  toJSON :: () -> T
  get :: String -> Any
  set :: String * Any -> Any
  on :: String * Function -> ()
}

# property :: Object * String -> ()
property = (obj, key, onSet = null) ->
  console.log 'onSet', onSet
  Object.defineProperty obj, key,
    get: ->
      @model.get key
    set: (val) ->
      @model.set key, val
      if onSet?
        @model.on key, onSet
window.property = property

class View extends Backbone.View
  css: -> @$el.css arguments...
  selectorCss: (selector, args...) -> @$(selector).css args...

  @cssProperty: (key, propertyName) ->
    propertyName ?= key
    Object.defineProperty View.prototype, key,
      get: -> @css(propertyName)
      set: (v :: String) -> @css propertyName, v

  template: ->
  bindings: {}

  render: ->
    @$el.html CoffeeKup.render @template if @template
    @stickit()

  initialize: (options) ->
    @model ?= new Backbone.Model (options?.props ? {})
    @render()

  dispose: ->
    @$el.remove()


  attach: (selector)->
    $(selector).append @$el

  detach: ->
    @$el.detach()

class RegionView extends View #implements Region
  # bgColor :: String

  View.cssProperty 'x', 'left'
  View.cssProperty 'y', 'top'
  View.cssProperty 'width'
  View.cssProperty 'height'
  View.cssProperty 'bgColor', 'backgroundColor'

  initialize: ->
    View::initialize.apply(@)
    @css position: 'absolute'

class Header extends RegionView
  template: ->
    span 'text'

$ ->
  header = new Header
  header.x = 0
  header.y = 0
  header.width = 480
  header.height = 100
  # header.bgColor = "red"

  header.attach 'body'
  window.header = header

  # window.a = a
  # a.height = 500
