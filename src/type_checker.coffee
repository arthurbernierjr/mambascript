console = {log: ->}
pj = try require 'prettyjson'
render = (obj) -> pj?.render obj

reporter = require './reporter'
CS = require './nodes'

{
  initializeGlobalTypes,
  Scope,
  ClassScope,
  FunctionScope
} = require './types'

# CS_AST -> Scope
g = window ? global
checkNodes = (cs_ast) ->
  return unless cs_ast.body?.statements?
  # console.log "AST =================="
  # console.log render cs_ast
  # console.log '================== AST'

  if g._root_
    root = g._root_
  else
    g._root_ = root = new Scope
    root.name = 'root'

    for i in ['global', 'exports', 'module']
      root.addVar i, 'Any', true
    initializeGlobalTypes(root)

  walk cs_ast, root
  # console.log 'scope ====================='
  # reporter.dump root
  # console.log root.nodes[0]
  return root

walk_struct = (node, scope) ->
  if node.name instanceof Object
    scope.addType node.name._base_, node.expr, node.name._templates_
  else
    scope.addType node.name, node.expr

walk_vardef = (node, scope) ->
  # avoid 'constructor' because it's property has special action on EcmaScript
  symbol = if node.name is 'constructor' then '_constructor_' else node.name
  if scope instanceof ClassScope
    scope.addThis symbol, node.expr
  else
    scope.addVar symbol, node.expr

walk_program = (node, scope) ->
  walk node.body.statements, scope
  node.annotation = type: 'Program'

walk_block = (node, scope) ->
  walk node.statements, scope
  last_annotation = (node.statements[node.statements.length-1])?.annotation
  node.annotation = last_annotation

walk_return = (node, scope) ->
  walk node.expression, scope
  if node.expression?.annotation?.type?
    scope.addReturnable node.expression.annotation.type
    node.annotation = node.expression.annotation

walk_binOp = (node, scope) ->
  walk node.left, scope
  walk node.right, scope

  left_type = node.left?.annotation?.type
  right_type = node.right?.annotation?.type

  if left_type and right_type
    # rough...
    if left_type is 'String' or right_type is 'String'
      node.annotation = type: 'String'
    else if left_type is right_type
      node.annotation = type: left_type
  else
    node.annotation = type:'Any'

walk_conditional = (node, scope) ->
  # condition expr
  walk node.condition, scope #=> Expr

  # else if
  walk node.consequent, scope #=> Block

  # else
  if node.alternate?
    walk node.alternate, scope #=> Block

  # if node.alternate doesn't exist, then return type is Undefined
  alternate_annotation = (node.alternate?.annotation) ? (type: 'Undefined')

  possibilities = []
  for annotation in [node.consequent?.annotation, alternate_annotation] when annotation?
    if annotation.type?.possibilities?
      possibilities.push type for type in annotation.type.possibilities
        
    else if annotation.type?
      possibilities.push annotation.type

  node.annotation = type: {possibilities}

walk_switch = (node, scope) ->
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
  alternate_annotation = (node.alternate?.annotation) ? (type: 'Undefined')

  possibilities = []
  for c in node.cases when c.annotation?
    possibilities.push c.consequent.annotation

  possibilities.push alternate_annotation.type
  node.annotation = type: {possibilities}

walk_newOp = (node, scope) ->
  for arg in node.arguments
    walk arg, scope
  Type = scope.getTypeInScope node.ctor.data
  if Type
    _args_ = node.arguments?.map (arg) -> arg.annotation?.type
    if err = scope.checkAcceptableObject Type.type._constructor_, {_args_: (_args_ ? []), _return_: 'Any'}
      return reporter.add_error node, err

  node.annotation = type: Type?.type

walk_for = (node, scope) ->
  walk node.target, scope

  if node.valAssignee?
    scope.addVar node.valAssignee.data, (node.valAssignee?.annotation?.type) ? 'Any'

  if node.keyAssignee?
    # must be number or string
    scope.addVar node.keyAssignee.data, (node.keyAssignee?.annotation?.type) ? 'Any'

  if node.valAssignee?
    # ForIn
    if node.target.annotation?.type?.array?
      if err = scope.checkAcceptableObject(node.valAssignee.annotation.type, node.target.annotation.type.array) 
        return reporter.add_error node, err

    # ForOf
    else if node.target?.annotation?.type instanceof Object
      if node.target.annotation.type instanceof Object
        for nop, type of node.target.annotation.type
          if err = scope.checkAcceptableObject(node.valAssignee.annotation.type, type)
            return reporter.add_error node, err

  # check body
  walk node.body, scope #=> Block
  node.annotation = node.target?.annotation

  # remove after iter
  delete scope._vars[node.valAssignee?.data]
  delete scope._vars[node.keyAssignee?.data]

