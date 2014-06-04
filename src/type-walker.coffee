{debug} = require './helpers'
reporter = require './reporter'
CS = require './nodes'
_ = require 'lodash'

{isAcceptable, checkType} = require './type-checker'

ImplicitAnyAnnotation =
  implicit: true
  isPrimitive: true
  nodeType: 'primitiveIdentifier'
  identifier:
    typeRef: 'Any'

# same :: Any... -> Boolean
same = (args...) ->
  len = args.length
  list = i for i, n in args when n isnt len-1
  _.all list, _.last args

typeErrorText = (left, right) ->
  util = require 'util'
  "TypeError: \n#{util.inspect left, false, null} \n to \n #{util.inspect right, false, null}"

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
    # for i in ['global', 'exports', 'module']
    #   root.addVar i, 'Any', true
    initializeGlobalTypes(root)

  # debug 'root', cs_ast
  walk cs_ast, root
  return root

walkStruct = (node, scope) ->
  # debug node
  scope.addStructType node

walkVardef = (node, scope) ->
  # return # TODO
  # avoid 'constructor' because it's property has special action on EcmaScript
  # debug 'vardef', node
  symbol = node.name.identifier.typeRef

  if scope instanceof ClassScope
    if symbol is 'constructor'
      symbol = '_constructor_'
    return # TODO

    scope.addThis symbol, node.expr
  else
    scope.addVar
      nodeType: 'variable'
      identifier:
        typeRef: symbol
      typeAnnotation: node.expr

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

  leftRef = leftAnnotation?.identifier.typeRef
  rightRef = rightAnnotation?.identifier.typeRef

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
      console.error 'aafdafda', node.className
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
    node.typeAnnotation = ImplicitAnyAnnotation
  # debug 'binOp', node

walkConditional = (node, scope) ->
  return # TODO
  # condition expr
  walk node.condition, scope #=> Expr

  # else if
  walk node.consequent, scope #=> Block

  # else
  if node.alternate?
    walk node.alternate, scope #=> Block

  # if node.alternate doesn't exist, then return type is Undefined
  alternate_typeAnnotation = (node.alternate?.typeAnnotation) ? (identifier: 'Undefined')

  possibilities = []
  for typeAnnotation in [node.consequent?.typeAnnotation, alternate_typeAnnotation] when typeAnnotation?
    if typeAnnotation.identifier?.possibilities?
      possibilities.push identifier for identifier in typeAnnotation.identifier.possibilities

    else if typeAnnotation.identifier?
      possibilities.push typeAnnotation.identifier

  node.typeAnnotation = identifier: {possibilities}

walkSwitch = (node, scope) ->
  return # TODO
  walk node.expression, scope

  # condition expr
  for c in node.cases
    # when a, b, c
    for cond in c.conditions
      walk c, scope #=> Expr
    walk c.consequent, scope

  # else if
  walk node.consequent, scope #=> Block

  # else
  if node.alternate?
    walk node.alternate, scope #=> Block

  # if node.alternate doesn't exist, then return type is Undefined
  alternate_typeAnnotation = (node.alternate?.typeAnnotation) ? (identifier: 'Undefined')

  possibilities = []
  for c in node.cases when c.typeAnnotation?
    possibilities.push c.consequent.typeAnnotation

  possibilities.push alternate_typeAnnotation.identifier
  node.typeAnnotation = identifier: {possibilities}

walkNewOp = (node, scope) ->
  return # TODO
  for arg in node.arguments
    walk arg, scope
  Type = scope.getTypeInScope node.ctor.data
  if Type
    args = node.arguments?.map (arg) -> arg.typeAnnotation?.identifier
    if err = scope.checkAcceptableObject Type.identifier._constructor_, {arguments: (args ? []), returnType: 'Any'}
      err = typeErrorText Type.identifier._constructor_, {arguments: (args ? []), returnType: 'Any'}
      return reporter.add_error node, err

  node.typeAnnotation = identifier: Type?.identifier

