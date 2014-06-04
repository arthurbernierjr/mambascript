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

pj = try require 'prettyjson'
render = (obj) -> pj?.render obj
{debug} = require './helpers'
reporter = require './reporter'
CS = require './nodes'
_ = require 'lodash'

identifier = (name) ->
  typeRef: name

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

# isAcceptablePrimitiveSymbol :: TypeAnnotation * TypeAnnotation -> Boolean
isAcceptablePrimitiveSymbol = (left, right) ->
  if left.nodeType isnt 'primitiveIdentifier'
    throw 'left is not primitive'

  return true if left.identifier.typeRef is 'Any'
  # type check
  return false if left.identifier.typeRef isnt right?.identifier?.typeRef
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
    # debug 'left', lprop.typeAnnotation
    debug 'right', rprop.typeAnnotation

    # return true
    unless rprop? then return false

    return isAcceptable scope, lprop.typeAnnotation, rprop.typeAnnotation

# isAcceptableFunction :: Scope * TypeAnnotation * TypeAnnotation -> Boolean
isAcceptableFunctionType = (scope, left, right) ->
  # debug 'isAcceptableFunction left', left
  # debug 'isAcceptableFunction right', right
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
  debug 'left', left
  debug 'right', right
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

  # debug 'leftAnnotation', leftAnnotation
  # debug 'rightAnnotation', rightAnnotation

  # Grasp if left is any
  if leftAnnotation.nodeType is 'primitiveIdentifier'
    if leftAnnotation.identifier.typeRef is 'Any'
      return true

  if leftAnnotation.nodeType is rightAnnotation.nodeType is 'members'
    return isAcceptableStruct scope, leftAnnotation, rightAnnotation
  if leftAnnotation.nodeType is rightAnnotation.nodeType is 'primitiveIdentifier'
    return isAcceptablePrimitiveSymbol leftAnnotation, rightAnnotation
  if leftAnnotation.nodeType is rightAnnotation.nodeType is 'functionType'
    return isAcceptableFunctionType scope, leftAnnotation, rightAnnotation

# isAcceptable :: Types.Scope * Type * Type -> ()
checkType = (scope, left, right) ->
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

    for i in ['global', 'exports', 'module']
      root.addVar i, 'Any', true
    initializeGlobalTypes(root)

  # debug 'root', cs_ast
  walk cs_ast, root
  return root

walk_struct = (node, scope) ->
  # debug node
  scope.addStructType node

walk_vardef = (node, scope) ->
  return # TODO
  # avoid 'constructor' because it's property has special action on EcmaScript
  symbol = if node.name is 'constructor' then '_constructor_' else node.name
  if scope instanceof ClassScope
    scope.addThis symbol, node.expr
  else
    scope.addVar symbol, node.expr

walk_program = (node, scope) ->
  walk node.body.statements, scope
  node.typeAnnotation = identifier: 'Program'

walk_block = (node, scope) ->
  walk node.statements, scope
  last_typeAnnotation = (node.statements[node.statements.length-1])?.typeAnnotation
  node.typeAnnotation = last_typeAnnotation

walk_return = (node, scope) ->
  return # TODO
  walk node.expression, scope
  if node.expression?.typeAnnotation?.identifier?
    scope.addReturnable node.expression.typeAnnotation.identifier
    node.typeAnnotation = node.expression.typeAnnotation

walk_binOp = (node, scope) ->
  return # TODO
  walk node.left, scope
  walk node.right, scope

  left_type = node.left?.typeAnnotation?.identifier
  right_type = node.right?.typeAnnotation?.identifier

  if left_type and right_type
    # rough...
    if left_type is 'String' or right_type is 'String'
      node.typeAnnotation = identifier: 'String'
    else if left_type is 'Int' and right_type is 'Int'
      node.typeAnnotation = identifier: 'Int'
    else if left_type in ['Int', 'Float'] and right_type in ['Int', 'Float']
      node.typeAnnotation = identifier: 'Float'
    else if left_type in ['Int', 'Float', 'Number'] and right_type in ['Int', 'Float', 'Number']
      node.typeAnnotation = identifier: 'Number'
    else if left_type is right_type
      node.typeAnnotation = identifier: left_type
  else
    node.typeAnnotation = identifier:'Any'

walk_conditional = (node, scope) ->
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

walk_switch = (node, scope) ->
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

walk_newOp = (node, scope) ->
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

