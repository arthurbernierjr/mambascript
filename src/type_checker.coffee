pj = try require 'prettyjson'
render = (obj) -> pj?.render obj
{debug} = require './helpers'
reporter = require './reporter'
CS = require './nodes'

typeErrorText = (left, right) ->
  "TypeError: #{JSON.stringify left} expect to #{JSON.stringify right}"

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
  if g._root_
    root = g._root_
  else
    g._root_ = root = new Scope
    root.name = 'root'

    for i in ['global', 'exports', 'module']
      root.addVar i, 'Any', true
    initializeGlobalTypes(root)

  walk cs_ast, root
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
  node.annotation = dataType: 'Program'

walk_block = (node, scope) ->
  walk node.statements, scope
  last_annotation = (node.statements[node.statements.length-1])?.annotation
  node.annotation = last_annotation

walk_return = (node, scope) ->
  walk node.expression, scope
  if node.expression?.annotation?.dataType?
    scope.addReturnable node.expression.annotation.dataType
    node.annotation = node.expression.annotation

walk_binOp = (node, scope) ->
  walk node.left, scope
  walk node.right, scope

  left_type = node.left?.annotation?.dataType
  right_type = node.right?.annotation?.dataType

  if left_type and right_type
    # rough...
    if left_type is 'String' or right_type is 'String'
      node.annotation = dataType: 'String'
    else if left_type is 'Int' and right_type is 'Int'
      node.annotation = dataType: 'Int'
    else if left_type in ['Int', 'Float'] and right_type in ['Int', 'Float']
      node.annotation = dataType: 'Float'
    else if left_type in ['Int', 'Float', 'Number'] and right_type in ['Int', 'Float', 'Number']
      node.annotation = dataType: 'Number'
    else if left_type is right_type
      node.annotation = dataType: left_type
  else
    node.annotation = dataType:'Any'

walk_conditional = (node, scope) ->
  # condition expr
  walk node.condition, scope #=> Expr

  # else if
  walk node.consequent, scope #=> Block

  # else
  if node.alternate?
    walk node.alternate, scope #=> Block

  # if node.alternate doesn't exist, then return type is Undefined
  alternate_annotation = (node.alternate?.annotation) ? (dataType: 'Undefined')

  possibilities = []
  for annotation in [node.consequent?.annotation, alternate_annotation] when annotation?
    if annotation.dataType?.possibilities?
      possibilities.push dataType for dataType in annotation.dataType.possibilities

    else if annotation.dataType?
      possibilities.push annotation.dataType

  node.annotation = dataType: {possibilities}

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
  alternate_annotation = (node.alternate?.annotation) ? (dataType: 'Undefined')

  possibilities = []
  for c in node.cases when c.annotation?
    possibilities.push c.consequent.annotation

  possibilities.push alternate_annotation.dataType
  node.annotation = dataType: {possibilities}

walk_newOp = (node, scope) ->
  for arg in node.arguments
    walk arg, scope
  Type = scope.getTypeInScope node.ctor.data
  if Type
    _args_ = node.arguments?.map (arg) -> arg.annotation?.dataType
    if err = scope.checkAcceptableObject Type.dataType._constructor_, {_args_: (_args_ ? []), returnType: 'Any'}
      err = typeErrorText Type.dataType._constructor_, {_args_: (_args_ ? []), returnType: 'Any'}
      return reporter.add_error node, err

  node.annotation = dataType: Type?.dataType