walkFor = (node, scope) ->
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
  return # TODO
  left  = node.assignee
  right = node.expression
  symbol = left.data

  walk left, scope
  if (right.instanceof CS.Function) and scope.getThis(symbol)
    walkFunction right, scope, scope.getThis(symbol).identifier
  else
    walk right, scope

  symbol = left.data

  if right.typeAnnotation?
    scope.addThis symbol, right.typeAnnotation.identifier

walkAssignOp = (node, scope) ->
  left  = node.assignee
  right = node.expression
  symbol = left.data

  preAnnotation = left.typeAnnotation #TODO: dirty...

  walk left, scope

  # TODO: refactor as functionTypeCheck
  # if preAnnotation and (right.typeAnnotation?.identifier?.identifier is left.typeAnnotation?.identifier?.identifier is 'Function')
  #   if scope.checkAcceptableObject(left.typeAnnotation.identifier.returnType, right.typeAnnotation.identifier.returnType)
  #     err = typeErrorText left.typeAnnotation.identifier.returnType, right.typeAnnotation.identifier.returnType
  #     return reporter.add_error node, err
  #   for arg, n in left.typeAnnotation.identifier.arguments
  #     if scope.checkAcceptableObject(left.typeAnnotation.identifier.arguments[n]?.identifier, right.typeAnnotation.identifier.arguments[n]?.identifier)
  #       err = typeErrorText left.typeAnnotation.identifier, right.typeAnnotation.identifier
  #       return reporter.add_error node, err

  # if right.instanceof?(CS.Function) and scope.getVarInScope(symbol)
  #   walkFunction right, scope, scope.getVarInScope(symbol).identifier
  # else if right.instanceof?(CS.Function) and preAnnotation
  #   walkFunction right, scope, left.typeAnnotation.identifier
  # else

  # Example
  #   add :: Int * Int -> Int
  #   add = (x, y) -> x + y
  if (right.instanceof CS.Function) and scope.getVarInScope(symbol)
    v = scope.getVarInScope(symbol)
    walkFunction right, scope, v.typeAnnotation
  else
    walk right, scope

  # Array initializer
  if left.instanceof CS.ArrayInitialiser
    return # TODO
    # if left.expression.instanceof CS.This
    # for member, index in left.members when member.data?
    #   l = left.typeAnnotation?.identifier?.array?[index]
    #   r = right.typeAnnotation?.identifier?.array?[index]
    #   if err = scope.checkAcceptableObject l, r
    #     err = typeErrorText l, r
    #     reporter.add_error node, err
    #   if l
    #     scope.addVar member.data, l, true
    #   else
    #     scope.addVar member.data, "Any", false

  # Destructive Assignment
  else if left?.members?
    return # TODO
    # if left.expression.instanceof CS.This
    # for member in left.members when member.key?.data?
    #   if scope.getVarInScope member.key.data
    #     l_type = scope.getVarInScope(member.key.data).identifier
    #     if err = scope.checkAcceptableObject l_type, right.typeAnnotation?.identifier?[member.key.data]
    #       err = typeErrorText l_type, right.typeAnnotation?.identifier?[member.key.data]
    #       reporter.add_error node, err
    #   else
    #     scope.addVar member.key.data, 'Any', false

  # Member
  else if left.instanceof CS.MemberAccessOp
    return unless checkType scope, node, left, right
    # TODO: this
    # if left.expression.instanceof CS.This
    #   T = scope.getThis(left.memberName)
    #   left.typeAnnotation = T if T?
    #   if T?
    #     if err = scope.checkAcceptableObject(left.typeAnnotation.identifier, right.typeAnnotation.identifier)
    #       err = typeErrorText left.typeAnnotation.identifier, right.typeAnnotation.identifier
    #       reporter.add_error node, err
    # # return if left.expression.raw is '@' # ignore @ yet
    # else if left.typeAnnotation?.identifier? and right.typeAnnotation?.identifier?
      # if left.typeAnnotation.identifier isnt 'Any'
        # if err = scope.checkAcceptableObject(left.typeAnnotation.identifier, right.typeAnnotation.identifier)
    #       err = typeErrorText left.typeAnnotation.identifier, right.typeAnnotation.identifier
    #       return reporter.add_error node, err

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
    else if not right.typeAnnotation.implicit and left.typeAnnotation.implicit
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
    throw 'unexpected node:' + node?.className

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