walk_for = (node, scope) ->
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
  delete scope._vars[node.valAssignee?.data]
  delete scope._vars[node.keyAssignee?.data]

walk_classProtoAssignOp = (node, scope) ->
  return # TODO
  left  = node.assignee
  right = node.expression
  symbol = left.data

  walk left, scope
  if (right.instanceof CS.Function) and scope.getThis(symbol)
    walk_function right, scope, scope.getThis(symbol).identifier
  else
    walk right, scope

  symbol = left.data

  if right.typeAnnotation?
    scope.addThis symbol, right.typeAnnotation.identifier

walk_assignOp = (node, scope) ->
  left  = node.assignee
  right = node.expression
  symbol = left.data

  preRegisteredTypeAnnotation = left.typeAnnotation #TODO: dirty...

  walk left, scope

  # TODO: refactor as functionTypeCheck
  if preRegisteredTypeAnnotation and (right.typeAnnotation?.identifier?.identifier is left.typeAnnotation?.identifier?.identifier is 'Function')
    if scope.checkAcceptableObject(left.typeAnnotation.identifier.returnType, right.typeAnnotation.identifier.returnType)
      err = typeErrorText left.typeAnnotation.identifier.returnType, right.typeAnnotation.identifier.returnType
      return reporter.add_error node, err
    for arg, n in left.typeAnnotation.identifier.arguments
      if scope.checkAcceptableObject(left.typeAnnotation.identifier.arguments[n]?.identifier, right.typeAnnotation.identifier.arguments[n]?.identifier)
        err = typeErrorText left.typeAnnotation.identifier, right.typeAnnotation.identifier
        return reporter.add_error node, err

  if right.instanceof?(CS.Function) and scope.getVarInScope(symbol)
    walk_function right, scope, scope.getVarInScope(symbol).identifier
  else if right.instanceof?(CS.Function) and preRegisteredTypeAnnotation
    walk_function right, scope, left.typeAnnotation.identifier
  else
    walk right, scope

  # Array initializer
  if left.instanceof CS.ArrayInitialiser
    for member, index in left.members when member.data?
      l = left.typeAnnotation?.identifier?.array?[index]
      r = right.typeAnnotation?.identifier?.array?[index]
      if err = scope.checkAcceptableObject l, r
        err = typeErrorText l, r
        reporter.add_error node, err
      if l
        scope.addVar member.data, l, true
      else
        scope.addVar member.data, "Any", false

  # Destructive
  else if left?.members?
    for member in left.members when member.key?.data?
      if scope.getVarInScope member.key.data
        l_type = scope.getVarInScope(member.key.data).identifier
        if err = scope.checkAcceptableObject l_type, right.typeAnnotation?.identifier?[member.key.data]
          err = typeErrorText l_type, right.typeAnnotation?.identifier?[member.key.data]
          reporter.add_error node, err
      else
        scope.addVar member.key.data, 'Any', false

  # Member
  else if left.instanceof CS.MemberAccessOp
    if left.expression.instanceof CS.This
      T = scope.getThis(left.memberName)
      left.typeAnnotation = T if T?
      if T?
        if err = scope.checkAcceptableObject(left.typeAnnotation.identifier, right.typeAnnotation.identifier)
          err = typeErrorText left.typeAnnotation.identifier, right.typeAnnotation.identifier
          reporter.add_error node, err
    # return if left.expression.raw is '@' # ignore @ yet
    else if left.typeAnnotation?.identifier? and right.typeAnnotation?.identifier?
      if left.typeAnnotation.identifier isnt 'Any'
        if err = scope.checkAcceptableObject(left.typeAnnotation.identifier, right.typeAnnotation.identifier)
          err = typeErrorText left.typeAnnotation.identifier, right.typeAnnotation.identifier
          return reporter.add_error node, err

  # Identifier
  else if left.instanceof CS.Identifier
    if scope.getVarInScope(symbol) and preRegisteredTypeAnnotation
      return reporter.add_error node, 'double bind: '+ symbol

    if left.typeAnnotation? and right.typeAnnotation?
      if left.typeAnnotation?.properties?
        unless isAcceptable scope, left.typeAnnotation, right.typeAnnotation
          err = typeErrorText left.typeAnnotation, right.typeAnnotation
          return reporter.add_error node, err
      else
        unless isAcceptable scope, left.typeAnnotation, right.typeAnnotation
          err = typeErrorText left.typeAnnotation, right.typeAnnotation
          return reporter.add_error node, err

    if (!preRegisteredTypeAnnotation) and right.typeAnnotation?.explicit
      scope.addVar symbol, right.typeAnnotation.identifier, true
    else
      debug '---dfa-fdsa-f-', left
      left.typeAnnotation ?= ImplicitAnyAnnotation
      scope.addVar symbol, left.typeAnnotation.identifier, true

  # Vanilla CS
  else
    scope.addVar symbol, 'Any', false