walk_for = (node, scope) ->
  walk node.target, scope

  if node.valAssignee?
    scope.addVar node.valAssignee.data, (node.valAssignee?.annotation?.dataType) ? 'Any'

  if node.keyAssignee?
    # must be number or string
    scope.addVar node.keyAssignee.data, (node.keyAssignee?.annotation?.dataType) ? 'Any'

  if node.valAssignee?
    # ForIn
    if node.target.annotation?.dataType?.array?
      if err = scope.checkAcceptableObject(node.valAssignee.annotation.dataType, node.target.annotation.dataType.array)
        err = typeErrorText node.valAssignee.annotation.dataType, node.target.annotation.dataType.array
        return reporter.add_error node, err

    # ForOf
    else if node.target?.annotation?.dataType instanceof Object
      if node.target.annotation.dataType instanceof Object
        for nop, dataType of node.target.annotation.dataType
          if err = scope.checkAcceptableObject(node.valAssignee.annotation.dataType, dataType)
            err = typeErrorText node.valAssignee.annotation.dataType, dataType
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
    walk_function right, scope, scope.getThis(symbol).dataType
  else
    walk right, scope

  symbol = left.data

  if right.annotation?
    scope.addThis symbol, right.annotation.dataType

walk_assignOp = (node, scope) ->
  left  = node.assignee
  right = node.expression

  pre_registered_annotation = left.annotation #TODO: dirty...

  symbol = left.data
  walk left,  scope

  # TODO: refactor as functionTypeCheck
  if pre_registered_annotation and (right.annotation?.dataType?.dataType is left.annotation?.dataType?.dataType is 'Function')
    if scope.checkAcceptableObject(left.annotation.dataType.returnType, right.annotation.dataType.returnType)
      err = typeErrorText left.annotation.dataType.returnType, right.annotation.dataType.returnType
      return reporter.add_error node, err
    for arg, n in left.annotation.dataType._args_
      if scope.checkAcceptableObject(left.annotation.dataType._args_[n]?.dataType, right.annotation.dataType._args_[n]?.dataType)
        err = typeErrorText left.annotation.dataType, right.annotation.dataType
        return reporter.add_error node, err

  if right.instanceof?(CS.Function) and scope.getVarInScope(symbol)
    walk_function right, scope, scope.getVarInScope(symbol).dataType
  else if right.instanceof?(CS.Function) and pre_registered_annotation
    walk_function right, scope, left.annotation.dataType
  else
    walk right, scope

  # Array initializer
  if left.instanceof CS.ArrayInitialiser
    for member, index in left.members when member.data?
      l = left.annotation?.dataType?.array?[index]
      r = right.annotation?.dataType?.array?[index]
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
        l_type = scope.getVarInScope(member.key.data).dataType
        if err = scope.checkAcceptableObject l_type, right.annotation?.dataType?[member.key.data]
          err = typeErrorText l_type, right.annotation?.dataType?[member.key.data]
          reporter.add_error node, err
      else
        scope.addVar member.key.data, 'Any', false

  # Member
  else if left.instanceof CS.MemberAccessOp
    if left.expression.instanceof CS.This
      T = scope.getThis(left.memberName)
      left.annotation = T if T?
      if T?
        if err = scope.checkAcceptableObject(left.annotation.dataType, right.annotation.dataType)
          err = typeErrorText left.annotation.dataType, right.annotation.dataType
          reporter.add_error node, err
    # return if left.expression.raw is '@' # ignore @ yet
    else if left.annotation?.dataType? and right.annotation?.dataType?
      if left.annotation.dataType isnt 'Any'
        if err = scope.checkAcceptableObject(left.annotation.dataType, right.annotation.dataType)
          err = typeErrorText left.annotation.dataType, right.annotation.dataType
          return reporter.add_error node, err

  # Identifier
  else if left.instanceof CS.Identifier
    if scope.getVarInScope(symbol) and pre_registered_annotation
      return reporter.add_error node, 'double bind: '+ symbol

    if left.annotation.dataType? and right.annotation?
      if err = scope.checkAcceptableObject(left.annotation.dataType, right.annotation.dataType)
        err = typeErrorText left.annotation.dataType, right.annotation.dataType
        return reporter.add_error node, err

    if (!pre_registered_annotation) and right.annotation?.explicit
      scope.addVar symbol, right.annotation.dataType, true
    else
      scope.addVar symbol, left.annotation.dataType, true

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
  node.annotation ?=
    dataType: 'String'
    primitive: true

walk_int = (node, scope) ->
  node.annotation ?=
    dataType: 'Int'
    primitive: true

