_ = require 'lodash'

rewriteType = (scope, node, from, to) ->
  if node.nodeType is 'identifier'
    # TODO: type arguments
    if node.identifier?.typeArguments?.length
      typeArgs =
        for i, n in node.identifier.typeArguments
          resolved = resolveType(scope, i)
          resolved.typeAnnotation
      ann = scope.getTypeByIdentifier from.typeAnnotation # Check later
      if ann
        extendType scope, ann, typeArgs
    if node.identifier?.typeRef is from.identifier.typeRef
      node.identifier.typeRef = to.identifier.typeRef

  else if node.nodeType is 'members'
    for prop in node.properties
      switch prop.typeAnnotation.nodeType
        when 'functionType'
          rewriteType scope, prop.typeAnnotation.returnType, from, to
          for arg in prop.typeAnnotation.arguments
            rewriteType scope, arg, from, to
          # debug 'functionType rewriten', prop.typeAnnotation
        when 'identifier'
          if prop.typeAnnotation?.identifier?.typeArguments?.length
            typeArgs =
              for i, n in prop.typeAnnotation.identifier.typeArguments
                resolved = resolveType(scope, i)
                resolved.typeAnnotation
            ann = scope.getTypeByIdentifier prop.typeAnnotation
            if ann
              extendType scope, ann, typeArgs

          if prop.typeAnnotation.identifier?.typeRef is from.identifier.typeRef
            prop.typeAnnotation.identifier.typeRef = to.identifier.typeRef
        when 'members'
          rewriteType scope, prop.typeAnnotation, from, to

extendIdentifierType = (scope, node) ->
  ann = scope.getTypeInScope(node.identifier.typeRef)
  if ann.nodeType is 'identifier'
    unless ann.typeAnnotation?
      throw new Error 'identifier with annotation required'
    from = node
    to = ann.typeAnnotation
    rewriteType scope, node, from, to

extendFunctionType = (scope, node) ->
  extendIdentifierType scope, node.returnType
  for arg in node.arguments
    if arg.nodeType is 'identifier'
      extendIdentifierType scope, arg
    else if arg.nodeType is 'functionType'
      extendFunctionType scope, arg
  node

extendMembers = (scope, node, givenArgs) ->
  typeScope = new Scope scope
  if node.identifier?.typeArguments?.length
    for arg, n in node.identifier.typeArguments
      givenArg = givenArgs[n]

      if givenArg?.identifier?.typeArguments?.length
        typeArgs = givenArg.identifier.typeArguments
        if ann = scope.getTypeByIdentifier givenArg
          extendType scope, ann, typeArgs

      typeScope.addType
        nodeType: 'identifier'
        identifier:
          typeRef: arg.identifier.typeRef
        typeAnnotation:
          nodeType: 'identifier'
          identifier:
            typeRef: givenArg.identifier.typeRef

  for arg, n in node.identifier.typeArguments
    givenArg = givenArgs[n]
    rewriteType typeScope, node, arg, givenArg

extendType = (scope, node, givenArgs) ->
  if node.nodeType is 'members'
    extendMembers scope, node, givenArgs
  else if node.nodeType is 'functionType'
    extendFunctionType scope, node
  node

resolveType = (scope, node) ->
  if node.nodeType is 'identifier'
    ret = scope.getTypeByIdentifier(node)
    if node.identifier?.typeArguments?.length
      ret = extendType scope, _.cloneDeep(ret), node.identifier.typeArguments
    unless ret
      if node.nodeType is 'identifier' # TODO: consider nested type arguments
        return node
      throw 'Type: '+ util.inspect(node.identifier.typeRef) + ' is not defined'
    ret
  else if node.nodeType is 'primitiveIdentifier'
    node
  else if node.nodeType is 'members'
    node
  else if node.nodeType is 'functionType'
    node
  else
    throw node?.nodeType + " is not registered nodeType"

module.exports = {
  resolveType, extendType
}
