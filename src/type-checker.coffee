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
#   identifier :: TypeIdentifier
#   members  :: PropertyTypeAnnotaiton
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
#   nullable :: Boolean
#   isArray :: Boolean

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
isAcceptablePrimitiveSymbol = (scope, left, right, nullable = false, isArray = false) ->
  if left.nodeType isnt 'primitiveIdentifier'
    throw 'left is not primitive'

  return true if left.identifier.typeRef is 'Any'
  unless isAcceptableExtends(scope, left, right)
    # debug 'isAcceptableExtends', left, right
    if nullable and right.identifier.typeRef in ['Null', 'Undefined'] # nullable
      return true
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
    unless rprop?
      return lprop.typeAnnotation?.identifier?.nullable
    return isAcceptable scope, lprop.typeAnnotation, rprop.typeAnnotation

# isAcceptableFunction :: Scope * TypeAnnotation * TypeAnnotation -> Boolean
isAcceptableFunctionType = (scope, left, right) ->
  left.returnType ?= ImplicitAnyAnnotation
  right.returnType ?= ImplicitAnyAnnotation
  unless isAcceptable(scope, left.returnType, right.returnType)
    # console.error 'fail at return type check'
    return false
  return _.all left.arguments.map (leftArg, n) ->
    leftArg = leftArg ? ImplicitAnyAnnotation
    rightArg = right.arguments[n] ? ImplicitAnyAnnotation
    ret = isAcceptable scope, leftArg, rightArg
    ret

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

  if left.identifier and right.identifier and rightAnnotation
    # leftNullable = left.identifier.nullable
    leftWholeNullable = left.identifier.wholeNullable
    if leftWholeNullable and rightAnnotation.identifier.typeRef in ['Undefined', 'Null']
      return true

    isSameArrayFlag = !!left.identifier.isArray is !!right.identifier.isArray or !!left.identifier.isArray is !!rightAnnotation.isArray
    unless isSameArrayFlag
      # console.error 'fail at isSameArrayFlag'
      return false

  # debug 'isAcceptableStruct', leftAnnotation, rightAnnotation
  # if leftAnnotation.nodeType is rightAnnotation.nodeType is 'members'
  if leftAnnotation.nodeType is 'members'
    if rightAnnotation.nodeType is 'members'
      ret = isAcceptableStruct scope, leftAnnotation, rightAnnotation
      return ret
    else
      return false
  if leftAnnotation.nodeType is 'primitiveIdentifier'
    if rightAnnotation.nodeType is 'primitiveIdentifier'
      leftNullable = !! left.identifier.nullable
      rightNullable = !! right.identifier.nullable
      if not leftNullable and rightNullable
        # console.error 'fail at nullable check'
        return false
      return isAcceptablePrimitiveSymbol scope, leftAnnotation, rightAnnotation, leftNullable
    else
      return false

  if leftAnnotation.nodeType is 'functionType'
    if rightAnnotation.nodeType is 'functionType'
      return isAcceptableFunctionType scope, leftAnnotation, rightAnnotation
    else if leftAnnotation?.returnType?.implicit
      return true
    else
      return false
  true # FIXME: pass all unknow pattern

typeErrorText = (left, right) ->
  util = require 'util'
  "TypeError: \n#{util.inspect left, false, null} \n to \n #{util.inspect right, false, null}"

# checkType :: Scope * Node * Type * Type -> ()
checkType = (scope, node, left, right) ->
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

# checkTypeAnnotation :: Scope * Node * Type * Type -> ()
checkTypeAnnotation = (scope, node, left, right) ->
  ret = isAcceptable scope, left, right
  if ret
    return true
  else
    err = typeErrorText left, right
    if left.implicit and right.implicit
      reporter.add_warning node, err
    else
      reporter.add_error node, err
    return false

module.exports = {
  checkType, checkTypeAnnotation, isAcceptable
}
