{debug} = require './helpers'
reporter = require './reporter'
CS = require './nodes'
_ = require 'lodash'

{isAcceptable, checkType, checkTypeAnnotation} = require './type-checker'

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

compareAsParent = (scope, a, b) ->
  retA = isAcceptable scope, a, b
  retB = isAcceptable scope, b, a
  if retA and retB then b
  else if retA then a
  else if retB then b
  else ImplicitAnyAnnotation

# CS_AST -> Scope
checkNodes = (cs_ast) ->
  # dirty hack
  g = window ? global
  return unless cs_ast.body?.statements?

  if g._root_
    root = g._root_
  else
    g._root_ = root = new Scope
    root.name = 'root'
    # for i in ['global', 'exports', 'module']
    #   root.addVar i, 'Any', true
    initializeGlobalTypes(root)

  # debug 'root', cs_ast
  walk cs_ast, root
  return root

walkStruct = (node, scope) ->
  # debug 'node', node
  scope.addStructType node

walkVardef = (node, scope) ->
  # avoid 'constructor' because it's property has special action on EcmaScript
  symbol = node.name.identifier.typeRef
  # debug 'classScope', symbol

  if scope instanceof ClassScope
    if symbol is 'constructor'
      symbol = '_constructor_'

    unless scope.getThis symbol
      scope.addThis
        nodeType: 'variable'
        identifier:
          typeRef: symbol
        typeAnnotation: node.expr
    else
      reporter.add_error node, 'double bind: '+ symbol
  else
    unless scope.getVar symbol
      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: symbol
        typeAnnotation: node.expr
    else
      reporter.add_error node, 'double bind: '+ symbol

walkProgram = (node, scope) ->
  walk node.body.statements, scope
  node.typeAnnotation = identifier: 'Program'

walkBlock = (node, scope) ->
  walk node.statements, scope
  last_typeAnnotation = (node.statements[node.statements.length-1])?.typeAnnotation
  node.typeAnnotation = last_typeAnnotation

walkReturn = (node, scope) ->
  return # TODO
  walk node.expression, scope
  if node.expression?.typeAnnotation?.identifier?
    scope.addReturnable node.expression.typeAnnotation.identifier
    node.typeAnnotation = node.expression.typeAnnotation

walkBinOp = (node, scope) ->
  walk node.left, scope
  walk node.right, scope

  [leftAnnotation, rightAnnotation] = [node.left.typeAnnotation, node.right.typeAnnotation].map (node) =>
    unless node? # FIXME
      return ImplicitAnyAnnotation

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

  leftRef = leftAnnotation?.identifier?.typeRef
  rightRef = rightAnnotation?.identifier?.typeRef

  # TODO: implicit
  if leftRef and rightRef
    if leftRef is 'String' or rightRef is 'String'
      node.typeAnnotation =
        implicit: true
        nodeType: 'primitiveIdentifier'
        identifier:
          typeRef: 'String'

    else if leftRef is 'Int' and rightRef is 'Int'
      node.typeAnnotation =
        implicit: true
        nodeType: 'primitiveIdentifier'
        identifier:
          typeRef: 'Int'

    else if leftRef in ['Int', 'Float'] and rightRef in ['Int', 'Float']
      node.typeAnnotation =
        implicit: true
        nodeType: 'primitiveIdentifier'
        identifier:
          typeRef: 'Float'
    else if leftRef in ['Int', 'Float', 'Number'] and rightRef in ['Int', 'Float', 'Number']
      node.typeAnnotation =
        implicit: true
        nodeType: 'primitiveIdentifier'
        identifier:
          typeRef: 'Number'
    else if leftRef is rightRef is 'Any'
      # TODO: Number or String
      if node instanceof CS.PlusOp
        node.typeAnnotation =
          implicit: true
          nodeType: 'primitiveIdentifier'
          identifier:
            typeRef: 'Any'
      else
        node.typeAnnotation =
          implicit: true
          nodeType: 'primitiveIdentifier'
          identifier:
            typeRef: 'Number'
    else
      # FIXME
      node.typeAnnotation ?= ImplicitAnyAnnotation

  else
    node.typeAnnotation = ImplicitAnyAnnotation

walkConditional = (node, scope) ->
  # node.typeAnnotation ?= ImplicitAnyAnnotation
  walk node.condition, scope #=> Expr
  # else if
  if node.consequent
    walk node.consequent, scope #=> Block

  # else
  if node.alternate?
    walk node.alternate, scope #=> Block

  consequentAnnotation = node.consequent?.typeAnnotation
  alternateAnnotation = node.alternate?.typeAnnotation

  if consequentAnnotation and alternateAnnotation
    parentType = compareAsParent scope, consequentAnnotation, alternateAnnotation
    node.typeAnnotation = parentType
  else if consequentAnnotation and not alternateAnnotation
    ret = _.clone consequentAnnotation
    if ret.identifier?
      ret.identifier.nullable = true
    node.typeAnnotation = ret
  else
    node.typeAnnotation = ImplicitAnyAnnotation
  # debug 'Conditional', node