walk_classProtoAssignOp = (node, scope) ->
  left  = node.assignee
  right = node.expression
  symbol = left.data

  walk left, scope
  if (right.instanceof CS.Function) and scope.getThis(symbol)
    walk_function right, scope, scope.getThis(symbol).type
  else
    walk right, scope

  symbol = left.data

  if right.annotation?
    scope.addThis symbol, right.annotation.type

walk_assignOp = (node, scope) ->
  pre_registered_annotation = node.assignee.annotation #TODO: dirty...

  left  = node.assignee
  right = node.expression
  symbol = left.data

  walk left,  scope

  if right.instanceof?(CS.Function) and scope.getVarInScope(symbol)
    walk_function right, scope, scope.getVarInScope(symbol).type
  else if right.instanceof?(CS.Function) and pre_registered_annotation
    walk_function right, scope, left.annotation.type
  else
    walk right, scope

  
  # Member
  if left.instanceof CS.MemberAccessOp
    if left.expression.instanceof CS.This
      T = scope.getThis(left.memberName)
      left.annotation = T if T?
      if T?
        if err = scope.checkAcceptableObject(left.annotation.type, right.annotation.type)
          return reporter.add_error node, err

      return
    # return if left.expression.raw is '@' # ignore @ yet
    else if left.annotation?.type? and right.annotation?.type?
      if left.annotation.type isnt 'Any'
        if err = scope.checkAcceptableObject(left.annotation.type, right.annotation.type)
          return reporter.add_error node, err

  # Identifier
  else if left.instanceof CS.Identifier
    symbol = left.data

    if scope.getVarInScope(symbol) and pre_registered_annotation
      return report.add_error node, 'double bind: '+ symbol

    scope.addVar symbol, left.annotation.type

    # 左辺に型宣言が存在する
    if left.annotation.type?
      # 明示的なAnyは全て受け入れる
      # x :: Any = "any instance"
      if left.annotation.type is 'Any'
        scope.addVar symbol, 'Any', true
      else 
        if right.annotation? and left.annotation?
          if err = scope.checkAcceptableObject(left.annotation.type, right.annotation.type)
            return reporter.add_error node, err
        scope.addVar symbol, left.annotation.type
  # Vanilla CS
  else
    scope.addVar symbol, 'Any'

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
  node.annotation ?=
    type: 'String'
    primitive: true

walk_int = (node, scope) ->
  node.annotation ?=
    type: 'Int'
    primitive: true

walk_float = (node, scope) ->
  node.annotation ?=
    type: 'Float'
    primitive: true

walk_numbers = (node, scope) ->
  node.annotation ?=
    type: 'Number'
    primitive: true

walk_bool = (node, scope) ->
  node.annotation ?=
    type: 'Boolean'
    primitive: true

walk_identifier = (node, scope) ->
  if scope.getVarInScope(node.data)
    Var = scope.getVarInScope(node.data)
    node.annotation = type: Var?.type
  else
    node.annotation ?=
      type: 'Any'

walk_this = (node, scope) ->
  type = {}
  for key, val of scope._this
    type[key] = val.type
  node.annotation ?= {type}

walk_memberAccess = (node, scope) ->
  # hoge?.fuga
  if node.instanceof CS.SoakedMemberAccessOp
    walk node.expression, scope
    type = scope.extendTypeLiteral(node.expression.annotation?.type)
    if type?
      node.annotation =
        type:
          possibilities:['Undefined', type[node.memberName]]
    else
      node.annotation = type: 'Any'

  else if node.instanceof CS.MemberAccessOp
    walk node.expression, scope
    type = scope.extendTypeLiteral(node.expression.annotation?.type)
    if type?
      node.annotation = type: type[node.memberName]
    else
      node.annotation = type: 'Any'

