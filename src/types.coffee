{debug} = require './helpers'
{clone, rewrite} = require './type-helpers'
_ = require 'lodash'

ImplicitAnyAnnotation =
  implicit: true
  isPrimitive: true
  nodeType: 'primitiveIdentifier'
  identifier:
    typeRef: 'Any'


# Var and typeRef scope as node
class Scope
  # constructor :: (Scope) -> Scope
  constructor: (@parent = null) ->
    @parent?.nodes.push this

    @name = ''
    @nodes  = [] #=> Scope[]

    # Scope vars
    @vars  = [] #=> Type[]

    # Scope typeRefs
    @types = [] #=> Type[]

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
    @types.push node
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
    mod.types.push node

  # getTypeByString :: String -> Type
  getTypeByString: (typeName) ->
    ret = _.find @types, (i) -> i.identifier.typeRef is typeName
    return null unless ret?
    return (if ret.nodeType is 'struct' then ret.members else ret)

  # getTypeByMemberAccess :: TypeRef -> Type
  getTypeByMemberAccess: (typeRef) ->
    ns = typeRef.left
    property = typeRef.right

    mod = @resolveNamespace ns
    ret = _.find mod.types, (node) =>
      node.identifier.typeRef is property
    return (if ret.nodeType is 'struct' then ret.members else ret)

  # getType :: TypeRef -> Type
  getType: (typeRef) ->
    # console.error 'checkPoint!3', typeRef
    if _.isString(typeRef)
      @getTypeByString(typeRef)
    else if typeRef?.nodeType is 'MemberAccess'
      @getTypeByMemberAccess(typeRef)

  # getTypeInScope :: TypeRef -> Type
  getTypeInScope: (typeRef) ->
    # console.error 'checkPoint!2'
    @getType(typeRef) or @parent?.getTypeInScope(typeRef) or null

  # getTypoIdentifier :: TypoAnnotation -> TypeAnnotation
  getTypeByIdentifier: (node) ->
    # if node?.nodeType noti n ['identifier', 'primitiveIdentifier', 'functionType', 'members']
    #   throw node?.nodeType + ' is not gettable node'
    switch node?.nodeType
      when 'members'
        node
      when 'primitiveIdentifier'
        node
      when 'identifier'
        @getTypeInScope(node.identifier.typeRef)
      when 'functionType'
        null
        ImplicitAnyAnnotation
      else
        ImplicitAnyAnnotation

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

      @_this[symbol] = {typeRef:obj}
    else
      @_this[symbol] = {typeRef}

  getThis: (symbol) ->
    @_this[symbol]

  # addVar :: Type * TypeArgument[] -> ()
  addVar: (type, args = []) ->
    # TODO: Apply typeArgument
    @vars.push type

  # getVar :: String -> ()
  getVar: (typeName) ->
    _.find @vars, (v) -> v.identifier.typeRef is typeName

  getVarInScope: (typeName) ->
    @getVar(typeName) or @parent?.getVarInScope(typeName) or undefined

  getTypeByVarNode: (node) ->
    typeName = node.identifier.typeRef
    @getVarInScope(typeName)?.typeAnnotation

  getTypeByVarName: (varName) ->
    @getVarInScope(varName)?.typeAnnotation

  checkAcceptableObject: (left, right) -> false

class ClassScope extends Scope
class FunctionScope extends Scope

primitives =
  AnyType:
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Any'
      isPrimitive: true

  StringType:
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'String'
      isPrimitive: true

  BooleanType:
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Boolean'
      isPrimitive: true

  IntType:
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Int'
      isPrimitive: true

  FloatType:
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Float'
      isPrimitive: true
    heritages:
      extend:
        identifier:
          typeRef: 'Int'
          isPrimitive: true

  NumberType:
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Number'
      isPrimitive: true
    heritages:
      extend:
        identifier:
          typeRef: 'Float'
          isPrimitive: true

  NullType:
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Null'
      isPrimitive: true

  UndefinedType:
    nodeType: 'primitiveIdentifier'
    identifier:
      typeRef: 'Updefined'
      isPrimitive: true

initializeGlobalTypes = (node) ->
  node.addPrimitiveType primitives.AnyType
  node.addPrimitiveType primitives.StringType
  node.addPrimitiveType primitives.IntType
  node.addPrimitiveType primitives.FloatType
  node.addPrimitiveType primitives.NumberType
  node.addPrimitiveType primitives.BooleanType
  node.addPrimitiveType primitives.NullType
  node.addPrimitiveType primitives.UndefinedType

module.exports = {
  initializeGlobalTypes, primitives
  Scope, ClassScope, FunctionScope
}