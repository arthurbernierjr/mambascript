{debug} = require './helpers'
reporter = require './reporter'
CS = require './nodes'
_ = require 'lodash'

{
  isAcceptable,
  checkType,
  checkTypeAnnotation,
  resolveType,
  extendTypeWithArguments,
  extendFunctionType
} = require './type-checker'

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
    initializeGlobalTypes(root)

  # debug 'root', cs_ast
  walk cs_ast, root
  return root

walkStruct = (node, scope) ->
  scope.addStructType _.cloneDeep node
  node.typeAnnotation = ImplicitAnyAnnotation

walkVardef = (node, scope) ->
  symbol = node.name.identifier.typeRef
  if scope instanceof ClassScope
    # avoid 'constructor' because it's property has special action on EcmaScript
    if symbol is 'constructor'
      symbol = '_constructor_'

    unless val = scope.getThis symbol
      scope.addThis
        nodeType: 'variable'
        identifier:
          typeRef: symbol
          typeArguments: node.name?.identifier?.typeArguments
        typeAnnotation: node.expr
    else
      if val.typeAnnotation.implicit and val.typeAnnotation.identifier.typeRef is 'Any'
        val.typeAnnotation = node.expr
      else
        reporter.add_error node, 'double bind: '+ symbol
  else
    unless val = scope.getVar symbol
      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: symbol
          typeArguments: node.name?.identifier?.typeArguments
        typeAnnotation: node.expr
    else
      if val.typeAnnotation.implicit and val.typeAnnotation.identifier.typeRef is 'Any'
        val.typeAnnotation = node.expr
      else
        reporter.add_error node, 'double bind: '+ symbol

walkProgram = (node, scope) ->
  walk node.body.statements, scope
  node.typeAnnotation = identifier: 'Program'

walkBlock = (node, scope) ->
  walk node.statements, scope
  returnables = scope.getReturnables()

  if _.last(node.statements)?.typeAnnotation
    lastAnn = (_.last node.statements).typeAnnotation
    returnables.push lastAnn

  node.typeAnnotation = scope.getHighestCommonType returnables

walkReturn = (node, scope) ->
  walk node.expression, scope
  if node.expression?.typeAnnotation?
    node.typeAnnotation = node.expression.typeAnnotation
    scope.addReturnable node.typeAnnotation

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
    parentType = scope.getHighestCommonType [consequentAnnotation, alternateAnnotation]
    node.typeAnnotation = parentType
  else if consequentAnnotation and not alternateAnnotation
    ret = _.cloneDeep consequentAnnotation
    if ret.identifier?
      ret.identifier.nullable = true
    node.typeAnnotation = ret
  else
    node.typeAnnotation = ImplicitAnyAnnotation

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
    if c.consequent
      walk c.consequent, scope
      canditates.push c.consequent.typeAnnotation

  # else
  if node.alternate
    walk node.alternate, scope #=> Block
    if c.alternate?.typeAnnotation?
      canditates.push c.alternate.typeAnnotation

  ann = scope.getHighestCommonType canditates

  if ann?
    if ann.identifier?
      ann.identifier.nullable = not node.alternate?
    node.typeAnnotation = ann ? ImplicitAnyAnnotation
  else
    node.typeAnnotation = ImplicitAnyAnnotation

walkNewOp = (node, scope) ->
  ctor = node.ctor?.ctor ? node.ctor
  args = node.ctor?.arguments ? node.arguments
  ann = scope.getTypeInScope ctor.data

  # override types
  if ctor.typeArguments?.length
    givenArgs = ctor.typeArguments
    ann = extendTypeWithArguments scope, _.cloneDeep(ann), givenArgs

  if ann
    ctorAnnotation = _.find ann.properties, (i) ->
      i.identifier?.typeRef is '_constructor_'

  # debug 'walkNewOp', ctorAnnotation
  # argument type check
  for arg, n in args
    walk arg, scope
    left = ctorAnnotation?.typeAnnotation?.arguments?[n]
    right = arg?.typeAnnotation
    if left and right
      checkTypeAnnotation scope, node, left, right

  node.typeAnnotation = ann ? ImplicitAnyAnnotation

walkOfOp = (node, scope) ->
  node.typeAnnotation ?= ImplicitAnyAnnotation
  return # TODO

