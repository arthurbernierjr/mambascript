# struct Node
#   nodeType :: String
#
# struct MemberAccess extends Node
#   left  :: TypeRef
#   right :: TypeRef
#
# type TypeRef = String | MemberAccess
#
# type Struct exnteds Node
#   identifier: TypeIdentifier
#   members: PropertyTypeAnnotaiton
#
# struct TypeIdentifier
#   typeRef :: TypeRef
#   isArray :: Boolean?
#   typeArguments :: TypeRef[]?
#
# struct TypeAnnotation extends Node
#   implicit :: Boolean?
#
# struct IdentifierTypeAnnotation implements TypeAnnotation
#   identifier :: TypeIdentifier
#
# struct PropertyTypeAnnotation implements TypeAnnotation
#   properties :: TypeIdentifier[]

{debug} = require './helpers'
reporter = require './reporter'
CS = require './nodes'
_ = require 'lodash'

ImplicitAnyAnnotation =
  implicit: true
  isPrimitive: true
  nodeType: 'primitiveIdentifier'
  identifier:
    typeRef: 'Any'

{
  initializeGlobalTypes,
  Scope,
  ClassScope,
  FunctionScope
} = require './types'

# correctExtends :: Scope * TypeAnnotation -> TypeAnnotation[]
correctExtends = (scope, annotation) ->
  extendList = [annotation]
  cur = annotation
  while cur?.heritages?.extend?
    next = scope.getTypeByIdentifier cur.heritages.extend
    if next
      extendList.push next
      cur = next
    else
      break
  extendList

isAcceptableExtends = (scope, left, right) ->
  _.any correctExtends(scope, left).map (le) ->
    le.identifier.typeRef is right.identifier.typeRef

# isAcceptablePrimitiveSymbol :: Scope * TypeAnnotation * TypeAnnotation -> Boolean
isAcceptablePrimitiveSymbol = (scope, left, right) ->
  if left.nodeType isnt 'primitiveIdentifier'
    throw 'left is not primitive'

  return true if left.identifier.typeRef is 'Any'
  # type check
  # if left.identifier.typeRef isnt right?.identifier?.typeRef
  unless isAcceptableExtends(scope, left, right)
    return false
  # array check
  if !!left.identifier.isArray
    if right?.identifier?.isArray?
      return false if !!right?.identifier?.isArray isnt true
    else
      return false
  else
    return false if !!right?.identifier?.isArray isnt false
  # TODO: typeArgument check
  true

# isAcceptableStruct :: Scope * TypeAnnotation * TypeAnnotation -> Boolean
isAcceptableStruct = (scope, left, right) ->
  _.all left.properties.map (lprop, n) =>
    rprop = _.find right.properties, (rp) ->
      rp.identifier?.typeRef is lprop.identifier?.typeRef
    unless rprop? then return false
    return isAcceptable scope, lprop.typeAnnotation, rprop.typeAnnotation

# isAcceptableFunction :: Scope * TypeAnnotation * TypeAnnotation -> Boolean
isAcceptableFunctionType = (scope, left, right) ->
  left.returnType ?= ImplicitAnyAnnotation
  right.returnType ?= ImplicitAnyAnnotation
  unless isAcceptable(scope, left.returnType, right.returnType)
    return false

  return _.all (for leftArg, n in left.arguments
    leftArg = leftArg ? ImplicitAnyAnnotation
    rightArg = right.arguments[n] ? ImplicitAnyAnnotation
    isAcceptable scope, leftArg, rightArg
  )

# isAcceptable :: Types.Scope * TypeAnnotation * TypeAnnotaion -> Boolean
isAcceptable = (scope, left, right) ->
  # FIXME
  return true if not left? or not right?

  [leftAnnotation, rightAnnotation] = [left, right].map (node) =>
    if node.nodeType is 'identifier'
      scope.getTypeByIdentifier(node)
    else if node.nodeType is 'primitiveIdentifier'
      node
    else if node.nodeType is 'members'
      node
    else if node.nodeType is 'functionType'
      node
    else
      throw node?.nodeType + " is not registered nodeType"

  # Grasp if left is any
  return true if not leftAnnotation? or not rightAnnotation? # FIXME

  if leftAnnotation.nodeType is 'primitiveIdentifier'
    if leftAnnotation.identifier.typeRef is 'Any'
      return true

  if leftAnnotation.nodeType is rightAnnotation.nodeType is 'members'
    return isAcceptableStruct scope, leftAnnotation, rightAnnotation
  if leftAnnotation.nodeType is rightAnnotation.nodeType is 'primitiveIdentifier'
    return isAcceptablePrimitiveSymbol scope, leftAnnotation, rightAnnotation
  if leftAnnotation.nodeType is rightAnnotation.nodeType is 'functionType'
    return isAcceptableFunctionType scope, leftAnnotation, rightAnnotation

# isAcceptable :: Types.Scope * Type * Type -> ()
checkType = (scope, node, left, right) ->
  typeErrorText = (left, right) ->
    util = require 'util'
    "TypeError: \n#{util.inspect left, false, null} \n to \n #{util.inspect right, false, null}"

  ret = isAcceptable scope, left.typeAnnotation, right.typeAnnotation
  if ret
    return true
  else
    err = typeErrorText left.typeAnnotation, right.typeAnnotation
    if left.implicit and right.implicit
      reporter.add_warning node, err
    else
      reporter.add_error node, err
    return false

module.exports = {
  checkType, isAcceptable
}
