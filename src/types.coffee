console = log: ->

pj = try require 'prettyjson'
render = (obj) -> pj?.render obj

{clone, rewrite} = require './type-helpers'
reporter = require './reporter'

NumberInterface =
  toString:
    name: 'function'
    _args_: []
    _return_: 'String'

ArrayInterface =
  length: 'Number'
  push:
    name: 'function'
    _args_: ['T']
    _return_: 'void'
  unshift:
    name: 'function'
    _args_: ['T']
    _return_: 'void'
  shift:
    name: 'function'
    _args_: []
    _return_: 'T'
  toString:
    name: 'function'
    _args_: []
    _return_: 'String'

ObjectInterface = ->
  toString:
    name: 'function'
    _args_: []
    _return_: 'String'
  keys:
    name: 'function'
    _args_: ['Any']
    _return_:
      array: 'String'

class Type
  constructor: ->

# ObjectType :: T -> Object
class ObjectType extends Type
  # :: String -> ()
  constructor:(@type) ->

# ArrayType :: {array :: T} = array: T
class ArrayType extends Type
  constructor:(type) ->
    @array = type

# possibilities :: Type[] = []
class Possibilites extends Array
  constructor: (arr = []) ->
    @push i for i in arr

# Exec down casting
# pass obj :: {x :: Number, name :: String} = {x : 3, y : "hello"}
# ng   obj :: {x :: Number, name :: String} = {x : 3, y : 5 }

# TODO: Add Transparent, Passable, Unknown
checkAcceptableObject = (left, right) ->
  # TODO: fix
  if left?.base? and left.templates? then left = left.base

  console.log 'checkAcceptableObject /', left, right

  # possibilites :: Type[]
  if right?.possibilities?
    for r in right.possibilities
      checkAcceptableObject left, r
    return

  # {array: "Number"} <> {array: "Number"}
  # {array: "Number"} <> {array: ["Number", 'Number']}
  if left is 'Any' then return

  if left?.array?

    if right.array instanceof Array
      checkAcceptableObject left.array, r for r in right.array
    else
      checkAcceptableObject left.array, right.array

  # "Array" <> array: Number
  else if right?.array?
    if left is 'Array' or left is 'Any' or left is undefined then 'ok'
    else
      reporter.add_error {}, "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

  else if ((typeof left) is 'string') and ((typeof right) is 'string')
    if (left is right) or (left is 'Any') or (right is 'Any')
      'ok'
    else
      reporter.add_error {}, "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

  # {x: "Nubmer", y: "Number"} <> {x: "Nubmer", y: "Number"}
  else if ((typeof left) is 'object') and ((typeof right) is 'object')
    for key, lval of left
      # when {x: Number} = {z: Number}
      if right[key] is undefined and lval?
        return if key in ['_return_', 'type'] # TODO ArrayTypeをこっちで吸収してないから色々きちゃう
        return reporter.add_error {}, "'#{key}' is not defined on right"

      checkAcceptableObject(lval, right[key])
  else if (left is undefined) or (right is undefined)
    "ignore now"
  else
    reporter.add_error {}, "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

# Initialize primitive types
# Number, Boolean, Object, Array, Any
initializeGlobalTypes = (node) ->
  # Primitive
  node.addTypeObject 'String', new TypeSymbol {
    type: 'String'
    instanceof: (expr) -> (typeof expr.data) is 'string'
  }

  node.addTypeObject 'Number', new TypeSymbol {
    type: 'Number'
    instanceof: (expr) -> (typeof expr.data) is 'number'
  }

  node.addTypeObject 'Boolean', new TypeSymbol {
    type: 'Boolean'
    instanceof: (expr) -> (typeof expr.data) is 'boolean'
  }

  node.addTypeObject 'Object', new TypeSymbol {
    type: 'Object'
    instanceof: (expr) -> (typeof expr.data) is 'object'
  }

  node.addTypeObject 'Array', new TypeSymbol {
    type: 'Array'
    instanceof: (expr) -> (typeof expr.data) is 'object'
  }

  node.addTypeObject 'Undefined', new TypeSymbol {
    type: 'Undefined'
    instanceof: (expr) -> expr.data is 'undefined'
  }

  # Any
  node.addTypeObject 'Any', new TypeSymbol {
    type: 'Any'
    instanceof: (expr) -> true
  }

# Known vars in scope
class VarSymbol
  # type :: String
  # implicit :: Bolean
  constructor: ({@type, @implicit}) ->

