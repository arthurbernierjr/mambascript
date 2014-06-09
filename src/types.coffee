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
    @_this  = []

    # Module scope
    @_modules  = {}

    @_returnables = [] #=> Type[]

  addReturnable: (typeRef) ->
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

  addType: (node) ->
    @types.push node
    return node

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
    node.typeAnnotation.identifier = node.identifier
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
    switch node?.nodeType
      when 'members'
        node
      when 'primitiveIdentifier'
        node
      when 'identifier'
        @getTypeInScope(node.identifier.typeRef)
      when 'functionType'
        ImplicitAnyAnnotation
      else
        ImplicitAnyAnnotation

  # addThis :: Type * TypeArgument[] -> ()
  addThis: (type, args = []) ->
    # TODO: Refactor with addThis
    @_this.push type

  getThis: (propName) ->
    _.find @_this, (v) -> v.identifier.typeRef is propName

  getThisByNode: (node) ->
    typeName = node.identifier.typeRef
    @getThis(typeName)?.typeAnnotation

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
  getConstructorType: ->
    (_.find @_this, (v) -> v.identifier.typeRef is '_constructor_')?.typeAnnotation

class FunctionScope extends Scope

primitives =
  AnyType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Any'

  StringType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'String'

  BooleanType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Boolean'

  IntType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Int'

  FloatType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Float'
    heritages:
      extend:
        nodeType: 'identifier'
        identifier:
          typeRef: 'Int'

  NumberType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Number'
    heritages:
      extend:
        nodeType: 'identifier'
        identifier:
          typeRef: 'Float'

  NullType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Null'

  UndefinedType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Undefined'

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