console = {log: ->}

CS = require './nodes'

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
  constructor: (@parent = null) ->
    @parent?.nodes.push this

    @name = ''
    @nodes  = [] #=> scopeeNode...
    @_vars  = {} #=> symbol -> type
    @_types = {} #=> typeName -> type
    @_this  = null #=> null or {}

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

  # convert
  # {name : String, p : Point} => {name : String, p : { x: Number, y: Number}}
  extendTypeLiteral: (object_or_name) ->
    switch (typeof object_or_name)
      when 'object'
        obj = object_or_name
        for key, val of obj
          switch (typeof validate)
            when 'object'
              obj[key] = @extendTypeLiteral(val)
            when 'string'
              obj[key] = @getTypeInScope(val)
        obj
      when 'string'
        str = object_or_name
        return @getTypeInScope(str) ? str


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
  walk cs_ast.body.statements, root
  Scope.dump root

walk = (node, currentScope) ->
  switch
    # undefined
    # TODO: Why?
    when node is undefined
      return

    # array
    when node.length?
      node.forEach (s) -> walk s, currentScope

    # struct
    when node.type is 'struct'
      currentScope.setType node.name, node.expr

    # クラス
    when node.instanceof CS.Class
      walk node.body.statements, new Scope currentScope

    # ラムダ
    when node.instanceof CS.Function
      scope = new Scope currentScope
      scope.name   = '-lambda-'

      # register arguments to next scope
      node.parameters.map (param) ->
        scope.setVar param.data, (param.annotation?.type ? 'Any')

      walk node.body?.statements, scope

    # 関数呼び出し
    when node.instanceof CS.FunctionApplication
      # TODO: 引数チェック
      walk node.arguments, currentScope

    # Assigning
    when node.instanceof CS.AssignOp
      left  = node.assignee
      right = node.expression

      # メンバーアクセス
      if left.memberName?
        symbol = left.expression.data
        registered = currentScope.getVarInScope(symbol) # Object
        return unless registered? # TODO: maybe global defined

        expected = registered[left.memberName] # ClassName
        infered  = guess_expr_type right

        if expected? and (expected is infered) or (registered is 'Any')
          ''
        else
          throw new Error "'#{symbol}' is expected to #{registered} (indeed #{infered}) at member access"

      # prepare for type interface
      symbol = left.data
      registered = currentScope.getVarInScope(symbol)
      infered    = guess_expr_type right

      assigning =
        if left.annotation?
          currentScope.extendTypeLiteral(left.annotation.type)
        else
          undefined

      # 型識別子が存在し、既にそのスコープで宣言済みのシンボルである場合、二重定義として例外
      #    x :: Number = 3
      # -> x :: String = "hello"
      if assigning? and registered?
        throw new Error 'double bind', symbol

      # -> x :: Number = f 4
      else if right.instanceof CS.FunctionApplication
        expected = currentScope.getVarInScope(right.function.data)

        if expected is undefined
          currentScope.setVar symbol, 'Any'
        else if assigning is expected?.returns
          currentScope.setVar symbol, assigning
        else
          throw new Error "'#{symbol}' is expected to #{assigning} indeed #{expected}, by function call"
        # TODO: argument check

      # シンボルに型識別子が存在せず、既にそのスコープで宣言済みのシンボルである場合
      # rightを再度型推論し、ダウンキャストできなければthrow
      #    x :: Number = 3
      # -> x = 5
      # TODO: ダウンキャストルールの記述
      else if registered?
        # 推論済みor anyならok
        return if symbol is 'toString'
        unless  (registered is infered) or (registered is 'Any')
          throw new Error "'#{symbol}' is expected to #{registered} indeed #{infered}, by assignee"

      # シンボルに対して 型識別子が存在する
      # -> x :: Number = 3
      else if assigning
        # 明示的なAnyは全て受け入れる
        # x :: Any = "any instance"
        if assigning is 'Any'
          currentScope.setVar symbol, 'Any'
        # TypedFunction
        # f :: Int -> Int = (n) -> n
        else if left.annotation.type.type is 'Function'
          # TODO: Fix parser
          currentScope.setVar symbol, left.annotation.type
        # オブジェクトリテラルを代入しようとしているときはとりあえず代入を許可する
        # obj :: {x :: Number} = {x : 3}
        else if (typeof assigning) is 'object'
          # TODO: オブジェクトの中身と型の確認。たぶんdeftypesを使う。
          currentScope.setVar symbol, left.annotation.type

        # 右辺の型が指定した型に一致する場合
        # x :: Number = 3 (:: A)
        else if assigning is infered
          currentScope.setVar symbol, left.annotation.type
          walk right, currentScope

        # 型が一致しないので例外を投げる
        else
          # TODO: なぜかtoStringくることがあるので握りつぶす
          return if symbol is 'toString'
          throw new Error "'#{symbol}' is expected to #{left.annotation.type} indeed #{infered}"

      # Vanilla CS
      else
        currentScope.setVar symbol, 'Any'
        walk right, currentScope

module.exports = {checkNodes}