# Known types in scope
class TypeSymbol
  # type :: String or Object
  # instanceof :: (Any) -> Boolean
  constructor: ({@type, @instanceof, @templates}) ->
    @instanceof ?= (t) -> t instanceof @constructor

# Var and type scope as node
class Scope
  # constructor :: (Scope) -> Scope
  constructor: (@parent = null) ->
    @parent?.nodes.push this

    @name = ''
    @nodes  = [] #=> scopeeNode...

    # スコープ変数
    @_vars  = {} #=> symbol -> type

    # 登録されている型
    @_types = {} #=> typeName -> type

    # TODO: This Scope
    @_this  = {} #=> null or {}

    # このブロックがReturn する可能性があるもの
    @_returnables = [] #=> [ReturnableType...]

  addReturnable: (symbol, type) ->
    @_returnables.push type

  getReturnables: -> @_returnables

  # addType :: String * Object * Object -> Type
  addType: (symbol, type, templates) ->
    @_types[symbol] = new TypeSymbol {type, templates}

  addTypeObject: (symbol, type_object) ->
    @_types[symbol] = type_object

  getType: (symbol) ->
    @_types[symbol]?.type or undefined

  getTypeObject: (symbol) ->
    @_types[symbol]

  getTypeInScope: (symbol) ->
    @getType(symbol) or @parent?.getTypeInScope(symbol) or undefined

  addThis: (symbol, type, implicit = true) ->
    @_this[symbol] = {type, implicit}

  getThis: (symbol) ->
    @_this[symbol]?.type ? undefined

  addVar: (symbol, type, implicit = true) ->
    console.log 'addvar;', symbol, type

    if type?.base?
      # modify type
      T = @getTypeObject(type.base)
      return undefined unless T
      obj = clone T.type
      if T.templates
        # create replacer and replace
        # TODO: length match
        rewrite_to = type.templates
        replacer = {} #=> inpupt => ouput
        for t, n in T.templates
          replacer[t] = rewrite_to[n]
        rewrite obj, replacer

      @_vars[symbol] = new VarSymbol {type:obj, implicit}
    else
      @_vars[symbol] = new VarSymbol {type, implicit}

  getVar: (symbol) ->
    @_vars[symbol]?.type ? undefined

  getVarInScope: (symbol) ->
    @getVar(symbol) or @parent?.getVarInScope(symbol) or undefined

  isImplicitVar: (symbol) -> !! @_vars[symbol]?.implicit

  isImplicitVarInScope: (symbol) ->
    @isImplicitVar(symbol) or @parent?.isImplicitVarInScope(symbol) or undefined

  # Extend symbol to type object
  # ex. {name : String, p : Point} => {name : String, p : { x: Number, y: Number}}
  extendTypeLiteral: (node) ->
    switch (typeof node)
      when 'object'
        # array
        if node instanceof Array
          return (@extendTypeLiteral(i) for i in node)
        # object
        else
          ret = {}
          for key, val of node
            ret[key] = @extendTypeLiteral(val)
          return ret
      when 'string'
        type = @getTypeInScope(node)
        switch typeof type
          when 'object'
            return @extendTypeLiteral(type)
          when 'string'
            return type
            
  # check object literal with extended object
  checkAcceptableObject: (left, right) ->
    l = @extendTypeLiteral(left)
    r = @extendTypeLiteral(right)
    checkAcceptableObject(l, r)

  # Check arguments
  checkFunctionLiteral: (left, right) ->
    console.log 'checkFunctionLiteral', left, right 
    # flat extend
    left  = @extendTypeLiteral left
    right = @extendTypeLiteral right
    return if left is undefined or left is 'Any'
    left._args_ ?= []
    # check _args_
    console.log left
    if left?._args_ is undefined
      return reporter.add_error node, "left is not arguments: #{JSON.stringify left}, #{JSON.stringify right}"
    for l_arg, i in left._args_
      r_arg = right._args_[i]
      checkAcceptableObject(l_arg, r_arg)

    # check return type
    # TODO: Now I will not infer function return type
    if right._return_ isnt 'Any'
      checkAcceptableObject(left._return_, right._return_)

module.exports = {
  checkAcceptableObject, 
  initializeGlobalTypes, 
  VarSymbol, TypeSymbol, Scope, 
  ArrayType, ObjectType, Type, Possibilites
}