walk_arrayInializer = (node, scope) ->
  walk node.members, scope

  node.annotation ?=
    type: {array: (node.members?.map (m) -> m.annotation?.type)}

walk_range = (node, scope) ->
  node.annotation = type : {array: 'Number'}

walk_objectInitializer = (node, scope) ->

  obj = {}
  nextScope = new Scope scope
  nextScope.name = 'object'

  for {expression, key} in node.members when key?
    walk expression, nextScope
    obj[key.data] = expression.annotation?.type

  node.annotation ?=
    type: obj

walk_class = (node, scope) ->
  classScope = new ClassScope scope

  # collect @values first 
  if node.body?.statements?
    for statement in node.body.statements when statement.type is 'vardef'
      walk_vardef statement, classScope
  
  # constructor
  if node.ctor?
    constructorScope = new FunctionScope classScope
    constructorScope._this = classScope._this # delegate this scope
    # arguments
    if node.ctor.expression.parameters?
      # vardef exists: constructor :: X, Y, Z
      if constructorScope.getThis('_constructor_')
        predef = constructorScope.getThis('_constructor_').type
        for param, index in node.ctor.expression.parameters when param?
          walk param, constructorScope
          constructorScope.addVar param.data, (predef._args_?[index] ? 'Any')
      else
        for param, index in node.ctor.expression.parameters when param?
          walk param, constructorScope
          constructorScope.addVar param.data, (param?.annotation?.type ? 'Any')

    # constructor body
    if node.ctor.expression.body?.statements?
      for statement in node.ctor.expression.body.statements
        walk statement, constructorScope

  # walk
  if node.body?.statements?
    for statement in node.body.statements when statement.type isnt 'vardef'
      walk statement, classScope

  if node.nameAssignee?.data
    obj = {}
    for fname, val of classScope._this
      obj[fname] = val.type
    scope.addType node.nameAssignee.data, obj

# Node * Scope * Type
# predef :: Type defined at assignee
walk_function = (node, scope, predef = null) ->
  _args_ = node.parameters?.map (param) -> param.annotation?.type ? 'Any'

  node.annotation.type._args_ = _args_

  functionScope = new Scope scope
  functionScope._name_ = 'function'

  if scope instanceof ClassScope
    functionScope._this = scope._this

  # register arguments to function scope
  if node.parameters?
    # if exist pre-defined parameters, override inferred object
    if predef
      node.annotation.type = predef
      for param, index in node.parameters
        functionScope.addVar param.data, (predef._args_?[index] ? 'Any')
    else
      for param, index in node.parameters
        functionScope.addVar param.data, (param?.annotation?.type ? 'Any')

  walk node.body, functionScope

  # () :: Number -> 3
  if node.annotation?.type?._return_ isnt 'Any'
    # last expr or single line expr
    last_expr =
      if node.body?.statements?.length # => Blcok
        node.body.statements?[node.body?.statements?.length-1]
      else # => Expr
        node.body

    # 明示的に宣言してある場合
    if err = scope.checkAcceptableObject(node.annotation?.type._return_, last_expr?.annotation?.type)
      return reporter.add_error node, err

  else
    last_expr =
      if node.body?.statements?.length # => Blcok
        node.body.statements?[node.body?.statements?.length-1]
      else # => Expr
        node.body

    if node.annotation?
      node.annotation.type._return_ = last_expr?.annotation?.type

walk_functionApplication = (node, scope) ->
  for arg in node.arguments
    walk arg, scope
  walk node.function, scope
  node.annotation = type: (node.function.annotation?.type?._return_)

  if node.function.annotation
    _args_ = node.arguments?.map (arg) -> arg.annotation?.type
    if err = scope.checkAcceptableObject node.function.annotation.type, {_args_: (_args_ ? []), _return_: 'Any'}
      return reporter.add_error node, err

# Traverse all nodes
# Node -> void
walk = (node, scope) ->
  console.log '---', node?.className, '---' #, node?.raw
  switch
    # undefined(mayby null body)
    when not node? then return
    # Nodes Array
    when node.length?                    then  walk s, scope for s in node
    # Struct
    # Dirty hack on Number
    when node.type is 'struct'           then walk_struct node, scope
    when node.type is 'vardef'           then walk_vardef node, scope
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
    # left.annotation.type
    when node.instanceof CS.AssignOp then walk_assignOp node, scope

module.exports = {checkNodes}
