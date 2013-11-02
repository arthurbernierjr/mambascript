console = {log: ->}
pj = try require 'prettyjson'
render = (obj) -> pj?.render obj

CS = require './nodes'

{
  checkAcceptableObject,
  initializeGlobalTypes,
  VarSymbol,
  TypeSymbol,
  Scope
} = require './types'

# CS AST -> void
checkNodes = (cs_ast) ->
  return unless cs_ast.body?.statements?
  console.log 'AST =================='
  # console.log render cs_ast
  console.log '================== AST'
  root = new Scope
  root.name = 'root'

  for i in ['global', 'exports', 'module']
    root.addVar i, 'Any', true
  initializeGlobalTypes(root)

  walk cs_ast, root

  console.log 'scope ====================='
  Scope.dump root
  console.log 'finish ================== checkNodes'


# Node -> void

walk_struct = (node, scope) ->
  scope.addType node.name, node.expr

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

# Traverse all nodes
walk = (node, currentScope) ->
  console.log '---', node?.className, '---', node?.raw
  switch
    # undefined(mayby null body)
    when not node? then return

    # Nodes Array
    when node.length?
      walk s, currentScope for s in node

    # Struct
    # Dirty hack on Number
    when node.type is 'struct'
      walk_struct node, currentScope

    # Program
    when node.instanceof CS.Program
      walk_program node, currentScope

    when node.instanceof CS.Block
      walk_block node, currentScope

    when node.instanceof CS.Return
      walk_return node, currentScope

    # bin op
    when node.instanceof(CS.PlusOp) or node.instanceof(CS.MultiplyOp) or node.instanceof(CS.DivideOp) or node.instanceof(CS.SubtractOp)
      console.log 'binops', node.className
      walk node.left, currentScope
      walk node.right, currentScope

      left_type = node.left?.annotation?.type
      right_type = node.right?.annotation?.type

      if left_type and right_type
        # rough...
        if left_type is 'String' or right_type is 'String'
          node.annotation = type: 'String'
        else if left_type is right_type
          node.annotation = type: left_type, implicit: false
      else
        node.annotation = type:'Any', implicit: true

        console.log render node


    # subtract
    when node.instanceof CS.SubtractOp
      node.annotation = type: 'Number'
      walk node.left, currentScope
      walk node.right, currentScope

    # === Controlle flow ===
    # If
    when node.instanceof CS.Conditional
      # condition expr
      walk node.condition, currentScope #=> Expr

      # else if
      walk node.consequent, currentScope #=> Block

      # else
      if node.alternate?
        walk node.alternate, currentScope #=> Block

      # if node.alternate doesn't exist, then return type is Undefined
      alternate_annotation = (node.alternate?.annotation) ? (type: 'Undefined', implicit: true)

      possibilities = []
      for n in [node.consequent?.annotation, alternate_annotation] when n?
        if n.possibilities?
          (possibilities.push(i) for i in n.possibilities)
        else
          possibilities.push n

      node.annotation = {possibilities, implicit: true}

    # For
    when (node.instanceof CS.ForIn) or (node.instanceof CS.ForOf)
      walk node.target, currentScope

      if node.valAssignee?
        currentScope.addVar node.valAssignee.data, (node.valAssignee?.annotation?.type) ? 'Any'

      if node.keyAssignee?
        # must be number or string
        currentScope.addVar node.keyAssignee.data, (node.keyAssignee?.annotation?.type) ? 'Any'

      # TODO:  Refactor with type array
      # for in
      if node.target.annotation?.type?.array?
        for el in node.target.annotation?.type?.array
          if node.valAssignee?
            currentScope.checkAcceptableObject(node.valAssignee.annotation.type, el)

      # for of
      else if node.target?.annotation?.type instanceof Object
        if node.target.annotation.type instanceof Object
          for nop, type of node.target.annotation.type
            currentScope.checkAcceptableObject(node.valAssignee.annotation.type, type)

      # check body
      walk node.body, currentScope #=> Block
      node.annotation = node.body?.annotation

      # remove after iter
      delete currentScope._vars[node.valAssignee?.data]
      delete currentScope._vars[node.keyAssignee?.data]

    # String
    when node.instanceof CS.String
      node.annotation ?=
        type: 'String'
        implicit: true
        primitive: true

    # Bool
    when node.instanceof CS.Bool
      node.annotation ?=
        type: 'Boolean'
        implicit: true
        primitive: true

    # Number
    # TODO: Int, Float
    when node.instanceof CS.Numbers
      node.annotation ?=
        type: 'Number'
        implicit: true
        primitive: true
      # if node.instanceof CS.Int
      #   node.annotation ?=
      #     type: 'Int'
      #     implicit: true
      # else if node.instanceof CS.Int
      #   node.annotation ?=
      #     type: 'Float'
      #     implicit: true

    # Identifier
    when node.instanceof CS.Identifier
      if currentScope.getVarInScope(node.data)
        node.annotation = type: currentScope.getVarInScope(node.data)
      else
        node.annotation ?=
          type: 'Any'
          implicit: true

    # MemberAccessOps
    when node.instanceof CS.MemberAccessOps
      if node.instanceof CS.MemberAccessOp
        walk node.expression, currentScope

        type = currentScope.extendTypeLiteral(node.expression.annotation?.type)
        if type?
          node.annotation = type: type[node.memberName], implicit: false
        else
          node.annotation = type: 'Any', implicit: true

    # Array
    when node.instanceof CS.ArrayInitialiser
      walk node.members, currentScope

      node.annotation ?=
        type: {array: (node.members?.map (m) -> m.annotation?.type)}
        implicit: true

    when node.instanceof CS.Range
      node.annotation = type : {array: 'Number'}

    # Object
    when node.instanceof CS.ObjectInitialiser
      obj = {}
      nextScope = new Scope currentScope
      nextScope.name = 'object'

      for {expression, key} in node.members when key?
        walk expression, nextScope
        obj[key.data] = expression.annotation?.type

      # TODO: implicit ルールをどうするか決める
      node.annotation ?=
        type: obj
        implicit: true

    # Class
    when node.instanceof CS.Class
      walk node.body.statements, new Scope currentScope

    # Function
    when node.instanceof CS.Function
      args = node.parameters?.map (param) -> param.annotation?.type ? 'Any'
      node.annotation.type.args = args

      functionScope      = new Scope currentScope
      functionScope.name = 'function'

      # register arguments to next scope
      node.parameters?.map (param) ->
        try
          functionScope.addVar? param.data, (param.annotation?.type ? 'Any')
        catch
          # TODO あとで調査 register.jsで壊れるっぽい
          'ignore but brake on somewhere. why?'

      # walk node.body?.statements, functionScope
      walk node.body, functionScope

      # () :: Number -> 3
      if node.annotation?.type?.returns isnt 'Any'
        # last expr or single line expr
        last_expr =
          if node.body?.statements?.length # => Blcok
            node.body.statements?[node.body?.statements?.length-1]
          else # => Expr
            node.body

        # 明示的に宣言してある場合
        currentScope.checkAcceptableObject(node.annotation.type.returns, last_expr.annotation?.type)

      else
        last_expr =
          if node.body?.statements?.length # => Blcok
            node.body.statements?[node.body?.statements?.length-1]
          else # => Expr
            node.body

        if node.annotation?
          node.annotation.type.returns = last_expr?.annotation?.type

    # FunctionApplication
    when node.instanceof CS.FunctionApplication
      walk node.arguments, currentScope
      expected = currentScope.getVarInScope(node.function.data)

      # args
      if expected? and expected isnt 'Any'
        args = node.arguments?.map (arg) -> arg.annotation?.type
        currentScope.checkFunctionLiteral expected, {args: args, returns: 'Any'}

        node.annotation ?=
          type: expected.returns
          implicit: true

    # Assigning
    when node.instanceof CS.AssignOp
      left  = node.assignee
      right = node.expression

      walk right, currentScope
      walk left, currentScope #=>

      return unless left?

      # NOT member access
      if left.instanceof CS.Identifier

        symbol     = left.data
        registered = currentScope.getVarInScope(symbol)
        infered    = right.annotation?.type

        assigning =
          if left.annotation?
            currentScope.extendTypeLiteral(left.annotation.type)
          else
            undefined

        # 既に宣言済みのシンボルに対して型宣言できない
        #    x :: Number = 3
        # -> x :: String = "hello"
        if assigning? and registered? and assigning isnt 'Any'
          throw new Error 'double bind: '+ symbol

        # 未定義のアクセスなど
        else if registered?
          return if symbol is 'toString' # TODO: fix
          # 推論済みor anyならok
          unless  (registered is infered) or (registered is 'Any')
            throw new Error "'#{symbol}' is expected to #{registered} indeed #{infered}, by assignee"

        # 左辺に型宣言が存在する
        # -> x :: Number = 3
        else if assigning?
          # 明示的なAnyは全て受け入れる
          # x :: Any = "any instance"

          console.log '---- xxx ---'
          console.log render right

          if assigning is 'Any'
            currentScope.addVar symbol, 'Any', true

          # ifが返す値
          else if right.instanceof CS.Conditional
            for p in right.annotation.possibilities
              currentScope.checkAcceptableObject assigning, p.type

          # forが返す可能性
          else if right.instanceof CS.ForIn
            currentScope.checkAcceptableObject(assigning.array, currentScope.extendTypeLiteral(right.annotation.type))

          # arr = [1,2,3]
          # else if right.instanceof CS.Range
          #   console.log 'range here yey!~!!', right
          else if right.annotation?.type?.array?
            # TODO: Refactor to checkAcceptableObject

            if (typeof right.annotation.type.array) is 'string'
              currentScope.checkAcceptableObject(assigning.array, right.annotation.type.array)

            else if right.annotation.type.array.length?
              for el in right.annotation.type.array
                currentScope.checkAcceptableObject(assigning.array, el)
            currentScope.addVar symbol, 'Any', true # TODO Valid type

          # TypedFunction
          # f :: Int -> Int = (n) -> n
          else if left.annotation.type.args? and right.annotation.type.args?
            # TODO: ノードを推論した結果、関数になる場合はok annotation.typeをみる
            if right.instanceof CS.Function
              currentScope.checkFunctionLiteral(left.annotation.type, right.annotation.type)

            else
              throw new Error "Right is not function"

            currentScope.addVar symbol, left.annotation.type

          else if (typeof assigning) is 'object'
            # TODO: ignore destructive assignation
            # ex) {map, concat, concatMap, difference, nub, union} = require './functional-helpers'
            if right.annotation? and left.annotation?
              currentScope.checkAcceptableObject(assigning, right.annotation.type)
              currentScope.addVar symbol, left.annotation.type, false

          # 右辺の型が指定した型に一致する場合
          # x :: Number = 3
          else if assigning is infered
            currentScope.addVar symbol, left.annotation.type
          # Throw items
          else
            return if symbol is 'toString' # TODO: なぜかtoStringくることがあるので握りつぶす
            throw new Error "'#{symbol}' is expected to #{left.annotation.type} indeed #{infered}"

      # Member access
      else if left.instanceof CS.MemberAccessOp
        return if left.expression.raw is '@' # ignore @ yet
        if left.annotation?.type? and right.annotation?.type?
          if left.annotation.type isnt 'Any'
            currentScope.checkAcceptableObject(left.annotation.type, right.annotation.type)

      # Vanilla CS
      else
        currentScope.addVar symbol, 'Any'

module.exports = {checkNodes}