walkFor = (node, scope) ->
  walk node.target, scope
  if node.valAssignee?
    preAnnotation = node?.valAssignee?.typeAnnotation
    walk node.valAssignee, scope
    # Override annotation if it is implicit Any
    # if node.target.typeAnnotation?.identifier?.isArray
    if preAnnotation
      # TODO: type check
      node.valAssignee.typeAnnotation = preAnnotation
    else if node.target.typeAnnotation?.identifier?.isArray
      targetType = _.cloneDeep node.target.typeAnnotation
      delete targetType.identifier.isArray
      node.valAssignee.typeAnnotation = targetType
    else
      node.valAssignee.typeAnnotation = ImplicitAnyAnnotation

    scope.addVar
      nodeType: 'variable'
      identifier:
        typeRef: node.valAssignee.data
      typeAnnotation: node.valAssignee.typeAnnotation

  if node.keyAssignee?
    if node instanceof CS.ForIn
      node.keyAssignee.typeAnnotation =
        nodeType: 'identifier'
        identifier:
          typeRef: 'Int'

      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: node.keyAssignee.data
        typeAnnotation:
          nodeType: 'identifier'
          identifier:
            typeRef: 'Int'
    else if node instanceof CS.ForOf
      # TODO: FIX later
      node.keyAssignee.typeAnnotation =
        nodeType: 'identifier'
        identifier:
          typeRef: 'String'
      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: node.keyAssignee.data
        typeAnnotation:
          nodeType: 'identifier'
          identifier:
            typeRef: 'String'
  # check body
  walk node.body, scope #=> Block

  if node.body?
    bodyType =  _.cloneDeep node.body.typeAnnotation

  if bodyType?.identifier
    if node.body?
      bodyType.identifier.isArray = true
      node.typeAnnotation = bodyType
    else
      node.typeAnnotation = ImplicitAnyAnnotation
  else
    node.typeAnnotation = ImplicitAnyAnnotation

walkClassProtoAssignOp = (node, scope) ->
  # node.typeAnnotation ?= ImplicitAnyAnnotation
  # return # TODO

  left  = node.assignee
  right = node.expression
  symbol = left.data

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
  if left instanceof CS.ArrayInitialiser
    if right.typeAnnotation?.identifier?.typeRef is 'Any'
      '' # ignore case
    else
      if right instanceof CS.ArrayInitialiser
        for lprop, n in left.members
          rprop = right?.members?[n]
          if lprop and rprop # FIXME: right may be null
            checkType scope, node, lprop, rprop
      else if right.typeAnnotation?.identifier?.isArray
        for lprop, n in left.members
          rpropAnn = _.cloneDeep right.typeAnnotation
          delete rpropAnn.identifier.isArray
          if lprop and rpropAnn # FIXME: right may be null
            # checkType scope, node, lprop, rprop
            checkTypeAnnotation scope, node, lprop.typeAnnotation, rpropAnn

    for member in left.members
      symbol = member.data
      unless scope.getVarInScope(symbol)
        scope.addVar
          nodeType: 'variable'
          identifier:
            typeRef: symbol
          typeAnnotation: member.typeAnnotation

  # Destructive Assignment
  else if left instanceof CS.ObjectInitialiser
    if right.typeAnnotation?.identifier?.typeRef is 'Any'
      '' # ignore case
    else
      return unless checkType scope, node, left, right

    for member in left.members
      symbol = member.key.data
      unless scope.getVarInScope(symbol)
        scope.addVar
          nodeType: 'variable'
          identifier:
            typeRef: symbol
          typeAnnotation: member.typeAnnotation

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

walkNumbers = (node, scope) ->
  node.typeAnnotation ?=
    nodeType: 'identifier'
    implicit: true
    identifier:
      typeRef: 'Number'

walkIdentifier = (node, scope) ->
  typeName = node.data
  if scope.getVarInScope(typeName)
    typeAnnotation = scope.getVarInScope(typeName)?.typeAnnotation
    node.typeAnnotation = typeAnnotation ? ImplicitAnyAnnotation
  else
    node.typeAnnotation ?= ImplicitAnyAnnotation