walkString = (node, scope) ->
  node.typeAnnotation ?=
    implicit: true
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'String'

walkInt = (node, scope) ->
  node.typeAnnotation ?=
    implicit: true
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Int'

walkBool = (node, scope) ->
  return # TODO
  node.typeAnnotation ?=
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Boolean'

walkFloat = (node, scope) ->
  node.typeAnnotation ?=
    implicit: true
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Float'
    heritages:
      extend:
        identifier:
          typeRef: 'Int'
          isArray: false

walkNumbers = (node, scope) ->
  node.typeAnnotation ?=
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Number'
    heritages:
      extend:
        identifier:
          typeRef: 'Float'

walkIdentifier = (node, scope) ->
  typeName = node.data
  if scope.getVarInScope(typeName)
    typeAnnotation = scope.getVarInScope(typeName)?.typeAnnotation
    node.typeAnnotation = typeAnnotation ? ImplicitAnyAnnotation
  else
    node.typeAnnotation ?= ImplicitAnyAnnotation

walkThis = (node, scope) ->
  return # TODO
  identifier = {}
  for key, val of scope._this
    identifier[key] = val.identifier
  node.typeAnnotation ?= {identifier}

walkMemberAccess = (node, scope) ->
  if node.instanceof CS.MemberAccessOp
    walk node.expression, scope

  type = scope.getTypeByIdentifier(node.expression.typeAnnotation)

  if type
    member = _.find type.properties, (prop) => prop.identifier?.typeRef is node.memberName
    node.typeAnnotation = member?.typeAnnotation ? ImplicitAnyAnnotation # FIXME
  else
    node.typeAnnotation ?= ImplicitAnyAnnotation

  debug 'walkMemberAccess', node

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
  return # TODO
  walk node.members, scope

  node.typeAnnotation ?=
    identifier: {array: (node.members?.map (m) -> m.typeAnnotation?.identifier)}

walkRange = (node, scope) ->
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
  # debug 'ObjectInitialiser', node.typeAnnotation


walkClass = (node, scope) ->
  return # TODO
  classScope = new ClassScope scope
  this_scope = {}
  # Add props to this_socpe by extends and implements
  if node.nameAssignee?.data
    # extends
    if node.parent?.data
      parent = scope.getTypeInScope node.parent.data
      if parent
        for key, val of parent.identifier
          this_scope[key] = val
    # implements
    if node.impl?.length?
      for name in node.impl
        cls = scope.getTypeInScope name
        if cls
          for key, val of cls.identifier
            this_scope[key] = val

  # collect @values first
  if node.body?.statements?
    for statement in node.body.statements when statement.identifier is 'vardef'
      walkVardef statement, classScope

  # constructor
  if node.ctor?
    constructorScope = new FunctionScope classScope
    constructorScope._this = classScope._this # delegate this scope
    # arguments
    if node.ctor.expression.parameters?
      # vardef exists: constructor :: X, Y, Z
      if constructorScope.getThis('_constructor_')
        preAnnotation = constructorScope.getThis('_constructor_').identifier
        for param, index in node.ctor.expression.parameters when param?
          walk param, constructorScope
          constructorScope.addVar param.data, (preAnnotation.arguments?[index] ? 'Any')
      else
        for param, index in node.ctor.expression.parameters when param?
          walk param, constructorScope
          constructorScope.addVar param.data, (param?.typeAnnotation?.identifier ? 'Any')

    # constructor body
    if node.ctor.expression.body?.statements?
      for statement in node.ctor.expression.body.statements
        walk statement, constructorScope

  # walk
  if node.body?.statements?
    for statement in node.body.statements when statement.identifier isnt 'vardef'
      walk statement, classScope

  if node.nameAssignee?.data
    for fname, val of classScope._this
      this_scope[fname] = val.identifier
    scope.addType node.nameAssignee.data, this_scope

