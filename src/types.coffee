pj = try require 'prettyjson'
render = (obj) -> pj?.render obj
{debug} = require './helpers'
reporter = require './reporter'
{clone, rewrite} = require './type-helpers'
reporter = require './reporter'
{find} = require './functional-helpers'
_ = require 'lodash'

typeErrorText = (left, right) ->
  "TypeError: #{JSON.stringify left} expect to #{JSON.stringify right}"

class Type
  constructor: ->

# ObjectType :: T -> Object
class ObjectType extends Type
  # :: String -> ()
  constructor:(@typeRef) ->

# ArrayType :: {array :: T} = array: T
class ArrayType extends Type
  constructor:(typeRef) ->
    @array = typeRef

# possibilities :: Type[] = []
class Possibilites extends Array
  constructor: (arr = []) ->
    @push i for i in arr

checkAcceptableObject = (left, right, scope) => false
#   # TODO: fix
#   if left?._base_? and left._templates_? then left = left._base_

#   # possibilites :: Type[]
#   if right?.possibilities?
#     results = (checkAcceptableObject left, r, scope for r in right.possibilities)
#     return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))

#   # Any
#   if left is 'Any'
#     return false

#   if left?.arguments
#     return if left is undefined or left is 'Any'
#     left.arguments ?= []
#     results = (checkAcceptableObject(l_arg, right.arguments[i], scope) for l_arg, i in left.arguments)
#     return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))

#     # check return typeRef
#     # TODO: Now I will not infer function return typeRef
#     if right.returnType isnt 'Any'
#       return checkAcceptableObject(left.returnType, right.returnType, scope)
#     return false

#   if left?.array?
#     if right.array instanceof Array
#       results = (checkAcceptableObject left.array, r, scope for r in right.array)
#       return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))
#     else
#       return checkAcceptableObject left.array, right.array, scope

#   else if right?.array?
#     if left is 'Array' or left is 'Any' or left is undefined
#       return false
#     else
#       return typeErrorText left, right

#   else if ((typeof left) is 'string') and ((typeof right) is 'string')
#     cur = scope.getTypeInScope(left)
#     extended_list = [left]
#     while cur._extends_
#       extended_list.push cur._extends_
#       cur = scope.getTypeInScope cur._extends_
#     # TODO: handle object
#     # now only allow primitive
#     if (left is 'Any') or (right is 'Any') or right in extended_list
#       return false
#     else
#       return typeErrorText left, right

#   else if ((typeof left) is 'object') and ((typeof right) is 'object')
#     results =
#       for key, lval of left
#         if right[key] is undefined and lval? and not (key in ['returnType', 'type', 'possibilities']) # TODO avoid system values
#           "'#{key}' is not defined on right"
#         else
#           checkAcceptableObject(lval, right[key], scope)
#     return (if results.every((i)-> not i) then false else results.filter((i)-> i).join('\n'))
#   else if (left is undefined) or (right is undefined)
#     return false
#   else
#     return typeErrorText left, right

# Initialize primitive types
# Number, Boolean, Object, Array, Any
initializeGlobalTypes = (node) ->
  AnyType =
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Any'
      isPrimitive: true

  StringType =
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'String'
      isPrimitive: true

  IntType =
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Int'
      isPrimitive: true

  FloatType =
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Float'
      isPrimitive: true
    heritages:
      extend:
        identifier:
          typeRef: 'Int'
          isPrimitive: true

  NumberType =
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Number'
      isPrimitive: true
    heritages:
      extend:
        identifier:
          typeRef: 'Float'
          isPrimitive: true

  node.addPrimitiveType AnyType
  node.addPrimitiveType StringType
  node.addPrimitiveType IntType
  node.addPrimitiveType FloatType
  node.addPrimitiveType NumberType

  # node.addTypeObject 'Int', new TypeSymbol
  #   typeRef: 'Int'
  #   typeArguments: []
  #   isArray: false
  #   isPrimitive: true

  # node.addTypeObject 'Boolean', new TypeSymbol
  #   typeRef: 'Boolean'
  #   typeArguments: []
  #   isArray: false
  #   isPrimitive: true
  # node.addTypeObject 'Object', new TypeSymbol
  #   typeRef: 'Object'
  #   typeArguments: []
  #   isArray: false

  # node.addTypeObject 'Array', new TypeSymbol
  #   typeRef: 'Array'
  #   typeArguments: []
  #   isArray: false

  # node.addTypeObject 'Undefined', new TypeSymbol
  #   typeRef: 'Undefined'
  #   typeArguments: []
  #   isArray: false
  #   isPrimitive: true

  # node.addTypeObject 'Any', new TypeSymbol
  #   typeRef: 'Any'
  #   typeArguments: []
  #   isArray: false

# Known vars in scope
class VarSymbol
  # typeRef :: String
  # explicit :: Boolean
  constructor: ({@typeRef, @explicit}) ->
    @explicit ?= false

# Known types in scope
class TypeSymbol
  # typeRef :: String or Object
  # instanceof :: (Any) -> Boolean
  constructor: ({@typeRef, @typeArguments,@isArray, @heritages, @isPrimitive}) ->