walkSwitch = (node, scope) ->
  if node.expression
    walk node.expression, scope

  canditates = []
  # condition expr
  for c in node.cases
    # when a, b, c
    for cond in c.conditions
      walk c, scope #=> Expr
    # console.error c.className
    walk c.consequent, scope
    canditates.push c.consequent.typeAnnotation

  # else
  if node.alternate
    walk node.alternate, scope #=> Block
    canditates.push c.consequent.typeAnnotation

  # debug 'walkSwitch', node
  [head, tail...] = canditates
  ret = _.clone _.reduce tail, ((a, b) ->
    compareAsParent scope, a, b
  ), head
  if ret?
    if ret.identifier?
      ret.identifier.nullable = not node.alternate?
    node.typeAnnotation = ret ? ImplicitAnyAnnotation
  else
    node.typeAnnotation = ImplicitAnyAnnotation


walkNewOp = (node, scope) ->
  type = scope.getTypeInScope node.ctor.data

  if type
    ctorAnnotation = _.find type.properties, (i) ->
      i.identifier?.typeRef is '_constructor_'

  for arg, n in node.arguments
    walk arg, scope

    left = ctorAnnotation?.typeAnnotation?.arguments?[n]
    right = arg?.typeAnnotation
    # debug 'walk left', left
    # debug 'walk right', right

    if left and right
      checkTypeAnnotation scope, node, left, right

  node.typeAnnotation = type ? ImplicitAnyAnnotation

walkOfOp = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO

walkFor = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO
  walk node.target, scope

  if node.valAssignee?
    scope.addVar node.valAssignee.data, (node.valAssignee?.typeAnnotation?.identifier) ? 'Any'

  if node.keyAssignee?
    # must be number or string
    scope.addVar node.keyAssignee.data, (node.keyAssignee?.typeAnnotation?.identifier) ? 'Any'

  if node.valAssignee?
    # ForIn
    if node.target.typeAnnotation?.identifier?.array?
      if err = scope.checkAcceptableObject(node.valAssignee.typeAnnotation.identifier, node.target.typeAnnotation.identifier.array)
        err = typeErrorText node.valAssignee.typeAnnotation.identifier, node.target.typeAnnotation.identifier.array
        return reporter.add_error node, err

    # ForOf
    else if node.target?.typeAnnotation?.identifier instanceof Object
      if node.target.typeAnnotation.identifier instanceof Object
        for nop, identifier of node.target.typeAnnotation.identifier
          if err = scope.checkAcceptableObject(node.valAssignee.typeAnnotation.identifier, identifier)
            err = typeErrorText node.valAssignee.typeAnnotation.identifier, identifier
            return reporter.add_error node, err

  # check body
  walk node.body, scope #=> Block
  node.typeAnnotation = node.target?.typeAnnotation

  # remove after iter
  delete scope._vars[node.valAssignee?.data] # WILL FIX
  delete scope._vars[node.keyAssignee?.data] # WILL FIX

walkClassProtoAssignOp = (node, scope) ->
  # node.typeAnnotation ?= ImplicitAnyAnnotation
  # return # TODO

  left  = node.assignee
  right = node.expression
  symbol = left.data

  # walk left, scope
  # debug 'left',
  if (right.instanceof CS.Function) and scope.getThis(symbol)
    annotation = scope.getThis(symbol)?.typeAnnotation
    # register before walk. for recursive call
    if annotation?
      left.typeAnnotation = annotation
      scope.addThis
        nodeType: 'variable'
        identifier:
          typeRef: symbol
        typeAnnotation: annotation
    walkFunction right, scope, annotation
  else
    annotation =
      nodeType: 'variable'
      identifier:
        typeRef: symbol
      typeAnnotation: null
    scope.addThis annotation
    walk right, scope

    if right.typeAnnotation
      annotation.typeAnnotation = right.typeAnnotation

  # symbol = left.data

  # if right.typeAnnotation?
  #   scope.addThis symbol, right.typeAnnotation.identifier

  # console.error left.className
  # debug 'proto left', left
  # console.error right.className
  # debug 'proto right', right


walkCompoundAssignOp = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO

