_ = require 'lodash'
{ImplicitAny} = require './types'

# Var and typeRef scope as node
class Scope
  # constructor :: (Scope) -> Scope
  constructor: (@parent = null) ->
    @id = _.uniqueId()

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

  getReturnables: -> _.cloneDeep @_returnables

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

    ref = structNode.name.identifier.typeRef
    if _.isString ref
      mod = @
      propName = ref
    else
      mod = @resolveNamespace ref.left, true
      propName = ref.right

    ann = _.clone structNode.expr
    ann.identifier = structNode.name.identifier
    ann.identifier.typeRef = propName
    mod.types.push ann

  # getTypeByString :: String -> Type
  getTypeByString: (typeName) ->
    _.find @types, (i, n) ->
      i.identifier.typeRef is typeName

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
    if _.isString(typeRef)
      @getTypeByString(typeRef)
    else if typeRef?.nodeType is 'MemberAccess'
      @getTypeByMemberAccess(typeRef)

  # getTypeInScope :: TypeRef -> Type
  getTypeInScope: (typeRef) ->
    ret = @getType(typeRef) or @parent?.getTypeInScope(typeRef) or null
    ret

  # getTypoIdentifier :: TypoAnnotation -> TypeAnnotation
  getTypeByNode: (node) ->
    switch node?.nodeType
      when 'members'
        node
      when 'primitiveIdentifier'
        node
      when 'identifier'
        @getTypeInScope(node.identifier.typeRef)
      when 'functionType'
        ImplicitAny
      else
        ImplicitAny

  # getTypoIdentifier :: TypoAnnotation -> TypeAnnotation
  getTypeByIdentifier: (identifier) ->
    @getTypeInScope(identifier.typeRef)

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

  getHighestCommonType: (list) ->
    [head, tail...] = list
    _.cloneDeep _.reduce tail, ((a, b) =>
      @compareAsParent a, b
    ), head

  compareAsParent: (a, b) ->
    {isAcceptable} = require './type-checker'

    if a?.identifier?.typeRef in ['Undefined', 'Null']
      b = _.cloneDeep(b)
      if b?.identifier?
        b.identifier.nullable = true
      return b

    if b?.identifier?.typeRef in ['Undefined', 'Null']
      a = _.cloneDeep(a)
      if a?.identifier?
        a.identifier.nullable = true
      return a

    retA = isAcceptable @, a, b
    retB = isAcceptable @, b, a
    if retA and retB then b
    else if retA then a
    else if retB then b
    else ImplicitAny

class ClassScope extends Scope
  getConstructorType: ->
    (_.find @_this, (v) -> v.identifier.typeRef is '_constructor_')?.typeAnnotation

class FunctionScope extends Scope

module.exports = {
  Scope, ClassScope, FunctionScope
}