console = {log: ->}

CS = require './nodes'
{render} = require 'prettyjson'

checkNodes = (cs_ast) ->
  return unless cs_ast.body?.statements?
  console.log 'AST =================='
  console.log render cs_ast
  console.log '================== AST'
  root = new Scope
  root.name = 'root'
  for i in ['global', 'exports', 'module']
    root.addVar i, 'Any', true
  initializeGlobalTypes(root)

  walk cs_ast.body.statements, root
  # console.log 'scope ====================='
  # Scope.dump root
  console.log '================== Scope'

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

  @dump: (node, prefix = '') ->
    console.log prefix + "[#{node.name}]"
    for key, val of node._vars
      console.log prefix, ' +', key, '::', val
    for next in node.nodes
      Scope.dump next, prefix + '  '

  # {name : String, p : Point} => {name : String, p : { x: Number, y: Number}}
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

  checkFunctionLiteral: (left, right) ->
    left  = @extendTypeLiteral left
    right = @extendTypeLiteral right
    console.log 'left', left
    console.log 'right', right

    # args
    for l_arg, i in left.args
      r_arg = right.args[i]
      checkAcceptableObject(l_arg, r_arg)

    # return type
    checkAcceptableObject(left.returns, right.returns)


# pass obj :: {x :: Number} = {x : 3}
checkAcceptableObject = (left, right) ->
  if ((typeof left) is 'string') and ((typeof right) is 'string')
    if (left is right) or (left is 'Any') or (right is 'Any')
      'ok'
    else
      throw (new Error "object deep equal mismatch #{left}, #{right}")
  else if ((typeof left) is 'object') and ((typeof right) is 'object')
    for lkey, lval of left
      checkAcceptableObject(lval, right[lkey])
  else if (left is undefined) or (right is undefined)
    "ignore now"
  else
    throw (new Error "object deep equal mismatch #{left}, #{right}")

initializeGlobalTypes = (node) ->
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

  node.addTypeObject 'Any', new TypeSymbol {
    type: 'Any'
    instanceof: (expr) -> true
  }

walk = (node, currentScope) ->
  switch
    # undefined(mayby body)
    when node is undefined
      return

    # Nodes Array
    when node.length?
      node.forEach (s) -> walk s, currentScope

    # Struct
    when node.type is 'struct'
      currentScope.addType node.name, node.expr

    # Program
    when node.instanceof CS.Program
      walk node.body.statements, currentScope
      node.annotation = type: 'Program'

    # Identifier
    when node.instanceof CS.Identifier
      node.annotation ?=
        type: currentScope.getVar(node.data) ? 'Any'

    # String
    when node.instanceof CS.String
      node.annotation ?=
        type: 'String'
        implicit: true

    # Bool
    when node.instanceof CS.Bool
      node.annotation ?=
        type: 'Boolean'
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

    # Number
    # TODO: Int, Float
    when node.instanceof CS.Numbers
      node.annotation ?=
        type: 'Number'
        implicit: true
      # if node.instanceof CS.Int
      #   node.annotation ?=
      #     type: 'Int'
      #     implicit: true
      # else if node.instanceof CS.Int
      #   node.annotation ?=
      #     type: 'Float'
      #     implicit: true

    # Class
    when node.instanceof CS.Class
      walk node.body.statements, new Scope currentScope

    # Function
    when node.instanceof CS.Function
      args = node.parameters.map (param) -> param.annotation?.type ? 'Any'
      node.annotation.type.args = args

      objectScope      = new Scope currentScope
      objectScope.name = '-lambda-'

      # register arguments to next scope
      node.parameters.map (param) ->
        try
          objectScope.addVar? param.data, (param.annotation?.type ? 'Any')
        catch
          # TODO あとで調査 register.jsで壊れるっぽい
          'ignore but brake on somewhere. why?'

      walk node.body?.statements, objectScope

    # FunctionApplication
    when node.instanceof CS.FunctionApplication
      # TODO: 引数チェック
      walk node.arguments, currentScope

    # Assigning
    when node.instanceof CS.AssignOp
      left  = node.assignee
      right = node.expression

      walk right, currentScope

      # メンバーアクセス
      # hoge.fuga.bar をちゃんとやる
      if left.memberName?
        symbol = left.expression.data
        registered = currentScope.getVarInScope(symbol) # Object
        return unless registered? # TODO: maybe global defined

        expected = registered[left.memberName] # ClassName
        infered    = right.annotation?.type

        if expected? and (expected is infered) or (registered is 'Any')
          ''
        else
          throw new Error "'#{symbol}' is expected to #{registered} (indeed #{infered}) at member access"

      # prepare for type interface
      symbol     = left.data
      registered = currentScope.getVarInScope(symbol)
      infered    = right.annotation?.type

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
          currentScope.addVar symbol, 'Any'
        else if assigning is expected?.returns
          currentScope.addVar symbol, assigning
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
      else if assigning?
        # 明示的なAnyは全て受け入れる
        # x :: Any = "any instance"
        if assigning is 'Any'
          currentScope.addVar symbol, 'Any'

        # TypedFunction
        # f :: Int -> Int = (n) -> n
        else if left.annotation.type.args? and right.annotation.type.args?
          # TODO: ノードを推論した結果、関数になる場合はok
          if right.instanceof CS.Function
            currentScope.checkFunctionLiteral(left.annotation.type, right.annotation.type)
          else
            throw new Error "assigining right is function"

          currentScope.addVar symbol, left.annotation.type
          # TODO 右辺の推論した型と比較

        else if (typeof assigning) is 'object'
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

      # Vanilla CS
      else
        currentScope.addVar symbol, 'Any'

module.exports = {checkNodes}