walkThis = (node, scope) ->
  node.typeAnnotation =
    nodeType: 'members'
    implicit: true
    identifier:
      typeRef: '[this]'
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
  for member in node.members
    walk member, scope
  ann = scope.getHighestCommonType node.members.map (m) -> m.typeAnnotation

  if ann?.identifier?
    ann.identifier.isArray = true
  node.typeAnnotation = ann

walkRange = (node, scope) ->
  node.typeAnnotation =
    nodeType: 'identifier'
    implicit: true
    identifier:
      typeRef: 'Int'
      isArray: true

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
    identifier:
      typeRef: '[object]'

walkClass = (node, scope) ->
  classScope = new ClassScope scope
  # Add props to this_socpe by extends and implements
  if node.nameAssignee?.data
    classScope.name = node.nameAssignee?.data

  # resolve at new
  if node.typeArguments?.length
    for arg in node.typeArguments
      classScope.addType
        nodeType: 'identifier'
        identifier:
          typeRef: arg.identifier.typeRef
        # typeAnnotation:
        #   unresolved: true
        #   nodeType: 'identifier'
        #   identifier:
        #     typeRef: arg.identifier.typeRef

  # has parent class?
  if node.impl?.length
    for impl in node.impl
      parentAnnotation = scope.getTypeInScope(impl.identifier.typeRef) # TODO: member access
      if parentAnnotation
        parentAnnotation.properties.map (prop) ->
          classScope.addThis _.cloneDeep(prop)

  # has parent class?
  if node.parent?
    # TODO: member access
    parentAnnotation = scope.getTypeInScope(node.parent.data)
    if parentAnnotation
      parentAnnotation.properties.map (prop) ->
        classScope.addThis _.cloneDeep(prop)
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
    type =
      nodeType: 'members'
      newable: true
      identifier:
        typeRef: node.nameAssignee.data
        typeArguments: node.typeArguments ? []
      properties: _.map _.cloneDeep(classScope._this), (prop) ->
        prop.nodeType = 'identifier' # hack for type checking
        prop
    scope.addType type

# TODO: move
addValuesByInitializer = (scope, initializerNode, preAnnotation = null) ->
  if initializerNode instanceof CS.ArrayInitialiser
    for member in initializerNode.members
      symbol = member.data
      unless scope.getVar(symbol)
        scope.addVar
          nodeType: 'variable'
          identifier:
            typeRef: symbol
          typeAnnotation: member.typeAnnotation ? ImplicitAnyAnnotation
  else if initializerNode instanceof CS.ObjectInitialiser
    for member in initializerNode.members
      symbol = member.key.data
      unless scope.getVar(symbol)
        scope.addVar
          nodeType: 'variable'
          identifier:
            typeRef: symbol
          typeAnnotation: member.typeAnnotation ? ImplicitAnyAnnotation