walk_float = (node, scope) ->
  node.annotation ?=
    dataType: 'Float'
    primitive: true

walk_numbers = (node, scope) ->
  node.annotation ?=
    dataType: 'Number'
    primitive: true

walk_bool = (node, scope) ->
  node.annotation ?=
    dataType: 'Boolean'
    primitive: true

walk_identifier = (node, scope) ->
  if scope.getVarInScope(node.data)
    Var = scope.getVarInScope(node.data)
    node.annotation = dataType: Var?.dataType, explicit: Var?.explicit
  else
    node.annotation ?=
      dataType: 'Any'

walk_this = (node, scope) ->
  dataType = {}
  for key, val of scope._this
    dataType[key] = val.dataType
  node.annotation ?= {dataType}

walk_memberAccess = (node, scope) ->
  # hoge?.fuga
  if node.instanceof CS.SoakedMemberAccessOp
    walk node.expression, scope
    dataType = scope.extendTypeLiteral(node.expression.annotation?.dataType)
    if dataType?
      node.annotation =
        dataType:
          possibilities:['Undefined', dataType[node.memberName]]
    else
      node.annotation = dataType: 'Any', explicit: false

  else if node.instanceof CS.MemberAccessOp
    walk node.expression, scope
    dataType = scope.extendTypeLiteral(node.expression.annotation?.dataType)
    if dataType?
      node.annotation = dataType: dataType[node.memberName], explicit: true
    else
      node.annotation = dataType: 'Any', explicit: false

walk_arrayInializer = (node, scope) ->
  walk node.members, scope

  node.annotation ?=
    dataType: {array: (node.members?.map (m) -> m.annotation?.dataType)}

walk_range = (node, scope) ->
  node.annotation = dataType : {array: 'Number'}

walk_objectInitializer = (node, scope) ->

  obj = {}
  nextScope = new Scope scope
  nextScope.name = 'object'

  for {expression, key} in node.members when key?
    walk expression, nextScope
    obj[key.data] = expression.annotation?.dataType

  node.annotation ?=
    dataType: obj

walk_class = (node, scope) ->
  classScope = new ClassScope scope
  this_scope = {}

  # Add props to this_socpe by extends and implements
  if node.nameAssignee?.data
    # extends
    if node.parent?.data
      parent = scope.getTypeInScope node.parent.data
      if parent
        for key, val of parent.dataType
          this_scope[key] = val
    # implements
    if node.impl?.length?
      for name in node.impl
        cls = scope.getTypeInScope name
        if cls
          for key, val of cls.dataType
            this_scope[key] = val

  # collect @values first
  if node.body?.statements?
    for statement in node.body.statements when statement.dataType is 'vardef'
      walk_vardef statement, classScope

  # constructor
  if node.ctor?
    constructorScope = new FunctionScope classScope
    constructorScope._this = classScope._this # delegate this scope
    # arguments
    if node.ctor.expression.parameters?
      # vardef exists: constructor :: X, Y, Z
      if constructorScope.getThis('_constructor_')
        predef = constructorScope.getThis('_constructor_').dataType
        for param, index in node.ctor.expression.parameters when param?
          walk param, constructorScope
          constructorScope.addVar param.data, (predef._args_?[index] ? 'Any')
      else
        for param, index in node.ctor.expression.parameters when param?
          walk param, constructorScope
          constructorScope.addVar param.data, (param?.annotation?.dataType ? 'Any')

    # constructor body
    if node.ctor.expression.body?.statements?
      for statement in node.ctor.expression.body.statements
        walk statement, constructorScope

  # walk
  if node.body?.statements?
    for statement in node.body.statements when statement.dataType isnt 'vardef'
      walk statement, classScope

  if node.nameAssignee?.data
    for fname, val of classScope._this
      this_scope[fname] = val.dataType
    scope.addType node.nameAssignee.data, this_scope