walkAssignOp = (node, scope) ->
  left  = node.assignee
  right = node.expression
  symbol = left.data

  preAnnotation = left.typeAnnotation #TODO: dirty...

  walk left, scope

  # Example
  #   add :: Int * Int -> Int
  #   add = (x, y) -> x + y
  if (right.instanceof CS.Function) and scope.getVarInScope(symbol)
    v = scope.getVarInScope(symbol)
    walkFunction right, scope, v.typeAnnotation
  else if (right.instanceof CS.Function) and preAnnotation
    walkFunction right, scope, preAnnotation
  else
    walk right, scope

  # Array initializer
  if left.instanceof CS.ArrayInitialiser
    return # TODO

  # Destructive Assignment
  else if left?.members?
    return # TODO

  # Member
  else if left.instanceof CS.MemberAccessOp
    return unless checkType scope, node, left, right
  # Identifier
  else if left.instanceof CS.Identifier
    if scope.getVarInScope(symbol) and preAnnotation
      return reporter.add_error node, 'double bind: '+ symbol

    if left.typeAnnotation? and right.typeAnnotation?
      if left.typeAnnotation?.properties?
        return unless checkType scope, node, left, right
      else
        return unless checkType scope, node, left, right

    if preAnnotation?
      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: symbol
        typeAnnotation: preAnnotation

    else if right.typeAnnotation? and not right.typeAnnotation.implicit and left?.typeAnnotation.implicit
      left.typeAnnotation = right.typeAnnotation
      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: symbol
        typeAnnotation: right.typeAnnotation
    else
      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: symbol
        typeAnnotation: ImplicitAnyAnnotation
      left.typeAnnotation ?= ImplicitAnyAnnotation

  # Vanilla CS
  else
    return # TODO
    throw 'unexpected node:' + left?.className

walkPrimitives = (node, scope) ->
  switch
    # String
    when node.instanceof CS.String  then walkString node, scope
    # Bool
    when node.instanceof CS.Bool    then walkBool node, scope
    # Number
    when node.instanceof CS.Int then walkInt node, scope
    when node.instanceof CS.Float then walkFloat node, scope
    when node.instanceof CS.Numbers then walkNumbers node, scope
    when node.instanceof CS.Null then walkNull node, scope
    when node.instanceof CS.Undefined then walkUndefined node, scope

walkUndefined = (node, scope) ->
  node.typeAnnotation ?=
    implicit: true
    nodeType: 'identifier'
    identifier:
      typeRef: 'Undefined'

walkNull = (node, scope) ->
  node.typeAnnotation ?=
    implicit: true
    nodeType: 'identifier'
    identifier:
      typeRef: 'Null'

walkString = (node, scope) ->
  node.typeAnnotation ?=
    implicit: true
    nodeType: 'identifier'
    identifier:
      typeRef: 'String'

walkInt = (node, scope) ->
  node.typeAnnotation ?=
    nodeType: 'identifier'
    implicit: true
    identifier:
      typeRef: 'Int'

walkBool = (node, scope) ->
  node.typeAnnotation ?=
    nodeType: 'identifier'
    implicit: true
    identifier:
      typeRef: 'Boolean'

walkFloat = (node, scope) ->
  node.typeAnnotation ?=
    nodeType: 'identifier'
    implicit: true
    identifier:
      typeRef: 'Float'

  # node.typeAnnotation ?=
  #   implicit: true
  #   nodeType: 'primitiveIdentifier'
  #   isPrimitive: true
  #   identifier:
  #     typeRef: 'Float'
  #   heritages:
  #     extend:
  #       identifier:
  #         typeRef: 'Int'
  #         isArray: false

walkNumbers = (node, scope) ->
  node.typeAnnotation ?=
    nodeType: 'identifier'
    implicit: true
    identifier:
      typeRef: 'Number'
    # heritages:
    #   extend:
    #     identifier:
    #       typeRef: 'Float'

walkIdentifier = (node, scope) ->
  typeName = node.data
  if scope.getVarInScope(typeName)
    typeAnnotation = scope.getVarInScope(typeName)?.typeAnnotation
    node.typeAnnotation = typeAnnotation ? ImplicitAnyAnnotation
  else
    node.typeAnnotation ?= ImplicitAnyAnnotation

walkThis = (node, scope) ->
  # debug 'walkThis', node
  # debug 'walkThis members', scope._this
  node.typeAnnotation =
    nodeType: 'members'
    properties: scope._this

walkDynamicMemberAccessOp = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO

walkDynamicProtoMemberAccessOp = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO

walkProtoMemberAccessOp = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO

walkMemberAccess = (node, scope) ->
  # debug 'walkMemberAccess', node.expression.className
  if node.instanceof CS.MemberAccessOp
    walk node.expression, scope

  type = scope.getTypeByIdentifier(node.expression.typeAnnotation)

  if type
    member = _.find type.properties, (prop) => prop.identifier?.typeRef is node.memberName
    node.typeAnnotation = member?.typeAnnotation ? ImplicitAnyAnnotation # FIXME
  else
    node.typeAnnotation ?= ImplicitAnyAnnotation

  # if node.instanceof CS.SoakedMemberAccessOp
  #   walk node.expression, scope
  #   identifier = scope.extendTypeLiteral(node.expression.typeAnnotation?.identifier)
  #   if identifier?
  #     node.typeAnnotation =
  #       identifier:
  #         possibilities:['Undefined', identifier[node.memberName]]
  #   else
  #     node.typeAnnotation = identifier: 'Any', explicit: false

  # else if node.instanceof CS.MemberAccessOp
  #   walk node.expression, scope
  #   identifier = scope.extendTypeLiteral(node.expression.typeAnnotation?.identifier)
  #   if identifier?
  #     node.typeAnnotation = identifier: identifier[node.memberName], explicit: true
  #   else
  #     node.typeAnnotation = identifier: 'Any', explicit: false

walkArrayInializer = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO
  walk node.members, scope

  node.typeAnnotation ?=
    identifier: {array: (node.members?.map (m) -> m.typeAnnotation?.identifier)}

walkRange = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO
  node.typeAnnotation = identifier : {array: 'Number'}

walkObjectInitializer = (node, scope) ->
  obj = {}
  nextScope = new Scope scope
  nextScope.name = 'object'

  props = []

  for {expression, key} in node.members when key?
    walk expression, nextScope
    props.push
      implicit: true
      identifier:
        typeRef: key.data
      nodeType: 'identifier'
      typeAnnotation: expression.typeAnnotation

  node.typeAnnotation ?=
    properties: props
    nodeType: 'members'
    implicit: true
    heritages: # TODO: check scheme later
      extend:
        implicit: true
        nodeType: 'identifier'
        identifier:
          typeRef: 'Object'

walkClass = (node, scope) ->
  classScope = new ClassScope scope
  # Add props to this_socpe by extends and implements
  if node.nameAssignee?.data
    classScope.name = node.nameAssignee?.data

  # has parent class?
  if node.impl?.length
    # debug 'walkClass impl!', node
    for impl in node.impl
      parentAnnotation = scope.getTypeInScope(impl.identifier.typeRef) # TODO: member access
      if parentAnnotation
        parentAnnotation.properties.map (prop) ->
          classScope.addThis _.clone(prop)

  # has parent class?
  if node.parent?
    # TODO: member access
    parentAnnotation = scope.getTypeInScope(node.parent.data)
    if parentAnnotation
      parentAnnotation.properties.map (prop) ->
        classScope.addThis _.clone(prop)
  # collect @values first
  if node.body?.statements?
    for statement in node.body.statements when statement.nodeType is 'vardef'
      walkVardef statement, classScope

  # constructor
  if node.ctor?
    walkFunction node.ctor.expression, classScope, classScope.getConstructorType()

  # walk
  if node.body instanceof CS.Block
    for statement in node.body.statements when statement.nodeType isnt 'vardef'
      walk statement, classScope

  if node.nameAssignee?.data
    scope.addType
      nodeType: 'struct'
      newable: true
      identifier:
        typeRef: node.nameAssignee.data
      members:
        nodeType: 'members'
        properties: _.map _.clone(classScope._this), (prop) ->
          prop.nodeType = 'identifier' # hack for type checking
          prop

# walkFunction :: Node * Scope * TypeAnnotation? -> ()
walkFunction = (node, scope, preAnnotation = null) ->
  functionScope = new Scope scope
  if scope instanceof ClassScope # TODO: fat arrow
    functionScope._this = scope._this

  if preAnnotation?
    # if node.typeAnnotation?.identifier?.typeRef is 'Any'
    if node.typeAnnotation?
      annotation = _.clone node.typeAnnotation
      annotation.returnType ?= ImplicitAnyAnnotation
      annotation.arguments ?= annotation.arguments?.map (arg) -> arg ? ImplicitAnyAnnotation
      annotation.arguments ?= []

      return unless checkTypeAnnotation scope, node,  annotation, preAnnotation

    hasError = false
    node.typeAnnotation = preAnnotation

    node.parameters?.map (param, n) ->
      if param.typeAnnotation?
        return unless checkTypeAnnotation scope, node, preAnnotation.arguments[n], param.typeAnnotation
      param.typeAnnotation ?= preAnnotation.arguments?[n] ? ImplicitAnyAnnotation
      functionScope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: param.data
        typeAnnotation: param.typeAnnotation
    if hasError then return
  else
    node.parameters?.map (param, n) ->
      functionScope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: param.data
        typeAnnotation: param.typeAnnotation ? ImplicitAnyAnnotation

  if node.body?
    if node.body instanceof CS.Function
      walkFunction node.body, functionScope, node.typeAnnotation.returnType
    else
      walk node.body, functionScope

    unless preAnnotation
      node.typeAnnotation.returnType = node.body.typeAnnotation

    left = node.typeAnnotation.returnType ?= ImplicitAnyAnnotation
    right = node.body.typeAnnotation ?= ImplicitAnyAnnotation

    return unless checkTypeAnnotation scope, node, left, right

