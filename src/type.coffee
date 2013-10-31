console = {log: ->}
pj = try require 'prettyjson'
render = (obj) -> pj?.render obj
{first, last, map, concat} = require './functional-helpers'

CS = require './nodes'

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

  walk cs_ast.body.statements, root

  console.log 'scope ====================='
  Scope.dump root
  console.log '================== Scope'
  console.log 'finish ================== checkNodes'

# Exec down casting
# pass obj :: {x :: Number, name :: String} = {x : 3, y : "hello"}
# ng   obj :: {x :: Number, name :: String} = {x : 3, y : 5 }
checkAcceptableObject = (left, right) ->
  console.log left, right
  # "Number" <> "Number"
  if ((typeof left) is 'string') and ((typeof right) is 'string')
    if (left is right) or (left is 'Any') or (right is 'Any')
      'ok'
    else
      throw (new Error "object deep equal mismatch #{left}, #{right}")

  # {array: "Number"} <> {array: "Number"}
  else if left?.array?
    # TODO: fix it
    console.log 'leftb', left
    console.log right

  # {x: "Nubmer", y: "Number"} <> {x: "Nubmer", y: "Number"}
  else if ((typeof left) is 'object') and ((typeof right) is 'object')
    for key, lval of left
      # when {x: Number} = {z: Number}
      if right[key] is undefined
        return if key is 'returns' # TODO FunctionTypeをちゃんとどうにかする 色々混線してる
        throw new Error "'#{key}' is not defined on right"
      checkAcceptableObject(lval, right[key])
  else if (left is undefined) or (right is undefined)
    # TODO: valid code later
    "ignore now"
  else
    throw (new Error "object deep equal mismatch #{left}, #{right}")

# Initialize primitive types
# Number, Boolean, Object, Array, Any
initializeGlobalTypes = (node) ->
  # Primitive
  node.addTypeObject 'String', new TypeSymbol {
    type: 'String'
    instanceof: (expr) -> (typeof expr.data) is 'string'
  }

  node.addTypeObject 'Number', new TypeSymbol {
    type: 'Number'
    instanceof: (expr) -> (typeof expr.data) is 'number'
  }

  node.addTypeObject 'Boolean', new TypeSymbol {
    type: 'Boolean'
    instanceof: (expr) -> (typeof expr.data) is 'boolean'
  }

  node.addTypeObject 'Object', new TypeSymbol {
    type: 'Object'
    instanceof: (expr) -> (typeof expr.data) is 'object'
  }

  node.addTypeObject 'Array', new TypeSymbol {
    type: 'Array'
    instanceof: (expr) -> (typeof expr.data) is 'object'
  }

  # Any
  node.addTypeObject 'Any', new TypeSymbol {
    type: 'Any'
    instanceof: (expr) -> true
  }

# Known vars in scope
class VarSymbol
  # type :: String
  # implicit :: Bolean
  constructor: ({@type, @implicit}) ->

# Known types in scope
class TypeSymbol
  # type :: String or Object
  # instanceof :: (Any) -> Boolean
  constructor: ({@type, @instanceof}) ->
    @instanceof ?= (t) -> t instanceof @constructor