# Node * Scope * Type
# preAnnotation :: Type defined at assignee
# walkFunction :: Node * Scope * TypeAnnotation? -> ()
walkFunction = (node, scope, preAnnotation = null) ->
  functionScope = new Scope scope
  if scope instanceof ClassScope # TODO: fat arrow
    functionScope._this = scope._this

  if preAnnotation?
    hasError = false
    node.typeAnnotation = preAnnotation
    node.parameters?.map (param, n) ->
      if param.typeAnnotation?
        unless isAcceptable scope, preAnnotation.arguments[n], param.typeAnnotation
          typeErrorText = (left, right) ->
            util = require 'util'
            "TypeError: \n#{util.inspect left, false, null} \n to \n #{util.inspect right, false, null}"
          err = typeErrorText preAnnotation.arguments[n], param.typeAnnotation
          hasError = true
          return reporter.add_error node, err
      param.typeAnnotation ?= preAnnotation.arguments[n]
      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: param.data
        typeAnnotation: param.typeAnnotation
    if hasError then return
  else
    node.parameters?.map (param, n) ->
      scope.addVar
        nodeType: 'variable'
        identifier:
          typeRef: param.data
        typeAnnotation: param.typeAnnotation ? ImplicitAnyAnnotation

  walk node.body, functionScope

  debug 'left', node.body.typeAnnotation
  debug 'right', node.typeAnnotation.returnType
  # debug 'rrrr', node.typeAnnotation
  node.body.typeAnnotation ?= ImplicitAnyAnnotation
  node.typeAnnotation.returnType ?= ImplicitAnyAnnotation

  unless isAcceptable scope, node.body.typeAnnotation, node.typeAnnotation.returnType
    typeErrorText = (left, right) ->
      util = require 'util'
      "TypeError: \n#{util.inspect left, false, null} \n to \n #{util.inspect right, false, null}"
    err = typeErrorText node.body.typeAnnotation, node.typeAnnotation.returnType
    return reporter.add_error node, err

  # debug 'function', node

  # debug 'func', node
  # node.typeAnnotation.identifier.arguments = args
  # if preAnnotation
  #   node.typeAnnotation.identifier = preAnnotation
  #   for param, index in node.parameters
  #     # Destructive
  #     if param.members
  #       for member in param.members
  #         # This
  #         if member.expression?.expression?.raw in ['@', 'this']
  #           t = functionScope.getThis(member.key.data)
  #           unless t?.identifier? then functionScope.addThis member.key.data, 'Any'
  #         # Var
  #         else
  #           if member.key?.data
  #             functionScope.addVar member.key.data, 'Any'
  #     # This
  #     else if param.expression?.raw in ['@', 'this']
  #       t = functionScope.getThis(param.memberName)
  #       if err = scope.checkAcceptableObject preAnnotation.arguments?[index], t?.identifier
  #         err = typeErrorText preAnnotation.arguments?[index], t?.identifier
  #         reporter.add_error node, err
  #       unless t?.identifier? then functionScope.addThis param.memberName, 'Any'
  #     # Var
  #     else
  #       functionScope.addVar param.data, (preAnnotation.arguments?[index] ? 'Any')

  # register arguments to function scope
  # TODO: DRY
  # if node.parameters?
  #   # example.
  #   #   f :: Int -> Int
  #   #   f: (n) -> n
  #   if preAnnotation
  #     node.typeAnnotation.identifier = preAnnotation
  #     for param, index in node.parameters
  #       # Destructive
  #       if param.members
  #         for member in param.members
  #           # This
  #           if member.expression?.expression?.raw in ['@', 'this']
  #             t = functionScope.getThis(member.key.data)
  #             unless t?.identifier? then functionScope.addThis member.key.data, 'Any'
  #           # Var
  #           else
  #             if member.key?.data
  #               functionScope.addVar member.key.data, 'Any'
  #       # This
  #       else if param.expression?.raw in ['@', 'this']
  #         t = functionScope.getThis(param.memberName)
  #         if err = scope.checkAcceptableObject preAnnotation.arguments?[index], t?.identifier
  #           err = typeErrorText preAnnotation.arguments?[index], t?.identifier
  #           reporter.add_error node, err
  #         unless t?.identifier? then functionScope.addThis param.memberName, 'Any'
  #       # Var
  #       else
  #         functionScope.addVar param.data, (preAnnotation.arguments?[index] ? 'Any')
  #   # example.
  #   #   f: (n) -> n
  #   else
  #     for param, index in node.parameters
  #       # Destructive
  #       if param.members
  #         for member in param.members
  #           # This
  #           if member.expression?.expression?.raw in ['@', 'this']
  #             t = functionScope.getThis(member.key.data)
  #             unless t?.identifier? then functionScope.addThis member.key.data, 'Any'
  #           # Var
  #           else
  #             if member.key?.data
  #               functionScope.addVar member.key.data, 'Any'
  #       # This
  #       else if param.expression?.raw in ['@', 'this']
  #         t = functionScope.getThis(param.memberName)
  #         unless t?.identifier? then functionScope.addThis param.memberName, 'Any'
  #       # Var
  #       else
  #         functionScope.addVar param.data, (param?.typeAnnotation?.identifier ? 'Any')


  # () :: Number -> 3
  # if node.typeAnnotation?.identifier?.returnType isnt 'Any'
  #   # last expr or single line expr
  #   last_expr =
  #     if node.body?.statements?.length # => Blcok
  #       node.body.statements?[node.body?.statements?.length-1]
  #     else # => Expr
  #       node.body

  #   # 明示的に宣言してある場合
  #   if err = scope.checkAcceptableObject(node.typeAnnotation?.identifier.returnType, last_expr?.typeAnnotation?.identifier)
  #     err = typeErrorText node.typeAnnotation?.identifier.returnType, last_expr?.typeAnnotation?.identifier
  #     return reporter.add_error node, err

  # else
  #   last_expr =
  #     if node.body?.statements?.length # => Blcok
  #       node.body.statements?[node.body?.statements?.length-1]
  #     else # => Expr
  #       node.body

  #   if node.typeAnnotation?
  #     node.typeAnnotation.identifier.returnType = last_expr?.typeAnnotation?.identifier