walkFunctionApplication = (node, scope) ->
  for arg in node.arguments
    walk arg, scope
  walk node.function, scope

  if node.function.typeAnnotation?.nodeType is 'functionType'
    node.typeAnnotation = node.function.typeAnnotation.returnType ? ImplicitAnyAnnotation
  else if node.function.typeAnnotation?.nodeType is 'primitiveIdentifier'
    node.typeAnnotation ?= ImplicitAnyAnnotation

  for arg, n in node.arguments
    left = node.function.typeAnnotation?.arguments?[n]
    right = arg?.typeAnnotation
    if left and right
      checkTypeAnnotation scope, node, left, right

# Traverse all nodes
# Node -> void
walk = (node, scope) ->
  return unless node?
  # console.error 'walking node:', node?.className , node?.raw2
  # debug 'walk', node
  switch
    # undefined(mayby null body)
    when not node? then return
    # Nodes Array
    when node.length?                    then  walk s, scope for s in node
    # Struct
    # Dirty hack on Number
    when node.nodeType is 'struct'       then walkStruct node, scope
    when node.nodeType is 'vardef'       then walkVardef node, scope
    # Program
    when node.instanceof CS.Program      then walkProgram node, scope
    # Block
    when node.instanceof CS.Block        then walkBlock node, scope
    # Retrun
    when node.instanceof CS.Return       then  walkReturn node, scope
    # New
    when node.instanceof CS.NewOp        then  walkNewOp node, scope
    # BinaryOperator
    when node.instanceof(CS.PlusOp) or node.instanceof(CS.MultiplyOp) or node.instanceof(CS.DivideOp) or node.instanceof(CS.SubtractOp)
      walkBinOp node, scope

    # === Controlle flow ===
    # Switch
    when node.instanceof CS.Switch then walkSwitch node, scope
    # If
    when node.instanceof CS.Conditional  then walkConditional node, scope

    when node.instanceof CS.Undefined         then walkUndefined node, scope

    when node.instanceof CS.OfOp              then walkOfOp node, scope
    # For
    when (node.instanceof CS.ForIn) or (node.instanceof CS.ForOf) then walkFor node, scope
    # Primitives
    when node.instanceof CS.Primitives        then walkPrimitives node, scope
    when node.instanceof CS.Null              then walkNull node, scope
    # This
    when node.instanceof CS.This              then walkThis node, scope
    # Identifier
    when node.instanceof CS.Identifier        then walkIdentifier node, scope
    # ClassProto
    when node.instanceof CS.ClassProtoAssignOp then walkClassProtoAssignOp node, scope
    # MemberAccessOps TODO: imperfect
    when node.instanceof CS.DynamicProtoMemberAccessOp
      walkDynamicProtoMemberAccessOp node, scope
    when node.instanceof CS.DynamicMemberAccessOp then walkDynamicMemberAccessOp node, scope
    when node.instanceof CS.ProtoMemberAccessOp then walkProtoMemberAccessOp node, scope
    when node.instanceof CS.MemberAccessOps   then walkMemberAccess node, scope
    # Array
    when node.instanceof CS.ArrayInitialiser  then walkArrayInializer node, scope
    # Range
    when node.instanceof CS.Range             then walkRange node, scope
    # Object
    when node.instanceof CS.ObjectInitialiser then walkObjectInitializer node, scope
    # Class
    when node.instanceof CS.Class             then walkClass node, scope
    # Function
    when node.instanceof CS.Function          then walkFunction node, scope
    # FunctionApplication
    when node.instanceof CS.FunctionApplication then walkFunctionApplication node, scope
    # left.typeAnnotation.identifier
    when node.instanceof CS.CompoundAssignOp then walkCompoundAssignOp node, scope
    when node.instanceof CS.AssignOp then walkAssignOp node, scope

module.exports = {checkNodes}