# Var and type scope as node
class Scope
  # constructor :: (Scope) -> Scope

  # Get registered type in my scope
  # addType  :: (String, String) -> ()

  # Get registered type included in parents
  # addTypeInScope  :: (String, String) -> ()

  constructor: (@parent = null) ->
    @parent?.nodes.push this

    @name = ''
    @nodes  = [] #=> scopeeNode...

    # スコープ変数
    @_vars  = {} #=> symbol -> type

    # 登録されている型
    @_types = {} #=> typeName -> type

    # TODO: This Scope
    @_this  = null #=> null or {}

    # このブロックがReturn する可能性があるもの
    @_returnables = [] #=> [ReturnableType...]

  addReturnable: (symbol, type) ->
    @_returnables.push type

  getReturnables: -> @_returnables

  addType: (symbol, type) ->
    @_types[symbol] = new TypeSymbol {type}

  addTypeObject: (symbol, type_object) ->
    @_types[symbol] = type_object

  getType: (symbol) ->
    @_types[symbol]?.type ? undefined

  getTypeInScope: (symbol) ->
    @getType(symbol) or @parent?.getTypeInScope(symbol) or undefined

  addVar: (symbol, type, implicit = true) ->
    @_vars[symbol] = new VarSymbol {type, implicit}

  getVar: (symbol) ->
    @_vars[symbol]?.type ? undefined

  getVarInScope: (symbol) ->
    @getVar(symbol) or @parent?.getVarInScope(symbol) or undefined

  isImplicitVar: (symbol) -> !! @_vars[symbol]?.implicit

  isImplicitVarInScope: (symbol) ->
    @isImplicitVar(symbol) or @parent?.isImplicitVarInScope(symbol) or undefined

  # Extend symbol to type object
  # ex. {name : String, p : Point} => {name : String, p : { x: Number, y: Number}}
  extendTypeLiteral: (node) ->
    switch (typeof node)
      when 'object'
        # array
        if node instanceof Array
          return (@extendTypeLiteral(i) for i in node)
        # object
        else
          ret = {}
          for key, val of node
            ret[key] = @extendTypeLiteral(val)
          return ret
      when 'string'
        type = @getTypeInScope(node)
        switch typeof type
          when 'object'
            return @extendTypeLiteral(type)
          when 'string'
            return type

  # Check arguments
  checkFunctionLiteral: (left, right) ->
    # flat extend
    left  = @extendTypeLiteral left
    right = @extendTypeLiteral right
    # check args
    for l_arg, i in left.args
      r_arg = right.args[i]
      checkAcceptableObject(l_arg, r_arg)

    # check return type
    # TODO: Now I will not infer function return type
    if right.returns isnt 'Any'
      checkAcceptableObject(left.returns, right.returns)

  # Check arrays
  # TODO: no use yet
  checkArrayLiteral: (left, right) ->
    left  = @extendTypeLiteral left
    right = @extendTypeLiteral right

    # check args
    for l_arg, i in left.args
      r_arg = right.args[i]
      checkAcceptableObject(l_arg, r_arg)

    # return type
    checkAcceptableObject(left.returns, right.returns)

  # for debug
  @dump: (node, prefix = '') ->
    console.log prefix + "[#{node.name}]"
    for key, val of node._vars
      console.log prefix, ' +', key, '::', val
    for next in node.nodes
      Scope.dump next, prefix + '  '

# Traverse all nodes
walk = (node, currentScope) ->
  console.log '---', node?.className, '---', node?.raw
  switch
    # undefined(mayby body)
    when not node?
      return

    # Nodes Array
    when node.length?
      walk s, currentScope for s in node

    # Struct
    # Dirty hack on Number
    when node.type is 'struct'
      currentScope.addType node.name, node.expr

    # Program
    when node.instanceof CS.Program
      walk node.body.statements, currentScope
      node.annotation = type: 'Program'

    when node.instanceof CS.Block
      walk node.statements, currentScope
      last_annotation = (node.statements[node.statements.length-1])?.annotation
      node.annotation = last_annotation

    when node.instanceof CS.Return
      walk node.expression, currentScope
      if node.expression?.annotation?.type?
        currentScope.addReturnable node.expression.annotation.type
        node.annotation = node.expression.annotation

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
            target_type = currentScope.extendTypeLiteral(el)
            checkAcceptableObject(node.valAssignee.annotation.type, target_type)

      # for of
      else if node.target?.annotation?.type instanceof Object
        if node.target.annotation.type instanceof Object
          for nop, type of node.target.annotation.type
            checkAcceptableObject(currentScope.extendTypeLiteral(node.valAssignee.annotation.type), currentScope.extendTypeLiteral(type))

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
        console.log '~~~~~~~~~~', node.annotation?.type?.returns

        # last expr or single line expr
        last_expr =
          if node.body?.statements?.length # => Blcok
            node.body.statements?[node.body?.statements?.length-1]
          else # => Expr
            node.body

        # 明示的に宣言してある場合
        checkAcceptableObject(currentScope.extendTypeLiteral(node.annotation.type.returns), currentScope.extendTypeLiteral(last_expr.annotation?.type))
        # console.log 'returns', currentScope.getReturnables()

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
          if assigning is 'Any'
            currentScope.addVar symbol, 'Any', true

          # ifが返す値
          else if right.instanceof CS.Conditional
            for p in right.annotation.possibilities
              checkAcceptableObject assigning, p.type

          # forが返す可能性
          else if right.instanceof CS.ForIn
            checkAcceptableObject(assigning.array, currentScope.extendTypeLiteral(right.annotation.type))

          # arr = [1,2,3]
          else if right.annotation?.type?.array?
            # TODO: Refactor to checkAcceptableObject
            for el in right.annotation.type.array
              target_type = currentScope.extendTypeLiteral(el)
              checkAcceptableObject(assigning.array, target_type)
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
              checkAcceptableObject(assigning, right.annotation.type)
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
            checkAcceptableObject(currentScope.extendTypeLiteral(left.annotation.type), currentScope.extendTypeLiteral(right.annotation.type))

      # Vanilla CS
      else
        currentScope.addVar symbol, 'Any'

module.exports = {checkNodes}
