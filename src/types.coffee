console = log: ->

pj = try require 'prettyjson'
render = (obj) -> pj?.render obj

{clone, rewrite} = require './type-helpers'
reporter = require './reporter'

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

checkAcceptableObject = (left, right) =>
  # TODO: fix
  if left?._base_? and left._templates_? then left = left._base_
  console.log 'checkAcceptableObject /', left, right

  # possibilites :: Type[]
  if right?.possibilities?
    results = (checkAcceptableObject left, r for r in right.possibilities)
    return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))

  # Any
  if left is 'Any'
    return false

  if left?._args_
    return if left is undefined or left is 'Any'
    left._args_ ?= []
    results = (checkAcceptableObject(l_arg, right._args_[i]) for l_arg, i in left._args_)
    return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))

    # check return type
    # TODO: Now I will not infer function return type
    if right._return_ isnt 'Any'
      return checkAcceptableObject(left._return_, right._return_)
    return false

  if left?.array?
    if right.array instanceof Array
      results = (checkAcceptableObject left.array, r for r in right.array)
      return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))
    else
      return checkAcceptableObject left.array, right.array

  else if right?.array?
    if left is 'Array' or left is 'Any' or left is undefined
      return false
    else
      return "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

  else if ((typeof left) is 'string') and ((typeof right) is 'string')
    if (left is right) or (left is 'Any') or (right is 'Any')
      return false
    else
      return "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

  else if ((typeof left) is 'object') and ((typeof right) is 'object')
    results =
      for key, lval of left
        if right[key] is undefined and lval? and not (key in ['_return_', 'type', 'possibilities']) # TODO avoid system values
          "'#{key}' is not defined on right"
        else
          checkAcceptableObject(lval, right[key])
    return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))
  else if (left is undefined) or (right is undefined)
    return false
  else
    return "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

# Initialize primitive types
# Number, Boolean, Object, Array, Any
initializeGlobalTypes = (node) ->
  # Primitive
  node.addTypeObject 'String', new TypeSymbol {type: 'String'}
  node.addTypeObject 'Number', new TypeSymbol {type: 'Number'}
  node.addTypeObject 'Boolean', new TypeSymbol {type: 'Boolean'}
  node.addTypeObject 'Object', new TypeSymbol {type: 'Object'}
  node.addTypeObject 'Array', new TypeSymbol {type: 'Array'}
  node.addTypeObject 'Undefined', new TypeSymbol {type: 'Undefined'}
  node.addTypeObject 'Any', new TypeSymbol {type: 'Any'}

# Known vars in scope
class VarSymbol
  # type :: String
  # implicit :: Bolean
  constructor: ({@type, @implicit}) ->

# Known types in scope
class TypeSymbol
  # type :: String or Object
  # instanceof :: (Any) -> Boolean
  constructor: ({@type, @instanceof, @_templates_}) ->
    @instanceof ?= (t) -> t instanceof @constructor

# Var and type scope as node
class Scope
  # constructor :: (Scope) -> Scope
  constructor: (@parent = null) ->
    @parent?.nodes.push this

    @name = ''
    @nodes  = [] #=> Scope[]

    # Scope vars
    @_vars  = {} #=> String -> Type

    # Scope types
    @_types = {} #=> String -> Type

    # This scope
    @_this  = {}

    @_returnables = [] #=> Type[]

  addReturnable: (symbol, type) ->
    @_returnables.push type

  getReturnables: -> @_returnables

  # addType :: String * Object * Object -> Type
  addType: (symbol, type, _templates_) ->
    @_types[symbol] = new TypeSymbol {type, _templates_}

  addTypeObject: (symbol, type_object) ->
    @_types[symbol] = type_object

  getType: (symbol) ->
    @_types[symbol]

  getTypeInScope: (symbol) ->
    @getType(symbol) or @parent?.getTypeInScope(symbol) or undefined

  addThis: (symbol, type, implicit = true) ->
    # TODO: Refactor with addVar
    if type?._base_?
      T = @getType(type._base_)
      return undefined unless T
      obj = clone T.type
      if T._templates_
        # TODO: length match
        rewrite_to = type._templates_
        replacer = {}
        for t, n in T._templates_
          replacer[t] = rewrite_to[n]
        rewrite obj, replacer

      @_this[symbol] = new VarSymbol {type:obj, implicit}
    else
      @_this[symbol] = new VarSymbol {type, implicit}

  getThis: (symbol) ->
    @_this[symbol]

  addVar: (symbol, type, implicit = true) ->
    # TODO: Refactor
    if type?._base_?
      T = @getType(type._base_)
      return undefined unless T
      obj = clone T.type
      if T._templates_
        # TODO: length match
        rewrite_to = type._templates_
        replacer = {}
        for t, n in T._templates_
          replacer[t] = rewrite_to[n]
        rewrite obj, replacer

      @_vars[symbol] = new VarSymbol {type:obj, implicit}
    else
      @_vars[symbol] = new VarSymbol {type, implicit}

  getVar: (symbol) ->
    @_vars[symbol]

  getVarInScope: (symbol) ->
    @getVar(symbol) or @parent?.getVarInScope(symbol) or undefined

  isImplicitVar: (symbol) -> !! @_vars[symbol]?.implicit

  isImplicitVarInScope: (symbol) ->
    @isImplicitVar(symbol) or @parent?.isImplicitVarInScope(symbol) or undefined

  # Extend symbol to type object
  # ex. {name : String, p : Point} => {name : String, p : { x: Number, y: Number}}
  extendTypeLiteral: (node) =>
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
        Type = @getTypeInScope(node)
        type = Type?.type
        switch typeof type
          when 'object'
            return @extendTypeLiteral(type)
          when 'string'
            return type
            
  # check object literal with extended object
  checkAcceptableObject: (left, right) ->
    l = @extendTypeLiteral(left)
    r = @extendTypeLiteral(right)
    return checkAcceptableObject(l, r)

class ClassScope extends Scope
class FunctionScope extends Scope

module.exports = {
  checkAcceptableObject, 
  initializeGlobalTypes, 
  VarSymbol, TypeSymbol, Scope, ClassScope, FunctionScope
  ArrayType, ObjectType, Type, Possibilites
}