walk_primitives = (node, scope) ->
  switch
    # String
    when node.instanceof CS.String  then walk_string node, scope
    # Bool
    when node.instanceof CS.Bool    then walk_bool node, scope
    # Number
    when node.instanceof CS.Int then walk_int node, scope
    when node.instanceof CS.Float then walk_float node, scope
    when node.instanceof CS.Numbers then walk_numbers node, scope

walk_string = (node, scope) ->
  node.typeAnnotation ?=
    implicit: true
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'String'

walk_int = (node, scope) ->
  node.typeAnnotation ?=
    implicit: true
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Int'

walk_bool = (node, scope) ->
  return # TODO
  node.typeAnnotation ?=
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Boolean'

walk_float = (node, scope) ->
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

walk_numbers = (node, scope) ->
  return # TODO
  node.typeAnnotation ?=
    nodeType: 'primitiveIdentifier'
    isPrimitive: true
    identifier:
      typeRef: 'Number'
    heritages:
      extend:
        identifier:
          typeRef: 'Float'

walk_identifier = (node, scope) ->
  # debug 'Identifier', node
  symbolName = node.data
  if scope.getVarInScope(symbolName)
    return # TODO
    Var = scope.getVarInScope(symbolName)
    node.typeAnnotation = identifier: Var?.identifier, explicit: Var?.explicit
  else
    node.typeAnnotation ?= ImplicitAnyAnnotation

walk_this = (node, scope) ->
  return # TODO
  identifier = {}
  for key, val of scope._this
    identifier[key] = val.identifier
  node.typeAnnotation ?= {identifier}

walk_memberAccess = (node, scope) ->
  return # TODO
  # hoge?.fuga
  if node.instanceof CS.SoakedMemberAccessOp
    walk node.expression, scope
    identifier = scope.extendTypeLiteral(node.expression.typeAnnotation?.identifier)
    if identifier?
      node.typeAnnotation =
        identifier:
          possibilities:['Undefined', identifier[node.memberName]]
    else
      node.typeAnnotation = identifier: 'Any', explicit: false

  else if node.instanceof CS.MemberAccessOp
    walk node.expression, scope
    identifier = scope.extendTypeLiteral(node.expression.typeAnnotation?.identifier)
    if identifier?
      node.typeAnnotation = identifier: identifier[node.memberName], explicit: true
    else
      node.typeAnnotation = identifier: 'Any', explicit: false

walk_arrayInializer = (node, scope) ->
  return # TODO
  walk node.members, scope

  node.typeAnnotation ?=
    identifier: {array: (node.members?.map (m) -> m.typeAnnotation?.identifier)}

walk_range = (node, scope) ->
  return # TODO
  node.typeAnnotation = identifier : {array: 'Number'}


walk_objectInitializer = (node, scope) ->
  # debug 'ObjectInitialiser', node

  obj = {}
  nextScope = new Scope scope
  nextScope.name = 'object'

  props = []

  for {expression, key} in node.members when key?
    walk expression, nextScope
    props.push
      implicit: true
      identifier: identifier(key.data)
      nodeType: 'identifier'
      typeAnnotation: expression.typeAnnotation

  node.typeAnnotation ?=
    properties: props
    nodeType: 'members'
    implicit: true
    heritages: # TODO: check scheme later
      extend: identifier('Object')

  # debug 'ObjectInitialiser', node.typeAnnotation