# walkFunction :: Node * Scope * TypeAnnotation? -> ()
walkFunction = (node, scope, preAnnotation = null) ->
  functionScope = new Scope scope
  if scope instanceof ClassScope # TODO: fat arrow
    functionScope._this = scope._this

  if preAnnotation?
    # if node.typeAnnotation?.identifier?.typeRef is 'Any'
    if node.typeAnnotation?
      annotation = _.cloneDeep node.typeAnnotation
      annotation.returnType ?= ImplicitAnyAnnotation
      annotation.arguments ?= annotation.arguments?.map (arg) -> arg ? ImplicitAnyAnnotation
      annotation.arguments ?= []
      return unless checkTypeAnnotation scope, node,  annotation, preAnnotation

    node.typeAnnotation = preAnnotation

    node.parameters?.map (param, n) ->
      if param.typeAnnotation?
        return unless checkTypeAnnotation scope, node, preAnnotation.arguments[n], param.typeAnnotation
      # FIXME: we should always walk param
      if param instanceof CS.MemberAccessOp
        walk param, functionScope

      param.typeAnnotation ?= preAnnotation.arguments?[n] ? ImplicitAnyAnnotation

      if param instanceof CS.Identifier
        functionScope.addVar
          nodeType: 'variable'
          identifier:
            typeRef: param.data
          typeAnnotation: param.typeAnnotation

      # getX :: Int[] -> Int = ([x, y]) -> x
      else if param instanceof CS.ArrayInitialiser
        preAnn = preAnnotation.arguments?[n]
        if preAnn
          for member in param.members
            type =  _.cloneDeep resolveType scope, preAnn
            type.identifier.isArRay = false
            if type.nodeType is 'primitiveIdentifier'
              t = _.cloneDeep preAnn
              delete t.identifier.isArray
              member.typeAnnotation = t
            else
              member.typeAnnotation = type ? ImplicitAnyAnnotation

        addValuesByInitializer scope, param
      # f :: Point -> Int = ({x, y}) -> Int
      else if param instanceof CS.ObjectInitialiser
        preAnn = preAnnotation.arguments?[n]
        if preAnn
          for member in param.members
            type =  resolveType scope, preAnn
            if type.nodeType is 'members'
              memberAnn =  _.find type.properties, (prop) -> prop.identifier?.typeRef is member.key?.data
              member.typeAnnotation = memberAnn?.typeAnnotation ? ImplicitAnyAnnotation
        addValuesByInitializer scope, param

  else
    node.parameters?.map (param, n) ->
      walk param, functionScope
      if param instanceof CS.Identifier
        functionScope.addVar
          nodeType: 'variable'
          identifier:
            typeRef: param.data
          typeAnnotation: param.typeAnnotation ? ImplicitAnyAnnotation
      else if param instanceof CS.ObjectInitialiser
        addValuesByInitializer scope, param
      else if param instanceof CS.ArrayInitialiser
        addValuesByInitializer scope, param

  if node.body?
    if node.body instanceof CS.Function
      walkFunction node.body, functionScope, node.typeAnnotation.returnType
    else
      walk node.body, functionScope

    unless preAnnotation
      if node.typeAnnotation?
        node.typeAnnotation.returnType = node.body.typeAnnotation

    node.typeAnnotation ?=
      implicit: true
      nodeType: 'functionType'
      returnType: null
      arguments: []

    left = node.typeAnnotation.returnType ?= ImplicitAnyAnnotation
    right = node.body.typeAnnotation ?= ImplicitAnyAnnotation
    # debug 'walkFunction l', left
    # debug 'walkFunction r', right
    # debug 'walkFunction body', node.body
    return unless checkTypeAnnotation scope, node, left, right

walkFunctionApplication = (node, scope) ->
  walk node.function, scope

  for arg, n in node.arguments
    walk arg, scope

    # preAnn = node.function.typeAnnotation?.arguments?[n]
    # debug 'preAnn', preAnn
    # if arg instanceof CS.Function and preAnn
    #   walkFunction arg, scope, preAnn
    # else
    #   walk arg, scope


  type = scope.getVarInScope node.function.data
  if type?.identifier?.typeArguments?.length
    typeScope = new Scope scope
    typeArguments = node.function.typeArguments
    for arg, n in type.identifier?.typeArguments
      givenArg = typeArguments?[n]
      typeScope.addType
        nodeType: 'identifier'
        identifier:
          typeRef: arg.identifier.typeRef
        typeAnnotation:
          nodeType: 'identifier'
          identifier:
            typeRef: givenArg.identifier.typeRef

    node.function.typeAnnotation = extendFunctionType typeScope, _.cloneDeep(node.function.typeAnnotation)

  if node.function.typeAnnotation?.nodeType is 'functionType'
    node.typeAnnotation = node.function.typeAnnotation.returnType ? ImplicitAnyAnnotation
  else if node.function.typeAnnotation?.nodeType is 'primitiveIdentifier'
    node.typeAnnotation ?= ImplicitAnyAnnotation

  for arg, n in node.arguments
    left = node.function.typeAnnotation?.arguments?[n]
    right = arg?.typeAnnotation

    if arg instanceof CS.Function
      if node.function.typeAnnotation?.identifier?.typeRef isnt 'Any'
        preAnn = node.function.typeAnnotation?.arguments?[n]
        if preAnn
          # walk arg again to build annotation by new arguments
          for param, i in arg.parameters
            a = preAnn.arguments[i]
            param.typeAnnotation = preAnn.arguments[i]
          delete arg.typeAnnotation
          delete arg.body.typeAnnotation
          walkFunction arg, scope, preAnn
          right = preAnn

    if left and right
      checkTypeAnnotation scope, node, left, right

# Traverse all nodes
# Node -> void
walk = (node, scope) ->
  return unless node?
  # console.error 'walking node:', node?.className , node?.raw
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
