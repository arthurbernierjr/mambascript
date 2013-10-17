CS = require './nodes'

console = {log: ->}
guess_expr_type = (expr) ->
  if (typeof expr.data) is 'number'
    'Number'
  else if (typeof expr.data) is 'string'
    'String'
  else if (typeof expr.data) is 'boolean'
    'Boolean'
  else if expr.parameters? and expr.body?
    'Function'
  else
    'Any'

class VarSymbol
  # type :: String
  # implicit :: Bolean
  constructor: ({@type, @implicit}) ->

class TypeSymbol
  # type :: String or Object
  # instanceof :: (Any) -> Boolean
  constructor: ({@type, @instanceof}) ->
    @instanceof ?= (t) -> t instanceof @constructor

class Scope
  constructor: ->
    @name = ''
    @nodes  = [] #=> scopeeNode...
    @_vars  = {} #=> symbol -> type
    @_types = {} #=> typeName -> type
    @_this  = null #=> null or {}
    @parent = null

  setType: (symbol, type) ->
    @_types[symbol] = new TypeSymbol {type}

  sltTypeObject: (symbol, type_object) ->
    @_types[symbol] = type_object

  getType: (symbol) ->
    @_types[symbol]?.type ? undefined

  getTypeInScope: (symbol) ->
    @getType(symbol) or @parent?.getTypeInScope(symbol) or undefined

  setVar: (symbol, type, implicit = true) ->
    @_vars[symbol] = new VarSymbol {type, implicit}

  getVar: (symbol) ->
    @_vars[symbol]?.type ? undefined

  getVarInScope: (symbol) ->
    @getVar(symbol) or @parent?.getVarInScope(symbol) or undefined

  @dump: (node, prefix = '') ->
    console.log prefix + "[#{node.name}]"
    for key, val of node._vars
      console.log prefix, ' +', key, '::', val
    for next in node.nodes
      Scope.dump next, prefix + '  '

initializeGlobalTypes = (node) ->
  node.setTypeObject 'Number', new TypeSymbol {
    type: 'Number'
    instanceof: (n) -> (typeof n) is 'number'
  }

checkNodes = (cs_ast) ->
  return unless cs_ast.body?.statements?
  console.log cs_ast.body.statements
  console.log '====================='
  root = new Scope
  root.name = 'root'
  for i in ['global', 'exports', 'Module', 'module']
    root.setVar i, 'Any', true
  _typecheck cs_ast.body.statements, root
  Scope.dump root

_typecheck = (node, currentScope) ->
  # console.log node.className
  # undefined
  # TODO: Why?
  if node is undefined
    return

  # array
  else if node.length?
    node.forEach (s) -> _typecheck s, currentScope
    return

  else if node.type is 'struct'
    console.log 'struct', node
    currentScope.setType node.name, node.expr

  # ラムダ
  else if node instanceof CS.Function
    {body} = node
    snode = new Scope
    snode.name   = '-lambda-'
    snode.parent = currentScope
    currentScope.nodes.push snode
    _typecheck body.statements, snode

  # クラス
  else if node instanceof CS.Class
    {body, name} = node
    snode = new Scope
    snode.name   = name.data
    snode.parent = currentScope
    currentScope.nodes.push snode
    _typecheck body.statements, snode

  # 関数呼び出し
  else if node instanceof CS.FunctionApplication
    # TODO: argumentsを名前空間に
    _typecheck node.arguments, currentScope

  # member access
  # TODO: 入れ子とか関数の返り値を考慮
  # else if node.assignee?.memberName? and node.expression?
  else if (node instanceof CS.AssignOp) and node.assignee.expression?
    symbol = node.assignee.expression.data
    member = node.assignee.memberName

    registered_type = currentScope.getVarInScope(symbol) # Object
    return unless registered_type? # TODO: maybe global defined

    type = registered_type[member] # ClassName
    infered_type = guess_expr_type node.expression

    if type? and (type is infered_type) or (registered_type is 'Any')
      ''
    else
      throw new Error "'#{symbol}' is expected to #{registered_type} (indeed #{infered_type}) at member access"

  # 代入
  else if node instanceof CS.AssignOp
    # console.log 'assign', node.className, (node instanceof CS.AssignOp), node

    {assignee, expression} = node
    symbol          = assignee.data
    registered_type = currentScope.getVarInScope(symbol)
    infered_type    = guess_expr_type expression
    assigned_type   =
      if (typeof assignee.annotation?.type) is 'object' then assignee.annotation?.type
      else currentScope.getTypeInScope(assignee.annotation?.type) ? assignee.annotation?.type
    console.log assigned_type, currentScope.getTypeInScope(assignee.annotation?.type)

    # 型識別子が存在し、既にそのスコープで宣言済みのシンボルである場合、二重定義として例外
    #    x :: Number = 3
    # -> x :: String = "hello"
    if registered_type? and assigned_type?
      throw new Error 'double bind', symbol

    # Function call
    # -> x :: Number = f 4
    else if node.expression.function?
      expected = currentScope.getVarInScope(expression.function.data)

      # TODO: argument check
      if expected is undefined
        currentScope.setVar symbol, 'Any'
      else if assigned_type is expected?.returns
        currentScope.setVar symbol, assigned_type
      else
        throw new Error "'#{symbol}' is expected to #{assigned_type} indeed #{expected}, by function call"

    # シンボルに型識別子が存在せず、既にそのスコープで宣言済みのシンボルである場合
    # expressionを再度型推論し、ダウンキャストできなければthrow
    #    x :: Number = 3
    # -> x = 5
    # TODO: ダウンキャストルールの記述
    else if registered_type?

      # 推論済みor anyならok
      if symbol is 'toString'
        ''
      else unless  (registered_type is infered_type) or (registered_type is 'Any')
        throw new Error "'#{symbol}' is expected to #{registered_type} indeed #{infered_type}, by assignee"

    # シンボルに対して 型識別子が存在する
    # -> x :: Number = 3
    else if assigned_type
      # 明示的なAny
      # x :: Any = "any instance"
      if assigned_type is 'Any'
        currentScope.setVar symbol, 'Any'
      # TypedFunction
      # f :: Int -> Int = (n) -> n
      else if assignee.annotation.type.type is 'Function'
        # register
        currentScope.setVar symbol, assignee.annotation.type
      # オブジェクトリテラル
      else if (typeof assigned_type) is 'object'
        currentScope.setVar symbol, assignee.annotation.type
      else if assigned_type is infered_type
        currentScope.setVar symbol, assignee.annotation.type
        # 関数を追加
        if infered_type is 'Function'
          fnode = new Scope
          fnode.name   = symbol
          fnode.parent = currentScope

          # 引数を次のスコープの名前空間に追加
          node.expression.parameters.map (param) ->
            fnode.setVar param.data, param.annotation?.type ? 'Any'

          currentScope.nodes.push fnode
          _typecheck node.expression.body.statements, fnode
      else
        # TODO: なぜかtoStringくることがあるので握りつぶす
        return if symbol is 'toString'

        throw new Error "'#{symbol}' is expected to #{assignee.annotation.type} indeed #{infered_type}"
    else
      # scope.setVar symbol, infered_type
      currentScope.setVar symbol, 'Any'
      if infered_type is 'Function' and node.expression.body?.statements?
        fnode = new Scope
        fnode.name   = symbol
        fnode.parent = currentScope
        currentScope.nodes.push fnode
        _typecheck node.expression.body.statements, fnode

module.exports = {checkNodes}