# Node * Scope * Type
# predef :: Type defined at assignee
walk_function = (node, scope, predef = null) ->
  _args_ = node.parameters?.map (param) -> param.annotation?.dataType ? 'Any'

  node.annotation.dataType._args_ = _args_

  functionScope = new Scope scope
  functionScope._name_ = 'function'


  if scope instanceof ClassScope
    functionScope._this = scope._this

  # register arguments to function scope
  # TODO: DRY
  if node.parameters?
    # example.
    #   f :: Int -> Int
    #   f: (n) -> n
    if predef
      node.annotation.dataType = predef
      for param, index in node.parameters
        # Destructive
        if param.members
          for member in param.members
            # This
            if member.expression?.expression?.raw in ['@', 'this']
              t = functionScope.getThis(member.key.data)
              unless t?.dataType? then functionScope.addThis member.key.data, 'Any'
            # Var
            else
              if member.key?.data
                functionScope.addVar member.key.data, 'Any'
        # This
        else if param.expression?.raw in ['@', 'this']
          t = functionScope.getThis(param.memberName)
          if err = scope.checkAcceptableObject predef._args_?[index], t?.dataType
            err = typeErrorText predef._args_?[index], t?.dataType
            reporter.add_error node, err
          unless t?.dataType? then functionScope.addThis param.memberName, 'Any'
        # Var
        else
          functionScope.addVar param.data, (predef._args_?[index] ? 'Any')
    # example.
    #   f: (n) -> n
    else
      for param, index in node.parameters
        # Destructive
        if param.members
          for member in param.members
            # This
            if member.expression?.expression?.raw in ['@', 'this']
              t = functionScope.getThis(member.key.data)
              unless t?.dataType? then functionScope.addThis member.key.data, 'Any'
            # Var
            else
              if member.key?.data
                functionScope.addVar member.key.data, 'Any'
        # This
        else if param.expression?.raw in ['@', 'this']
          t = functionScope.getThis(param.memberName)
          unless t?.dataType? then functionScope.addThis param.memberName, 'Any'
        # Var
        else
          functionScope.addVar param.data, (param?.annotation?.dataType ? 'Any')

  walk node.body, functionScope

  # () :: Number -> 3
  if node.annotation?.dataType?.returnType isnt 'Any'
    # last expr or single line expr
    last_expr =
      if node.body?.statements?.length # => Blcok
        node.body.statements?[node.body?.statements?.length-1]
      else # => Expr
        node.body

    # 明示的に宣言してある場合
    if err = scope.checkAcceptableObject(node.annotation?.dataType.returnType, last_expr?.annotation?.dataType)
      err = typeErrorText node.annotation?.dataType.returnType, last_expr?.annotation?.dataType
      return reporter.add_error node, err

  else
    last_expr =
      if node.body?.statements?.length # => Blcok
        node.body.statements?[node.body?.statements?.length-1]
      else # => Expr
        node.body

    if node.annotation?
      node.annotation.dataType.returnType = last_expr?.annotation?.dataType

walk_functionApplication = (node, scope) ->
  for arg in node.arguments
    walk arg, scope
  walk node.function, scope
  node.annotation = dataType: (node.function.annotation?.dataType?.returnType)

  if node.function.annotation
    _args_ = node.arguments?.map (arg) -> arg.annotation?.dataType
    if err = scope.checkAcceptableObject node.function.annotation.dataType, {_args_: (_args_ ? []), returnType: 'Any'}
      err = typeErrorText node.function.annotation.dataType, {_args_: (_args_ ? []), returnType: 'Any'}
      return reporter.add_error node, err

# Traverse all nodes
# Node -> void
walk = (node, scope) ->
  switch
    # undefined(mayby null body)
    when not node? then return
    # Nodes Array
    when node.length?                    then  walk s, scope for s in node
    # Struct
    # Dirty hack on Number
    when node.dataType is 'struct'           then walk_struct node, scope
    when node.dataType is 'vardef'           then walk_vardef node, scope
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
    # left.annotation.dataType
    when node.instanceof CS.AssignOp then walk_assignOp node, scope

module.exports = {checkNodes}
