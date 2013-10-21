# console = {log: ->}

CS = require './nodes'

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

  setTypeObject: (symbol, type_object) ->
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
        return @getTypeInScope(str)


initializeGlobalTypes = (node) ->
  node.setTypeObject 'String', new TypeSymbol {
    type: 'String'
    instanceof: (expr) -> (typeof expr.data) is 'string'
  }

  node.setTypeObject 'Number', new TypeSymbol {
    type: 'Number'
    instanceof: (expr) -> (typeof expr.data) is 'number'
  }

  node.setTypeObject 'Boolean', new TypeSymbol {
    type: 'Boolean'
    instanceof: (expr) -> (typeof expr.data) is 'boolean'
  }

  node.setTypeObject 'Object', new TypeSymbol {
    type: 'Object'
    instanceof: (expr) -> (typeof expr.data) is 'object'
  }

  node.setTypeObject 'Any', new TypeSymbol {
    type: 'Any'
    instanceof: (expr) -> true
  }

checkNodes = (cs_ast) ->
  return unless cs_ast.body?.statements?
  # console.log cs_ast.body.statements
  # console.log '====================='
  root = new Scope
  root.name = 'root'
  for i in ['global', 'exports', 'Module', 'module']
    root.setVar i, 'Any', true
  initializeGlobalTypes(root)

  walk cs_ast.body.statements, root
  # Scope.dump root

walk = (node, currentScope) ->
  # console.log node
  switch
    # undefined(mayby body)
    when node is undefined
      return

    # Nodes Array
    when node.length?
      node.forEach (s) -> walk s, currentScope

    # Struct
    when node.type is 'struct'
      currentScope.setType node.name, node.expr

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
      objectScope = new Scope currentScope
      objectScope.name = '-lambda-'

      # register arguments to next scope
      node.parameters.map (param) ->
        try
          objectScope.setVar? param.data, (param.annotation?.type ? 'Any')
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
      else if assigning?

        # 明示的なAnyは全て受け入れる
        # x :: Any = "any instance"
        if assigning is 'Any'
          currentScope.setVar symbol, 'Any'

        # TypedFunction
        # f :: Int -> Int = (n) -> n
        else if left.annotation.type.type is 'Function'
          # TODO: Fix parser 'type.type' -> 'type'
          currentScope.setVar symbol, left.annotation.type

        # pass obj :: {x :: Number} = {x : 3}
        # ng   obj :: {x :: Number} = {x : 3}
        else if (typeof assigning) is 'object'
          for key, val of assigning
            if right.annotation.type[key] isnt val # TODO Deep equal
              throw new Error "'#{key}' is expected to #{right.annotation.type[key]}(indeed #{val})"
          currentScope.setVar symbol, left.annotation.type, false

        # 右辺の型が指定した型に一致する場合
        # x :: Number = 3
        else if assigning is infered
          currentScope.setVar symbol, left.annotation.type

        # 型が一致しないので例外を投げる
        else
          # TODO: なぜかtoStringくることがあるので握りつぶす
          return if symbol is 'toString'
          throw new Error "'#{symbol}' is expected to #{left.annotation.type} indeed #{infered}"

      # Vanilla CS
      else
        currentScope.setVar symbol, 'Any'

module.exports = {checkNodes}
