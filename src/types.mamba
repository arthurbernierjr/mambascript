{debug} = require './helpers'
{clone, rewrite} = require './type-helpers'
_ = require 'lodash'

ImplicitAny =
  implicit: true
  isPrimitive: true
  nodeType: 'primitiveIdentifier'
  identifier:
    typeRef: 'Any'

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

  VoidType:
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Void'

initializeGlobalTypes = (node) ->
  node.addPrimitiveType primitives.AnyType
  node.addPrimitiveType primitives.StringType
  node.addPrimitiveType primitives.IntType
  node.addPrimitiveType primitives.FloatType
  node.addPrimitiveType primitives.NumberType
  node.addPrimitiveType primitives.BooleanType
  node.addPrimitiveType primitives.NullType
  node.addPrimitiveType primitives.UndefinedType
  node.addPrimitiveType primitives.VoidType

module.exports = {
  initializeGlobalTypes, primitives, ImplicitAny
}
