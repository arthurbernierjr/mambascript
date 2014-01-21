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
  constructor:(@dataType) ->

# ArrayType :: {array :: T} = array: T
class ArrayType extends Type
  constructor:(dataType) ->
    @array = dataType

# possibilities :: Type[] = []
class Possibilites extends Array
  constructor: (arr = []) ->
    @push i for i in arr

checkAcceptableObject = (left, right, scope) =>
  # TODO: fix
  if left?._base_? and left._templates_? then left = left._base_
  console.log 'checkAcceptableObject /', left, right

  # possibilites :: Type[]
  if right?.possibilities?
    results = (checkAcceptableObject left, r, scope for r in right.possibilities)
    return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))

  # Any
  if left is 'Any'
    return false

  if left?._args_
    return if left is undefined or left is 'Any'
    left._args_ ?= []
    results = (checkAcceptableObject(l_arg, right._args_[i], scope) for l_arg, i in left._args_)
    return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))

    # check return dataType
    # TODO: Now I will not infer function return dataType
    if right._return_ isnt 'Any'
      return checkAcceptableObject(left._return_, right._return_, scope)
    return false

  if left?.array?
    if right.array instanceof Array
      results = (checkAcceptableObject left.array, r, scope for r in right.array)
      return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))
    else
      return checkAcceptableObject left.array, right.array, scope

  else if right?.array?
    if left is 'Array' or left is 'Any' or left is undefined
      return false
    else
      return "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

  else if ((typeof left) is 'string') and ((typeof right) is 'string')
    cur = scope.getTypeInScope(left)
    extended_list = [left]
    while cur._extends_
      extended_list.push cur._extends_
      cur = scope.getTypeInScope cur._extends_
    # TODO: handle object
    # now only allow primitive
    if (left is 'Any') or (right is 'Any') or right in extended_list
      return false
    else
      return "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

  else if ((typeof left) is 'object') and ((typeof right) is 'object')
    results =
      for key, lval of left
        if right[key] is undefined and lval? and not (key in ['_return_', 'type', 'possibilities']) # TODO avoid system values
          "'#{key}' is not defined on right"
        else
          checkAcceptableObject(lval, right[key], scope)
    return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))
  else if (left is undefined) or (right is undefined)
    return false
  else
    return "object deep equal mismatch #{JSON.stringify left}, #{JSON.stringify right}"

# Initialize primitive types
# Number, Boolean, Object, Array, Any
initializeGlobalTypes = (node) ->
  # Primitive
  node.addTypeObject 'String', new TypeSymbol {dataType: 'String'}
  node.addTypeObject 'Number', new TypeSymbol {dataType: 'Number', _extends_: 'Float'}
  node.addTypeObject 'Int', new TypeSymbol {dataType: 'Int'}
  node.addTypeObject 'Float', new TypeSymbol {dataType: 'Float', _extends_: 'Int'}
  node.addTypeObject 'Boolean', new TypeSymbol {dataType: 'Boolean'}
  node.addTypeObject 'Object', new TypeSymbol {dataType: 'Object'}
  node.addTypeObject 'Array', new TypeSymbol {dataType: 'Array'}
  node.addTypeObject 'Undefined', new TypeSymbol {dataType: 'Undefined'}
  node.addTypeObject 'Any', new TypeSymbol {dataType: 'Any'}

# Known vars in scope
class VarSymbol
  # dataType :: String
  # implicit :: Bolean
  constructor: ({@dataType, @implicit}) ->

# Known types in scope
class TypeSymbol
  # dataType :: String or Object
  # instanceof :: (Any) -> Boolean
  constructor: ({@dataType, @instanceof, @_templates_, @_extends_}) ->

# Var and dataType scope as node
class Scope
  # constructor :: (Scope) -> Scope
  constructor: (@parent = null) ->
    @parent?.nodes.push this

    @name = ''
    @nodes  = [] #=> Scope[]

    # Scope vars
    @_vars  = {} #=> String -> Type

    # Scope dataTypes
    @_types = {} #=> String -> Type

    # This scope
    @_this  = {}

    @_returnables = [] #=> Type[]

  addReturnable: (symbol, dataType) ->
    @_returnables.push dataType

  getReturnables: -> @_returnables

  # addType :: String * Object * Object -> Type
  addType: (symbol, dataType, _templates_) ->
    @_types[symbol] = new TypeSymbol {dataType, _templates_}

  addTypeObject: (symbol, type_object) ->
    @_types[symbol] = type_object

  getType: (symbol) ->
    @_types[symbol]

  getTypeInScope: (symbol) ->
    @getType(symbol) or @parent?.getTypeInScope(symbol) or undefined

  addThis: (symbol, dataType, implicit = true) ->
    # TODO: Refactor with addVar
    if dataType?._base_?
      T = @getType(dataType._base_)
      return undefined unless T
      obj = clone T.dataType
      if T._templates_
        # TODO: length match
        rewrite_to = dataType._templates_
        replacer = {}
        for t, n in T._templates_
          replacer[t] = rewrite_to[n]
        rewrite obj, replacer

      @_this[symbol] = new VarSymbol {dataType:obj, implicit}
    else
      @_this[symbol] = new VarSymbol {dataType, implicit}

  getThis: (symbol) ->
    @_this[symbol]

  addVar: (symbol, dataType, implicit = true) ->
    # TODO: Refactor
    if dataType?._base_?
      T = @getType(dataType._base_)
      return undefined unless T
      obj = clone T.dataType
      if T._templates_
        # TODO: length match
        rewrite_to = dataType._templates_
        replacer = {}
        for t, n in T._templates_
          replacer[t] = rewrite_to[n]
        rewrite obj, replacer

      @_vars[symbol] = new VarSymbol {dataType:obj, implicit}
    else
      @_vars[symbol] = new VarSymbol {dataType, implicit}

  getVar: (symbol) ->
    @_vars[symbol]

  getVarInScope: (symbol) ->
    @getVar(symbol) or @parent?.getVarInScope(symbol) or undefined

  isImplicitVar: (symbol) -> !! @_vars[symbol]?.implicit

  isImplicitVarInScope: (symbol) ->
    @isImplicitVar(symbol) or @parent?.isImplicitVarInScope(symbol) or undefined

  # Extend symbol to dataType object
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
        dataType = Type?.dataType
        switch typeof dataType
          when 'object'
            return @extendTypeLiteral(dataType)
          when 'string'
            return dataType

  # check object literal with extended object
  checkAcceptableObject: (left, right) ->
    l = @extendTypeLiteral(left)
    r = @extendTypeLiteral(right)
    return checkAcceptableObject(l, r, @)

class ClassScope extends Scope
class FunctionScope extends Scope

module.exports = {
  checkAcceptableObject,
  initializeGlobalTypes,
  VarSymbol, TypeSymbol, Scope, ClassScope, FunctionScope
  ArrayType, ObjectType, Type, Possibilites
}