walkFunctionApplication = (node, scope) ->
  for arg in node.arguments
    walk arg, scope
  walk node.function, scope

  node.typeAnnotation = node.function.typeAnnotation?.returnType ? ImplicitAnyAnnotation
  debug 'FunctionApplication', node

  for arg, n in node.arguments
    left = node.function.typeAnnotation?.arguments?[n]
    right = arg?.typeAnnotation
    if left and right
      unless isAcceptable scope, left, right
        typeErrorText = (left, right) ->
          util = require 'util'
          "TypeError: \n#{util.inspect left, false, null} \n to \n #{util.inspect right, false, null}"
        err = typeErrorText left, right
        reoprter.add_error node, err

# Traverse all nodes
# Node -> void
walk = (node, scope) ->
  console.error 'walking node:', node?.className
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
    # For
    when (node.instanceof CS.ForIn) or (node.instanceof CS.ForOf) then walkFor node, scope
    # Primitives
    when node.instanceof CS.Primitives        then walkPrimitives node, scope
    # This
    when node.instanceof CS.This              then walkThis node, scope
    # Identifier
    when node.instanceof CS.Identifier        then walkIdentifier node, scope
    # ClassProto
    when node.instanceof CS.ClassProtoAssignOp then walkClassProtoAssignOp node, scope
    # MemberAccessOps TODO: imperfect
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
    when node.instanceof CS.AssignOp then walkAssignOp node, scope

module.exports = {checkNodes}