# Var and typeRef scope as node
class Scope
  # constructor :: (Scope) -> Scope
  constructor: (@parent = null) ->
    @parent?.nodes.push this

    @name = ''
    @nodes  = [] #=> Scope[]

    # Scope vars
    @_vars  = {} #=> String -> Type

    # Scope typeRefs
    @_types = [] #=> String -> Type

    # This scope
    @_this  = {}

    # Module scope
    @_modules  = {}

    @_returnables = [] #=> Type[]

  addReturnable: (symbol, typeRef) ->
    @_returnables.push typeRef

  getReturnables: -> @_returnables

  getRoot: ->
    return @ unless @parent
    root = @parent
    while true
      if root.parent
        root = root.parent
      else break
    root

  # addType :: Any * Object * Object -> Type
  addModule: (name) ->
    scope = new Scope this
    scope.name = name
    return @_modules[name] = scope

  getModule: (name) -> @_modules[name]

  getModuleInScope: (name) ->
    @getModule(name) or @parent?.getModuleInScope(name) or undefined

  # addType :: StructNode -> ()

  # resolveNamespace :: TypeRef -> Module
  resolveNamespace: (ref, autoCreate = false) ->
    ns = []
    cur = ref
    while true
      if (typeof cur) is 'string'
        ns.unshift cur
        break
      else
        ns.unshift cur.right
        cur = cur.left
    # find or initialize module
    cur = @
    for moduleName in ns
      mod = cur.getModuleInScope(moduleName)
      unless mod
        if autoCreate
          mod = cur.addModule(moduleName)
        else
          return null
      cur = mod
    cur

  addPrimitiveType: (node) ->
    if node.nodeType isnt 'primitiveIdentifier'
      throw 'nodeType isnt primitiveIdentifier'
    @_types.push node
    return node

  addStructType: (structNode) ->
    if structNode.nodeType isnt 'struct'
      throw 'node isnt structNode'

    ref = structNode.identifier.identifier.typeRef
    if _.isString ref
      mod = @
      propName = ref
    else
      mod = @resolveNamespace ref.left, true
      propName = ref.right

    node = _.clone structNode
    node.identifier.typeRef = propName
    delete node.data
    delete node.line
    delete node.offset
    delete node.column
    delete node.raw
    node = {
      nodeType: 'struct'
      identifier:
        typeRef: propName
      members: node.typeAnnotation
    }
    mod._types.push node

  # getTypeByString :: String -> Type
  getTypeByString: (typeName) ->
    ret = find @_types, (i) -> i.identifier.typeRef is typeName
    return (if ret.nodeType is 'struct' then ret.members else ret)

  # getTypeByMemberAccess :: TypeRef -> Type
  getTypeByMemberAccess: (typeRef) ->
    ns = typeRef.left
    property = typeRef.right

    mod = @resolveNamespace ns
    ret = _.find mod._types, (node) =>
      node.identifier.typeRef is property
    return (if ret.nodeType is 'struct' then ret.members else ret)

  # getType :: TypeRef -> Type
  getType: (typeRef) ->
    # debug 'typeRef', typeRef
    if _.isString(typeRef)
      @getTypeByString(typeRef)
    else if typeRef?.nodeType is 'MemberAccess'
      @getTypeByMemberAccess(typeRef)

  # getTypeInScope :: TypeRef -> Type
  getTypeInScope: (typeRef) ->
    @getType(typeRef) or @parent?.getTypeInScope(typeRef) or null

  # getTypoIdentifier :: TypoAnnotation -> TypeAnnotation
  getTypeByIdentifier: (node) ->
    if node.nodeType isnt 'identifier'
      throw 'node is not identifier node'
    switch node.nodeType
      when 'members'
        return node
      when 'identifier'
        @getTypeInScope(node.identifier.typeRef)

  addThis: (symbol, typeRef) ->
    # TODO: Refactor with addVar
    if typeRef?._base_?
      T = @getType(typeRef._base_)
      return undefined unless T
      obj = clone T.typeRef
      if T._templates_
        # TODO: length match
        rewrite_to = typeRef._templates_
        replacer = {}
        for t, n in T._templates_
          replacer[t] = rewrite_to[n]
        rewrite obj, replacer

      @_this[symbol] = new VarSymbol {typeRef:obj}
    else
      @_this[symbol] = new VarSymbol {typeRef}

  getThis: (symbol) ->
    @_this[symbol]

  addVar: (symbol, typeRef, explicit) ->
    # TODO: Refactor
    if typeRef?._base_?
      T = @getType(typeRef._base_)
      return undefined unless T
      obj = clone T.typeRef
      if T._templates_
        # TODO: length match
        rewrite_to = typeRef._templates_
        replacer = {}
        for t, n in T._templates_
          replacer[t] = rewrite_to[n]
        rewrite obj, replacer

      @_vars[symbol] = new VarSymbol {typeRef:obj, explicit}
    else
      @_vars[symbol] = new VarSymbol {typeRef, explicit}

  getVar: (symbol) ->
    @_vars[symbol]

  getVarInScope: (symbol) ->
    @getVar(symbol) or @parent?.getVarInScope(symbol) or undefined

  isImplicitVarInScope: (symbol) ->
    @isImplicitVar(symbol) or @parent?.isImplicitVarInScope(symbol) or undefined

  # Extend symbol to typeRef object
  # ex. {name : String, p : Point} => {name : String, p : { x: Number, y: Number}}
  extendTypeLiteral: (node) =>
    if (typeof node) is 'string' or node?.nodeType is 'MemberAccess'
      Type = @getTypeInScope(node)
      typeRef = Type?.typeRef
      switch typeof typeRef
        when 'object'
          return @extendTypeLiteral(typeRef)
        when 'string'
          return typeRef

    else if (typeof node) is 'object'
      # array
      if node instanceof Array
        return (@extendTypeLiteral(i) for i in node)
      # object
      else
        ret = {}
        for key, val of node
          ret[key] = @extendTypeLiteral(val)
        return ret

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