walk_class = (node, scope) ->
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
      walk_vardef statement, classScope

  # constructor
  if node.ctor?
    constructorScope = new FunctionScope classScope
    constructorScope._this = classScope._this # delegate this scope
    # arguments
    if node.ctor.expression.parameters?
      # vardef exists: constructor :: X, Y, Z
      if constructorScope.getThis('_constructor_')
        predef = constructorScope.getThis('_constructor_').identifier
        for param, index in node.ctor.expression.parameters when param?
          walk param, constructorScope
          constructorScope.addVar param.data, (predef.arguments?[index] ? 'Any')
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
# predef :: Type defined at assignee
# walk_function :: Node * Scope * TypeAnnotation -> ()
walk_function = (node, scope, predef = null) ->
  # return # TODO
  args = node.parameters?.map (param) -> param.typeAnnotation?.identifier ? 'Any'
  debug 'func', node
  # node.typeAnnotation.identifier.arguments = args
  functionScope = new Scope scope

  if scope instanceof ClassScope
    functionScope._this = scope._this

  # register arguments to function scope
  # TODO: DRY
  # if node.parameters?
  #   # example.
  #   #   f :: Int -> Int
  #   #   f: (n) -> n
  #   if predef
  #     node.typeAnnotation.identifier = predef
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
  #         if err = scope.checkAcceptableObject predef.arguments?[index], t?.identifier
  #           err = typeErrorText predef.arguments?[index], t?.identifier
  #           reporter.add_error node, err
  #         unless t?.identifier? then functionScope.addThis param.memberName, 'Any'
  #       # Var
  #       else
  #         functionScope.addVar param.data, (predef.arguments?[index] ? 'Any')
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

  walk node.body, functionScope

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

walk_functionApplication = (node, scope) ->
  return # TODO
  for arg in node.arguments
    walk arg, scope
  walk node.function, scope
  node.typeAnnotation = identifier: (node.function.typeAnnotation?.identifier?.returnType)

  if node.function.typeAnnotation
    args = node.arguments?.map (arg) -> arg.typeAnnotation?.identifier
    if err = scope.checkAcceptableObject node.function.typeAnnotation.identifier, {arguments: (args ? []), returnType: 'Any'}
      err = typeErrorText node.function.typeAnnotation.identifier, {arguments: (args ? []), returnType: 'Any'}
      return reporter.add_error node, err

# Traverse all nodes
# Node -> void
walk = (node, scope) ->
  # debug 'walk', node
  switch
    # undefined(mayby null body)
    when not node? then return
    # Nodes Array
    when node.length?                    then  walk s, scope for s in node
    # Struct
    # Dirty hack on Number
    when node.nodeType is 'struct'       then walk_struct node, scope
    when node.nodeType is 'vardef'       then walk_vardef node, scope
    # Program
    when node.instanceof CS.Program      then walk_program node, scope
    # Block
    when node.instanceof CS.Block        then walk_block node, scope
    # Retrun
    when node.instanceof CS.Return       then  walk_return node, scope
    # New
    when node.instanceof CS.NewOp        then  walk_newOp node, scope
    # BinaryOperator
    when node.instanceof(CS.PlusOp) or node.instanceof(CS.MultiplyOp) or node.instanceof(CS.DivideOp) or node.instanceof(CS.SubtractOp)
      walk_binOp node, scope

    # === Controlle flow ===
    # Switch
    when node.instanceof CS.Switch then walk_switch node, scope
    # If
    when node.instanceof CS.Conditional  then walk_conditional node, scope
    # For
    when (node.instanceof CS.ForIn) or (node.instanceof CS.ForOf) then walk_for node, scope
    # Primitives
    when node.instanceof CS.Primitives        then walk_primitives node, scope
    # This
    when node.instanceof CS.This              then walk_this node, scope
    # Identifier
    when node.instanceof CS.Identifier        then walk_identifier node, scope
    # ClassProto
    when node.instanceof CS.ClassProtoAssignOp then walk_classProtoAssignOp node, scope
    # MemberAccessOps TODO: imperfect
    when node.instanceof CS.MemberAccessOps   then walk_memberAccess node, scope
    # Array
    when node.instanceof CS.ArrayInitialiser  then walk_arrayInializer node, scope
    # Range
    when node.instanceof CS.Range             then walk_range node, scope
    # Object
    when node.instanceof CS.ObjectInitialiser then walk_objectInitializer node, scope
    # Class
    when node.instanceof CS.Class             then walk_class node, scope
    # Function
    when node.instanceof CS.Function          then walk_function node, scope
    # FunctionApplication
    when node.instanceof CS.FunctionApplication then walk_functionApplication node, scope
    # left.typeAnnotation.identifier
    when node.instanceof CS.AssignOp then walk_assignOp node, scope

module.exports = {checkNodes}
