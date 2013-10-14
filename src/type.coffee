# console = {log: ->}
class TypeSymbol
  constructor: (@type) ->
    @type = Symbol

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

class ScopeNode
  constructor: ->
    @name = ''
    @nodes = [] #=> ScopeNode...
    @defs = {} #=> symbol -> type
    @parent = null
  setType: (symbol, type) ->
    @defs[symbol] = type
  getType: (symbol) ->
    @defs[symbol]
  getScopedType: (symbol) ->
    @getType(symbol) or @parent?.getScopedType(symbol) or undefined

  @dump: (node, prefix = '') ->
    console.log prefix + "[#{node.name}]"
    for key, val of node.defs
      console.log prefix, ' +', key, '::', val
    for n in node.nodes
      ScopeNode.dump n, prefix + '  '

checkNodes = (cs_ast) ->
  return unless cs_ast.body?.statements?
  # console.log cs_ast.body.statements
  root = new ScopeNode
  root.name = 'root'
  _typecheck cs_ast.body.statements, root
  ScopeNode.dump root

_typecheck = (node, parentScope) ->
  # undefined
  return if node is undefined

  # array
  if node.length?
    node.forEach (s) -> _typecheck s, parentScope
    return

  # ラムダ
  else if guess_expr_type(node) is 'Function'
    # console.log 'this is lambda', statement
    {body} = node
    snode = new ScopeNode
    snode.name   = '-lambda-'
    snode.parent = parentScope
    parentScope.nodes.push snode
    _typecheck body.statements, snode

  # クラス
  else if node.nameAssignee? and node.body?
    {body, name} = node
    snode = new ScopeNode
    snode.name   = name.data
    snode.parent = parentScope
    parentScope.nodes.push snode
    _typecheck body.statements, snode

  # 関数呼び出し
  else if node.function? and node.arguments?
    _typecheck node.arguments, parentScope

  # 代入
  else if node.assignee? and node.expression?
    {assignee, expression} = node
    symbol          = assignee.data
    registered_type = parentScope.getScopedType(symbol)
    infered_type    = guess_expr_type expression
    assigned_type   = assignee.annotation?.type

    # 型識別子が存在し、既にそのスコープで宣言済みのシンボルである場合、二重定義として例外
    if registered_type? and assigned_type?
      throw new Error 'double bind', symbol

    # 型識別子が存在せず、既にそのスコープで宣言済みのシンボルである場合、再度型推論する
    else if registered_type?
      # 推論済みor anyならok
      if symbol is 'toString'
        ''
      else unless  (registered_type is infered_type) or (registered_type is 'Any')
        throw new Error "'#{symbol}' is expected to #{registered_type} indeed #{infered_type}, #{node.toString()}"

    # 型識別子が存在せず、既にそのスコープで宣言済みの型である場合、再度型推論する識別子が存在する場合スコープに追加する
    else if assigned_type
      if assigned_type is 'Any'
        parentScope.setType symbol, 'Any'
      else if assigned_type is infered_type
        parentScope.setType symbol, assignee.annotation.type
        # 関数を追加
        if infered_type is 'Function'
          fnode = new ScopeNode
          fnode.name   = symbol
          fnode.parent = parentScope

          # 引数を次のスコープの名前空間に追加
          node.expression.parameters.map (param) ->
            fnode.setType param.data, param.annotation?.type ? 'Any'

          parentScope.nodes.push fnode
          _typecheck node.expression.body.statements, fnode
      else
        # TODO: なぜかtoStringくることがあるので握りつぶす
        if symbol is 'toString'
          ''
        else
          throw new Error "'#{symbol}' is expected to #{assignee.annotation.type} indeed #{infered_type}"
    else
      # scope.setType symbol, infered_type
      parentScope.setType symbol, 'Any'
      if infered_type is 'Function' and node.expression.body?.statements?
        fnode = new ScopeNode
        fnode.name   = symbol
        fnode.parent = parentScope
        parentScope.nodes.push fnode
        _typecheck node.expression.body.statements, fnode

module.exports = {checkNodes}
