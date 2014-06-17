{initializeGlobalTypes} = require '../lib/types'
reporter = require '../lib/reporter'

parse = (coffee) ->
  reporter.clean()
  parse coffee

shouldBeTypeError = (input) ->
  try
    CoffeeScript.parse input
  catch e
    ok /TypeError/.test e
    return
  throw 'must be type error but parsed'

shouldBeError = (input) ->
  try
    CoffeeScript.parse input
  catch e
    return
  throw 'must be error but parsed'

root = window ? global ? this
root._module_ = (ns, f, context = root) =>
  context ?= root
  hist = []
  for name in ns.split('.')
    unless context[name]?
      context[name] = {}
    context = context[name]
    hist.push context
  f.apply context, hist

suite 'Module', ->
  test 'module', ->
    module X
      @x = 3
    eq X.x, 3

  test 'nested module', ->
    module X.Y
      @x = 3
    eq X.Y.x, 3

suite 'TypeChecker', ->
  setup ->
    global._root_.vars = []
    global._root_.types = []
    global._root_._this = []
    global._root_._modules = []
    initializeGlobalTypes(global._root_)
    reporter.clean()

  suite 'Primitive', ->
    test 'int', ->
      x :: Int = 3

    test 'int', ->
      x :: Int = 3 + 3

    test 'string', ->
      x :: String = ''

    test 'string', ->
      x :: String = '' + ''

    test 'boolean', ->
      x :: Boolean = true

    test 'boolean', ->
      x :: Boolean = 1 is 2

    test 'boolean', ->
      x :: Null = null

    test 'boolean', ->
      x :: Undefined = undefined

  suite 'Assignment', ->
    test 'basic assign', ->
      x :: Int = 3
      eq x, 3

    test 'int assign', ->
      x :: Number = 3

    test 'pre-defined syntax', ->
      a :: Number
      a = 3

    test 'throw pre-defined', ->
      shouldBeTypeError """
      bbb :: Number
      bbb = "str"
      """

    test 'throw pre-defined', ->
      shouldBeTypeError """
      i :: Int
      i :: Float
      """

    test 'pre-defined function', ->
      a :: Number -> Number
      a = (n) -> n

    test 'assign to implicit any', ->
      a = global
      a :: {toString :: Any}

    test 'assign to implicit any', ->
      shouldBeError """
      a = global
      a :: {toString :: Any}
      a :: Int
      """

    test 'apply float to int', ->
      shouldBeTypeError """
      x :: Int = 3.5
      """

    test 'apply string to int', ->
      shouldBeTypeError """
      x :: Int = 'a'
      """

    test 'throw type mismatch', ->
      shouldBeTypeError """
      x :: Number = "3"
      """

    test 'primitive extended assign', ->
      x :: Int = 3
      y :: Number = x

    test 'primitive extended assign', ->
      x :: Int = 3
      y :: Float = x

    test 'throw primitive extended assign', ->
      shouldBeTypeError """
      x :: Float = 3.3
      y :: Int = x
      """

    test 'basic assign', ->
      x :: Int = 3
      x = 5
      eq x, 5

    test 'any type thorough everything', ->
      a :: Any = 3
      a = false
      eq a, false

  suite 'destructive assignment', ->
    test 'destructive assignment', ->
      a :: Int
      {a, b, c} = {a: 3, b:5, c:6}

    test 'throw destructive assignment', ->
      shouldBeTypeError """
      a :: String
      {a, b, c} = {a: 3, b:5, c:6}
      """

    test 'destructive assignment', ->
      a :: Int
      b :: String
      c :: Int
      {a, b, c} = {a: 3, b: '', c: 1}

    test 'struct with implements', ->
      struct A
        a :: Int

      struct B implements A
        b :: Int

      b :: B
      b = {a: 1, b: 2}
      obj :: {a :: Int, b :: Int} = b

    test 'struct with implements', ->
      shouldBeTypeError """
      struct A
        a :: Int

      struct B implements A
        b :: Int

      a :: A
      a = {a: 1, b: 2}
      obj :: {a :: Int, b :: Int} = a
      """

    test 'destructive assignment', ->
      struct Point
        x :: Int
        y :: Int
      p :: Point = {x: 1, y: 2}

      x :: Int
      y :: Int
      {x, y} = p

    test 'destructive assignment', ->
      shouldBeTypeError """
      struct Point
        x :: Int
        y :: Int
      p :: Point = {x: 1, y: 2}

      x :: Int
      y :: String
      {x, y} = p
      """

    test 'destructive assignment', ->
      shouldBeTypeError """
      a :: Int
      b :: String
      c :: Int
      {a, b, c} = {a: 3, b: 1, c: 1}
      """

    test 'destructive assignment', ->
      a :: Int
      [a, b, c] = [1, 2, 3]

    test 'destructive assignment', ->
      shouldBeTypeError """
      a :: Int
      {a, b, c} = [1, 2, 3]
      """

    test 'destructive assignment', ->
      shouldBeTypeError """
      a :: String
      [a, b, c] = [3, 5, 6]
      """

    test 'destructive assignment', ->
      shouldBeTypeError """
      a :: Int
      b :: String
      [a, b, c] = [3, 5, 6]
      """

    test 'destructive assignment', ->
      list :: Int[] = [1..10]
      a :: Int
      [a, b] = list

    test 'destructive assignment', ->
      shouldBeTypeError """
      list :: Int[] = [1..10]
      a :: Int
      b :: String

      [a, b] = list
      """

  suite 'Struct', ->
    test 'object assign', ->
      obj :: {x :: Number} = {x : 2 }

    test 'object literal with newline', ->
      p :: {
        x :: Number
        y :: Number
      } = {x : 1, y: 5}

    test 'struct definition without blace', ->
      struct Point {
        x :: Int
        y :: Int
      }

    test 'struct definition without blace', ->
      struct Point
        x :: Int
        y :: Int

    test 'struct definition without blace', ->
      struct A {}
      struct B {}
      struct Point
        x :: A
        y :: B

    test 'struct definition without blace', ->
      struct Point
        x :: Int
        y :: Int
      p :: Point = {x: 3, y: 3}

    test 'struct with namespace', ->
      struct A.B.Point
        x :: Int
        y :: Int

      p :: A.B.Point = {x: 1, y: 3}

    test 'struct definition without blace', ->
      shouldBeTypeError """
      struct Point
        x :: Int
        y :: String
      p :: Point = {x: 3, y: 3}
      """

    test 'struct definition without blace', ->
      shouldBeTypeError """
      struct Point
        x :: Int
        y :: Int
      p :: Point = {x: "", y: 3}
      """

    test 'struct definition with symbol', ->
      struct A
        num :: Int

      struct Point
        x :: Int
        y ::
          a :: A
          b :: String

      p :: Point = {x: 3, y: {a : {num: 4} , b : 'foo'}}

    test 'nested struct definition', ->
      struct Point
        x :: Int
        y ::
          a :: Int
          b :: String

      p :: Point = {x: 3, y: {a : 1 , b : 'foo'}}

    test 'throw struct member access with mismatch type', ->
      shouldBeTypeError """
        struct Point {
          x :: Int
          y :: Int
        }
        p :: Point = {x:3, y:3}
        p.x = "hoge"
      """

    test 'throw when function args mismatch', ->
      shouldBeTypeError """
      f :: Number * String -> String = (n, s) ->
        a :: Number = s
      """

    test 'throw pre-defined args mismatch', ->
      shouldBeTypeError """
      a :: Number -> Number
      a = (n) ->
        n2 :: String = n """


    test 'throw object literal mitmatching', ->
      shouldBeTypeError """
        obj :: { x :: Number } = { x : '' }
      """

    test 'throw at lacking of object member', ->
      shouldBeTypeError """
        obj :: { x :: Number, y :: Number } = { x : 3 }
      """

    test 'throw member access error', ->
      shouldBeTypeError """
        obj :: { x :: Number } = { x : 3 }
        obj.x = ""
      """

  suite 'Nullable', ->
    test 'nullable', ->
      a :: Int? = 1

    test 'nullable', ->
      a :: Int? = null

    test 'nullable', ->
      a :: Int? = undefined

    test 'nullable', ->
      shouldBeTypeError """
      a :: Int? = ''
      """

    test 'nullable member', ->
      struct A
        a :: Int?
      a :: A = {}

    test 'nullable member', ->
      struct A
        a :: Int?
      a :: A = a: null

    test 'nullable member', ->
      struct A
        a :: Int?
      a :: A = a: undefined

    test 'nullable member', ->
      struct A
        a :: Int?
      a :: A = a: 1

    test 'nullable member', ->
      shouldBeTypeError """
      struct A
        a :: Int?
      a :: A = a: ''
      """

    test 'nullable assign', ->
      nn :: Int? = 1
      n :: Int? = nn

    test 'nullable assign', ->
      shouldBeTypeError """
      nn :: Int? = 1
      n :: Int = nn
      """

  suite 'Explicit Rules', ->
    test 'type propagation', ->
      a :: Int = 3
      b = a

    test 'throw type propagation', ->
      shouldBeTypeError """
      a :: Int = 3
      b = a
      b = "Hoge"
      """

    test 'type propagationw with member access', ->
      a :: {x :: Int, y :: Int} = {x: 3, y: 5}
      b :: Int = a.x

    test 'throw explicit with member access', ->
      shouldBeTypeError """
      a :: {x :: Int, y :: Int} = {x: 3, y: 5}
      b = a.x
      b = "hoge"
      """

  suite 'Function', ->
    test 'assign function', ->
      f :: Int -> Int = (n) -> n

    test 'assign function', ->
      struct A
        x :: Int
        y :: Int
      getX :: A -> Int
      getX = ({x, y}) -> x

    test 'assign function', ->
      shouldBeTypeError """
      struct A
        x :: Int
        y :: Int
      getX :: A -> String
      getX = ({x, y}) -> x
      """

    test 'assign function', ->
      getX :: Int[] -> Int
      getX = ([x, y]) -> x
      getX [1, 2]

    test 'assign function', ->
      shouldBeTypeError """
      getX :: Int[] -> String
      getX = ([x, y]) -> x
      """

    test 'assign function', ->
      shouldBeTypeError """
      getX :: String[] -> Int
      getX = ([x, y]) -> x
      """

    test 'assign function', ->
      f :: Int -> Int = (@n) ->
        n :: Int = 1
        n

    test 'assign function', ->
      shouldBeTypeError """
      f :: Int -> Int = (@n) ->
        n
      """

    test 'typed function', ->
      f :: Number -> Number = (n :: Number) :: Number ->  n * n

    test 'typed function', ->
      f = (n :: Number) :: Number ->  n * n

    test 'assign function', ->
      f :: Int -> Int = (n) -> n
      g :: Int -> Int = f

    test 'typed function return type error', ->
      shouldBeTypeError """
      f :: Number -> String = (n :: Number) :: String ->  n * n
      """

    test 'typed function that has 2 arguments', ->
      f :: Number * Number -> Number = (n :: Number, m :: Number) :: Number ->  n * m

    test 'typed function that has 2 arguments', ->
      f :: (Number, Number) -> Number = (n :: Number, m :: Number) :: Number ->  n * m

    test 'typed function that has 2 arguments', ->
      f :: Number * Number -> Number = (n, m) ->  n * m

    test 'typed function that has 2 arguments', ->
      f :: Number * Number -> Number = (n, m) :: Number ->  n * m

    test 'typed function that has 3 arguments', ->
      f :: Number * Number * Number -> Number = (n :: Number, m :: Number, r :: Number) :: Number ->  n * m * r

    test 'typed function type mismatch', ->
      shouldBeTypeError """
      f :: Number -> Number = (n :: Number) :: String ->  n * n
      """

    test 'typed function mismatching application', ->
      shouldBeTypeError """
      f :: Number -> Number = 3
      """

    test 'typed function mismatching application', ->
      shouldBeTypeError """
      f :: Number -> Number = {}
      """

    test 'throw function return type mismatch', ->
      shouldBeTypeError """
      f0 :: () -> Number = () :: Number -> ''
      """

    test 'typed function', ->
      f = (n :: Int) ->  n * n
      n :: Int = f(3)

    test 'typed function return type error', ->
      shouldBeTypeError """
      f :: Number -> Number = (n :: Number) :: String ->  n * n
      """

    # test 'typed function return type error', ->
    #   shouldBeTypeError """
    #   f = (n :: Number) :: String ->  n * n
    #   """

    test 'splats', ->
      f :: Int... -> Int[]
      f = (args...) ->
        args
      f 1, 2, 3

    test 'splats', ->
      shouldBeTypeError """
      f :: Int... -> Int[]
      f = (args...) ->
        args
      f 1, '', 3
      """

    test 'splats', ->
      f :: String * Int... -> Int[]
      f = (s, args...) ->
        args
      f '', 1, 2, 3

    test 'splats', ->
      shouldBeTypeError """
      f :: String * Int... -> Int[]
      f = (s, args...) ->
        args
      f '', '', 3
      """

  suite 'FunctionApplication', ->
    test 'typed function and binding', ->
      f :: Int -> Int = (n :: Int) ->  n * n
      n :: Int  = f 4

    test 'typed function with return type', ->
      f :: Int -> Int = (n :: Int) :: Int ->  n * n
      n :: Int  = f 4

    test 'throw function arguments mismatch', ->
      shouldBeTypeError """
        f :: Number -> Number = (n :: Number) :: Number ->  n * n
        (f "hello")
      """

    test 'function application', ->
      f :: Int -> Int = (n :: Int) :: Int ->  n * n
      x :: Int = (f 3)

    test 'throw function arguments mismatch', ->
      shouldBeTypeError """
      f :: Int -> Int = (n :: Int) :: Int ->  n * n
      y :: String = (f 3)
      """

    test 'return function type', ->
      f :: Int -> Int -> Int = (n) -> (m) -> n * m

    test 'return function type', ->
      f :: Int -> Int -> Int = (n) -> (m) -> n * m
      f2 :: Int -> Int = f(2)

    test 'return function type', ->
      f :: Int -> Int -> Int = (n) -> (m) -> n * m
      n :: Int = f(2)(3)

    test 'return function type', ->
      shouldBeTypeError """
      f :: Int -> Int -> Int = (n) -> (m) -> n * m
      n :: Int = f("")(3)
      """

    test 'return function type', ->
      shouldBeTypeError """
      f :: Int -> Int -> Int = (n) -> (m) -> n * m
      n :: Int = f(2)("")
      """

    test 'return function type', ->
      shouldBeTypeError """
      f :: Int -> Int -> Int = (n) -> (m) -> n * m
      n :: String = f(2)(3)
      """

    test 'return function type', ->
      f :: Int -> Int * String -> Int = (n) -> (m, str) -> n * m

    test 'return function type', ->
      f :: Int -> Int * String -> Int
      f = (n) -> (m, str) -> n * m
      f(1)(2, 'hey!')

  suite 'BinOps', ->
    test 'BinOps Num', ->
      a :: Number = (3 + 3 * 6) / 2

    test 'BinOps Int * Int -> Int', ->
      a :: Int = 3 + 5

    test 'BinOps Int * Float -> Float', ->
      a :: Float = 3 + 5.5

    test 'throw BinOps Int * Int -> Int', ->
      shouldBeTypeError """
      a :: Int = 3 + 5.5
      """

    test 'BinOps String', ->
      a :: String = "hello" + "world"

    test 'miscast BinOp', ->
      shouldBeTypeError """
      c :: Number = "" + 3
      """

  suite 'Void', ->
    test 'void', ->
      nf :: () -> () = -> setTimeout (->), 100
      nf()

    test 'void keyword', ->
      nf :: () -> Void = -> setTimeout (->), 100
      nf()

  suite 'Array', ->
    test 'typed array', ->
      arr :: Int[] = [1, 2, 3]

    test 'typed array', ->
      shouldBeTypeError """
      arr :: Int[] = [1, 2.1, 3]
      """

    test 'typed array', ->
      arr :: Float[] = [1, 2.1, 3]

    test 'typed array', ->
      struct Point
        x :: Number
        y :: Number
      p :: Point = x: 3, y: 2
      tarr :: Point[]  = [{x : 3, y: 3}, {x : 3, y: 3}, p]

    test 'typed array', ->
      struct S
        x :: Number
      tarr :: S[] = [{x: 1, y: 2}, {x: 1}]

    test 'typed array', ->
      shouldBeTypeError """
      struct S
        x :: Number
        y :: Number
      tarr :: S[] = [{x: 1, y: 2}, {x: 1}]
      """

    test 'typed array', ->
      n :: Int? = 1
      arr :: Int?[] = [1, n, 3]

    test 'typed array', ->
      shouldBeTypeError """
      n :: Int? = 1
      arr :: Int[] = [1, n, 3]
      """

    test 'typed array', ->
      arr :: Int?[] = [1, null, 3]

    test 'typed array', ->
      shouldBeTypeError """
      arr :: Int[] = [1, null, 3]
      """

  suite 'Range', ->
    test 'Range', ->
      list :: Number[] = [1..10]

    test 'Range', ->
      list :: Int[] = [1..10]

    test 'Range', ->
      list :: Int[]? = [1..10]

    test 'Range', ->
      list :: Int[]? = null

    test 'Range', ->
      list :: Int?[]? = [1..10]

    test 'Range', ->
      list :: Int?[]? = null

    test 'Range', ->
      shouldBeTypeError """
      list :: Number[] = 1
      """

    test 'throw function return type mismatch', ->
      shouldBeTypeError """
      list :: String[] = [1..10]
      """

  suite 'For', ->
    test 'for in' , ->
      list :: Number[] =
        for i :: Number, n in [1..3]
          i

    test 'for of' , ->
      list :: Number[] =
        for key, val of {a: 1, b: 2}
          1

    test 'for in' , ->
      struct Point
        x :: Int
        y :: Int

      list :: Point[] =
        for i :: Int, n in [1..3]
          {x: 1, y: 2}

    test 'for in' , ->
      list :: Int?[] =
        for i in [1..10]
          if true
            1
          else
            null

    test 'for in' , ->
      list :: Int?[] =
        for i in [1..10]
          if true
            1

    test 'for in' , ->
      list :: Int[] =
        for i in [1..10]
          if true
            1
          else
            2

    test 'for in' , ->
      shouldBeTypeError """
      list :: Int?[] =
        for i in [1..10]
          if true
            1
          else
            ''
      """

    test 'for in' , ->
      shouldBeTypeError """
      struct Point
        x :: Int
        y :: Int

      list :: Point[] =
        for i :: Int, n in [1..3]
          i
      """

    test 'for in' , ->
      shouldBeTypeError """
      list :: String[] =
        for i :: Number, n in [1..3]
          i
      """

    test 'for of', ->
      list :: Number[] =
        for key :: String, val :: Number of {x: 77, y: 6}
          val

  suite 'if', ->
    test 'if expr', ->
      n :: Int =
        if true
          1
        else if false
          2
        else
          3

    test 'if expr', ->
      n :: Number =
        if true
          1
        else if false
          1.1
        else
          1

    test 'if expr', ->
      shouldBeTypeError """
      n :: Int =
        if true
          1
        else if false
          ''
        else
          3
      """

    test 'if expr', ->
      n :: { x :: Number } =
        if true
          x: 1
        else if false
          x: 1, y: 2
        else
          x: 1, y: 2, z: 3

    test 'if expr', ->
      shouldBeTypeError """
      n :: { x :: Number, y :: Number} =
        if true
          {x: 1}
        else if false
          {x: 1, y: 2}
        else
          {x: 1, y: 2, z: 3}
      """

    test 'if expr', ->
      shouldBeTypeError """
      n :: { x :: String} =
        if true
          {x: 1}
        else if false
          {x: 1, y: 2}
        else
          {x: 1, y: 2, z: 3}
      """

    test 'if expr without altenative', ->
      n :: Int? =
        if true
          1

    test 'if expr without altenative', ->
      n :: Int? = if true then 1

    test 'if expr without altenative', ->
      shouldBeTypeError """
      n :: Int = if true then 1
      """

    test 'if expr without altenative', ->
      n :: Int = if true then 1 else 1

    test 'throw if return type mismatch', ->
      shouldBeTypeError """
        a :: Number = if true then 3 else ""
      """

    test.skip 'throw return type mismatch', ->
      shouldBeTypeError """
        arr :: Number[] = ("" for i in [1,2,3])
      """

    test.skip 'throw return type mismatch', ->
      arr :: Number[] = (i for i in [1,2,3])

    test 'throw target mismatch', ->
      shouldBeTypeError """
      arr :: Number[] = (i for i in [1,2,""])
    """

    # test 'throw target mismatch', ->
    #   shouldBeTypeError """
    #     list :: Number[] =
    #       for key :: String, val :: Number of {x: "hoge", y: 6}
    #         val
    #   """

  suite 'Return', ->
    test 'return', ->
      f :: Int -> Int = ->
        if true
          return 3
        if false
          return 2
        return 1

    test 'return', ->
      f :: Int -> Int? = ->
        if true
          return null
        if false
          return null
        return 1

    test 'return', ->
      shouldBeTypeError """
      f :: Int -> Int = ->
        if true
          return ''
        if true
          return ''
        return 1
      """

    test 'return', ->
      shouldBeTypeError """
      f :: Int -> Int = ->
        if true
          return null
        if false
          return null
        return 1
      """

    test 'function return type', ->
      f2 :: () -> Int = ->
        return 3

    test 'throw function return type mismatch', ->
      shouldBeTypeError """
      f2 :: () -> Number = ->
        return ""
      """

  suite 'Switch', ->
    test 'Switch', ->
      x :: String? =
        switch true
          when 0
            'foo'
          when 1
            'bar'

    test 'Switch', ->
      x :: Number =
        switch true
          when 0
            1
          when 1
            2.5
          else
            3.1

    test 'switch', ->
      n :: { x :: Int } =
        switch 1
          when 1
            x: 1
          when 2
            x: 1, y: 2
          else 2
            x: 1, y: 2, z: 3

    test 'Switch', ->
      x :: String =
        switch true
          when 0
            'foo'
          when 1
            'bar'
          else
            'fuga'

    test 'Switch', ->
      shouldBeTypeError """
      x :: String =
        switch true
          when 0
            'foo'
          when 1
            1
      """

  suite 'Class', ->
    test 'define class', ->
      class A
        name :: String

    test 'nested class', ->
      class A
      class A.B
      class A.B.C
        name :: Int
      abc = new A.B.C
      n :: Int = abc.name

    test 'nested class', ->
      class A
      class A.B
      class A.B.C
        p :: Int
      class A.B.D
        p :: Int

      abd = new A.B.D
      n :: Int = abd.p

    test 'nested class', ->
      shouldBeTypeError """
      class A
      class A.B
      class A.B.C
        name :: String
      abc = new A.B.C
      n :: Int = abc.name
      """

    test 'throw double assignment', ->
      shouldBeError """
      class A
        name :: String
        name :: Int
      """

    test 'define class', ->
      class A
        @name :: String
      s :: String = A.name

    test 'define class', ->
      shouldBeError """
      class A
        @name :: String
      s :: Int = A.name
      """

    test 'define class', ->
      class A
        @foo :: String
      class B extends A
      s :: String = B.foo

    test 'define class', ->
      shouldBeTypeError """
      class A
        @foo :: String
      class B extends A
      s :: Int = B.foo
      """

    suite 'constructor', ->
      test 'define class with pre defined arugments', ->
        class A
          constructor :: String -> ()
          constructor: (name :: String) ->

      test 'define class with pre defined arguments', ->
        class A
          constructor :: () -> ()
          constructor: () ->

      test 'throw constructor arguments', ->
        shouldBeTypeError '''
        class A
          constructor :: String -> ()
          constructor: (name :: Int) ->
        '''

      test 'throw unmatched constructor arguments', ->
        shouldBeTypeError '''
        class A
          constructor :: String -> ()
          constructor: (name :: String, foo :: Int) ->
        '''

      test 'this member access', ->
        class A
          name :: String
          constructor :: String -> ()
          constructor: (name :: String) ->
            @name = name

      test 'throw member assignment', ->
        shouldBeTypeError """
        class A
          name :: String
          constructor: ->
            @name = 3
        """

    suite 'classProtoAssign', ->
      test 'throw member assignment', ->
        class A
          f :: Int -> Int
          f: (n :: Int) -> n

      test 'throw member assignment', ->
        shouldBeTypeError """
        class A
          f :: Int -> Int
          f: (n :: String) -> n
        """

    test 'throw return type in class', ->
      shouldBeTypeError """
      class X
        text :: String
        f :: Number -> Number
        f: (n) ->
          @text = n.toString()
      """

    test 'throw pre-defined args mismatch in class', ->
      shouldBeTypeError """
      class X
        text :: String
        f :: Number -> Number
        f: (n) ->
          @text = n
          1
      """

    test 'bound function', ->
      class A
        name :: String
        f: ->
          setTimeout =>
            @name = ''

    test 'bound function', ->
      shouldBeTypeError '''
      class A
        name :: String
        f: ->
          setTimeout =>
            @name = 1
      '''

    suite 'MemberAccess in class', ->
      test 'access this in class', ->
        class X
          foo :: Number
          constructor: ->
            @foo = 3

      test 'access this in class', ->
        shouldBeTypeError """
        class X
          foo :: Number
          constructor: ->
            @foo = ''
        """

      test 'access this proto in class', ->
        class Y
          foo :: Number
          bar: ->
            @foo = 3

      test 'receive this', ->
        class X
          x :: Int
          f: (@x) -> 3

      test 'receive this', ->
        class X
          x :: Int
          f :: Int -> Int
          f: (@x) -> 3
        x = new X
        x.f 3

      test 'receive this', ->
        shouldBeTypeError """
        class X
          x :: Int
          f :: Int -> Int
          f: (@x) -> 3
        x = new X
        x.f ""
        """

      # test 'throw destructive assignment', ->
      #   shouldBeTypeError """
      #   class X
      #     x :: String
      #     f :: Int -> Int
      #     f: (@x) -> {b:5, c:6}
      #   """

    suite 'Extends', ->
      test 'extends', ->
        class A
          a :: String
        class B extends A
          b :: String
        b :: { a :: String, b :: String} = new B

      test 'extends', ->
        class A
          a :: Int

        class B extends A
          b :: Int

        class C extends B
          c :: Int

        c :: {a :: Int, b :: Int, c :: Int}
        c = new C

      test 'extends', ->
        class A
          a :: Int

        class B extends A
          b :: Int

        class C extends B
          c :: Int
        c :: A
        c = new C

      test 'extends', ->
        shouldBeTypeError """
        class A
          a :: String

        class B extends A
          b :: Int

        class C extends B
          c :: Int
        c :: {a :: Int, b :: Int, c :: Int}
        c = new C
        """

      test 'extends', ->
        class A
          a :: String
        class B extends A
          b :: String
        b1 :: A = new B
        b2 :: B = new B

      test 'down cast', ->
        class A
          a :: String
        class B extends A
          b :: String
        b :: A = new B
        str :: String = b.a

      test 'throw down cast', ->
        shouldBeTypeError """
        class A
          a :: String
        class B extends A
          b :: String
        b :: A = new B
        str :: String = b.b
        """

      test 'extends properties', ->
        class Point
          x :: Int
          y :: Int

        class Entity extends Point
          width  :: Int
          height :: Int

        e :: {x :: Int, y :: Int} = new Entity


  suite 'Generics', ->
    # test 'throw generics object', ->
    #   shouldBeTypeError """
    #   struct Hash<K, V> {
    #     get :: K -> V
    #     set :: K * V -> ()
    #   }

    #   hash :: Hash<String, Number> =
    #     get: (key) -> @[key]
    #     set: (key, val) -> @[key] = val

    #   hash.set "", 1
    #   hash.get 1
    #   """

  suite 'NewOp', ->

    test 'new', ->
      class A
      a = new A

    test 'new', ->
      class A
        text :: String
      a = new A
      s :: String = a.text

    test 'new', ->
      shouldBeTypeError """
      class A
      a :: { num :: Number } = new A
      """

    test 'new', ->
      shouldBeTypeError """
      class A
        text :: String
      a = new A
      s :: Int = a.text
      """

    suite 'constructor', ->
      test 'constructor annotation', ->
        class A
          constructor :: Int -> ()
        a :: A = new A 3

      test 'constructor', ->
        class A
          constructor :: Int -> ()
          constructor: (n) ->
        a :: A = new A 3

      test 'constructor', ->
        shouldBeTypeError """
        class A
          constructor :: Int -> ()
        new A ''
        """

    test 'new', ->
      shouldBeError """
      struct S
        foo :: String
      class A
        bar: String

      a :: S = new A
      """

    test 'new', ->
      shouldBeTypeError """
      struct S
        foo :: String
      class A
      a :: S = new A
      """

    test 'new', ->
      class X
        f :: Number -> Number
        f: (n) -> n * n
      x :: X = new X
      n :: Number = x.f 3

    test 'access proto this in class', ->
      class X
        constructor :: Number * String -> ()
        constructor: (num, fuga) ->
          @num = num
      x :: X = new X 3, ""

    test 'throw access proto this in class', ->
      shouldBeTypeError """
      class X
        constructor :: Number -> ()
        constructor: (num, fuga) ->
          @num = num
      x :: X = new X ""
      """

    test 'new', ->
      shouldBeTypeError """
      class X
        f :: Number -> Number
        f: (n) -> n * n
      x :: X = new X
      n :: String = x.f 3
      """

  suite 'Generics', ->
    test 'generics', ->
      struct Id<A>
        id :: A
      obj :: Id<Int> = {id: 1}

    test 'generics', ->
      struct Entity.Id<A, B>
        id :: A
        content :: B
      obj1 :: Entity.Id<Int, String> = {id: 1, content: ''}

    test 'generics', ->
      shouldBeTypeError """
      struct Entity.Id<A, B>
        id :: A
        content :: B
      obj1 :: Id<Int> = {id: 1}
      """

    test 'generics', ->
      shouldBeError """
      struct Id<A, B>
        id      :: A
        content :: B
      obj1 :: Id<Int, String> = {id: '', content: ''}
      """

    test 'generics', ->
      struct Id<A, B>
        nested ::
          a :: A
          b :: B

      obj :: Id<Int, String> =
        nested:
          a: 1
          b: ''

    test 'generics', ->
      shouldBeTypeError """
      struct Id<A, B>
        nested ::
          a :: A
          b :: B

      obj :: Id<Int, String> =
        nested:
          a: 1
          b: 1
      """

    test 'generics', ->
      struct Point
        x :: Int
        y :: Int
      struct Id<A>
        nested ::
          p :: A
      obj :: Id<Point> =
        nested:
          p:
            x: 1
            y: 2

    test 'generics', ->
      shouldBeTypeError """
      struct Point
        x :: Int
        y :: Int
      struct Id<A>
        nested ::
          p :: A
      obj :: Id<Point> =
        nested:
          p:
            x: ''
            y: 2
      """

    test 'generics', ->
      struct Value<T, U>
        value :: T
      struct Id<A, B>
        id :: Value<A, B>
      obj :: Id<Int, String> =
        id:
          value: 1

    test 'generics', ->
      struct Value<T, U>
        value :: U
      struct Id<A, B>
        id :: Value<A, B>
      obj :: Id<Int, String> =
        id:
          value: ''

    test 'generics', ->
      shouldBeTypeError """
      struct Value<T, U>
        value :: U
      struct Id<A, B>
        id :: Value<A, B>
      obj :: Id<Int, String> =
        id:
          value: 1
      """

    test 'generics', ->
      struct Value<T>
        value :: T
      struct Id<A>
        id :: A
      obj :: Id<Value<Int>> =
        id:
          value: 1

    test 'generics', ->
      shouldBeTypeError """
      struct Value<T>
        value :: T
      struct Id<A>
        id :: A
      obj :: Id<Value<Int>> =
        id:
          value: ''
      """

    test 'generics', ->
      struct Id<T>
        list :: T[]
      obj :: Id<Int> =
        list: [1..10]

    test 'generics', ->
      shouldBeTypeError """
      struct Id<T>
        list :: T[]
      obj :: Id<String> =
        list: [1..10]
      """

    test 'generics', ->
      class C<A>
        a :: A

    test 'generics', ->
      class C<A>
        f :: A -> A

    test 'generics', ->
      class C<A>
        a :: A
        f :: A -> A
        f: (a) -> a

    test 'generics', ->
      shouldBeTypeError """
      class C<A>
        f :: A -> A
        f: (a) -> 1
      """

    test 'generics', ->
      class C<A>
        a :: A
        f :: A -> A
        f: (a) -> @a

    test 'generics', ->
      class C<A, B>
        b :: B
        f :: A -> B
        f: (a) -> @b

    test 'generics', ->
      shouldBeTypeError """
      class C<A, B>
        b :: B
        f :: A -> A
        f: (a) -> @b
      """

    test 'generics', ->
      shouldBeTypeError """
      class C<A, B>
        f :: B -> A
        f: (b) -> b
      """

    test 'generics', ->
      class C<A, B>
        a :: A
        b :: B
      c = new C<Int, String>
      num :: Int = c.a
      str :: String = c.b

    test 'generics', ->
      shouldBeTypeError """
      class C<A, B>
        a :: A
        b :: B
      c = new C<Int, String>
      num :: Int = c.a
      str :: String = c.a
      """

    test 'generics', ->
      shouldBeTypeError """
      class C<A, B>
        a :: A
        b :: B
      c = new C<String, String>
      num :: Int = c.a
      str :: String = c.a
      """

    test 'generics', ->
      class C<A>
        f :: Int -> Int
        constructor :: A -> ()
        constructor: (a) ->
      c = new C<Int>(1)

    test 'generics', ->
      class C<A>
        constructor :: A -> ()
        constructor: () ->
      c = new C<Int>()

    test 'generics', ->
      class C<A>
        constructor :: A -> ()
        constructor: () ->
      c = new C<Int>

    test 'generics', ->
      class C<A>
        f :: Int -> Int
        constructor :: A -> ()
      c = new C<Int>(1)

    test 'generics', ->
      shouldBeTypeError """
      class C<A>
        constructor :: A -> ()
        constructor: (a) ->
      c = new C<Int>('')
      """

    test 'generics', ->
      shouldBeTypeError """
      class C<A>
        f :: Int -> Int
        constructor :: A -> ()
        constructor: (a) ->
      c = new C<Int>('')
      """

    test 'generics', ->
      class C<A, B>
        b :: B
        f :: Int -> B
        f: (n) -> @b
        constructor :: A -> ()
      c = new C<Int, String>(1)
      n :: String = c.f 3

    test 'funciton with type argumnets', ->
      parseInt<T> :: String -> T
      n :: Int = parseInt<Int> '3'

    test 'funciton with type argumnets', ->
      parseInt<T> :: T -> Int
      n :: Int = parseInt<String> '3'

    test 'funciton with type argumnets', ->
      map<T, U> :: T[] * (T -> U) -> U[]
      map = (list, fn) ->
        for i in list
          fn(i)

    test 'funciton with type argumnets', ->
      shouldBeTypeError """
      map<T, U> :: T[] * (T -> U) -> U[]
      map = (list, fn) ->
        1 for i in list
      """

    test 'funciton with type argumnets', ->
      map<T, U> :: T[] * (T -> U) -> U[]
      map = (list, fn) ->
        fn(i) for i in list
      list :: String[] = map<Int, String> [1..10], (i) -> ''

    test 'funciton with type argumnets', ->
      shouldBeTypeError """
      map<T, U> :: T[] * (T -> U) -> U[]
      map = (list, fn) ->
        fn(i) for i in list
      list :: String[] = map<Int, String> [1..10], (i) -> i
      """

    test 'funciton with type argumnets', ->
      shouldBeTypeError """
      map<T, U> :: T[] * (T -> U) -> U[]
      map = (list, fn) ->
        fn(i) for i in list
      list :: Int[] = map<Int, String> [1..10], (i) -> ''
      """

  suite "implements", ->
    test 'implements', ->
      struct Size
        width  :: Int
        height :: Int
      class Entity implements Size
      e :: {width :: Int, height :: Int} = new Entity

    test 'multi class implements and extends', ->
      class Point
        x :: Int
        y :: Int

      struct Size
        width  :: Int
        height :: Int
      class Entity extends Object implements Point, Size
      e :: {x :: Int, width :: Int} = new Entity

    test 'throw implements', ->
      shouldBeTypeError """
      struct Size
        width  :: Int
        height :: Int
      class Entity implements Size
      e :: {z :: Int} = new Entity
      """

    test 'implement with MemberAccess', ->
      class A
      class A.B
      class A.B.C2
        a :: Int

      struct S2 implements A.B.C2
        b :: Int

      s :: {a :: Int, b :: Int} = {a: 1, b: 1}
      t :: S2 = s

    test 'implement with MemberAccess', ->
      shouldBeTypeError """
      class A
      class A.B
      class A.B.C
        a :: Int

      struct S implements A.B.C
        b :: Int

      s :: {a :: Int} = {a: 1, b: 1}
      t :: S = s
    """

    test 'implement with MemberAccess', ->
      class A
      class A.B
        a :: Int

      struct S.T implements A.B
        b :: Int

      s :: {a :: Int, b :: Int} = {a: 1, b: 1}
      t :: S.T = s

    test 'implement with MemberAccess', ->
      shouldBeTypeError """
      class A
      class A.B
        a :: Int

      struct S.T implements A.B
        b :: Int

      s :: {a :: Int} = {a: 1, b: 1}
      t :: S.T = s
      """

    test 'implement with MemberAccess', ->
      class A
      class A.B
        a :: Int

      struct S.T<U> implements A.B
        b :: U

      s :: {a :: Int, b :: String} = {a: 1, b: 's'}
      t :: S.T<String> = s

    test 'implement with MemberAccess', ->
      shouldBeTypeError """
      class A
      class A.B
        a :: Int

      struct S.T<U> implements A.B
        b :: U

      s :: {a :: Int, b :: String} = {a: 1, b: 's'}
      t :: S.T<Int> = s
      """

  suite "Module", ->

    test 'module', ->
      module X
        @a :: Int

    test 'typecheck in module', ->
      shouldBeTypeError """
      module A
        nop :: Int = 'string'
      """

    test 'nested module declare', ->
      module M.N
        @a :: Int
        @a = 1
      a :: Int = M.N.a

    test 'nested module declare', ->
      shouldBeTypeError """
      module X.Y
        @a :: Int
        @a = 1
      a :: String = X.Y.a
      """

    test 'nested module declare', ->
      module X.Y.Z
        @a :: Int
        @a = 1
      a :: Int = X.Y.Z.a

    test 'nested module declare', ->
      shouldBeTypeError """
      module X.Y.Z
        @a :: Int
        @a = 1
      a :: String = X.Y.Z.a
      """

    test 'nested module declare', ->
      module X.Y.Z
        struct A
          a :: Int
      a :: X.Y.Z.A = a: 1

    test 'nested module declare', ->
      shouldBeTypeError """
      module X.Y.Z
        struct A
          a :: Int
      a :: X.Y.Z.A = a: ''
      """

    test 'nested module declare', ->
      module X.Y.Z
        class @A
          a :: Int
      a :: X.Y.Z.A = a: 1

    test 'nested module declare', ->
      module X.Y.Z
        class @A
          a :: Int
      a :: {a :: Int} = new X.Y.Z.A

    test 'nested module declare', ->
      module X.Y.Z
        class @A
          a :: Int
      a :: X.Y.Z.A = new X.Y.Z.A
