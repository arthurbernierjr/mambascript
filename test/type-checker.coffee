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

suite 'TypeChecker', ->
  setup ->
    global._root_.vars = []
    global._root_._this = []
    reporter.clean()

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
    test 'basic assign', ->
    test 'assign function', ->
      f :: Int -> Int = (n) -> n

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

  suite 'Nullable', ->
    # test 'cant catch undefined', ->
    #   shouldBeTypeError """
    #   x :: Number = global?.require
    #   """

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
      nf :: () -> void = -> setTimeout (->), 100
      nf()

  suite 'Array', ->
    # test 'typed array', ->
    #   struct Point
    #     x :: Number
    #     y :: Number
    #   p :: Point = x: 3, y: 2
    #   tarr :: Point[]  = [{x : 3, y: 3}, {x : 3, y: 3}, p]

  suite 'Range', ->
    # test 'Range', ->
    #   list :: Number[] = [1..10]
    # test 'throw function return type mismatch', ->
    #   shouldBeTypeError """
    #   list :: String[] = [1..10]
    #   """

  suite 'For', ->
    # test 'for in' , ->
    #   list :: Number[] =
    #     for i :: Number, n in [1..3]
    #       nn :: Number  = 3
    #       nn
    #   list2 :: Number[] =
    #     for i :: Number, n in [1..3]
    #       i
    #   list3 :: Number[] =
    #     for i :: Number, n in [1..3]
    #       n

    # test 'for of', ->
    #   list :: Number[] =
    #     for key :: String, val :: Number of {x: 77, y: 6}
    #       val

  suite 'if', ->
    # test 'if', ->
    #   f :: Number -> Number = (n) -> n

    #   tf :: () -> Boolean = -> true
    #   a :: Number =
    #     if tf()
    #       if true
    #         f 4
    #       else
    #         6
    #     else if true
    #       4
    #     else
    #       8

    # test 'throw if return type mismatch', ->
    #   shouldBeTypeError """
    #     a :: Number = if true then 3 else ""
    #   """

    # test.skip 'throw return type mismatch', ->
    #   shouldBeTypeError """
    #     arr :: Number[] = ("" for i in [1,2,3])
    #   """

    # test 'throw target mismatch', ->
    #   shouldBeTypeError """
    #     arr :: Number[] = (i for i :: Number in [1,2,""])
    #   """

    # test 'throw target mismatch', ->
    #   shouldBeTypeError """
    #     list :: Number[] =
    #       for key :: String, val :: Number of {x: "hoge", y: 6}
    #         val
    #   """

  suite 'Return', ->
    # test 'throw function return type mismatch', ->
    #   f2 :: () -> Int = ->
    #     return 3
    # test 'throw function return type mismatch', ->
    #   shouldBeTypeError """
    #   f2 :: () -> Number = ->
    #     return ""
    #   """

  suite 'Switch', ->
    # test 'Switch', ->
    #   x :: String =
    #     switch true
    #       when 0
    #         'foo'
    #       when 1
    #         'bar'
    #       else
    #         'fuga'
    # test 'miscast Switch', ->
    #   shouldBeTypeError """
    #   x :: Number =
    #     switch true
    #       when 0
    #         1
    #       else
    #         'str'
    #   """

  suite 'Class', ->
    test 'define class', ->
      class A
        name :: String

    test 'throw double assignment', ->
      shouldBeError """
      class A
        name :: String
        name :: Int
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

    suite 'Extends', ->
      # test 'extends properties', ->
      #   class Point
      #     x :: Int
      #     y :: Int

      #   class Entity extends Point
      #     width  :: Int
      #     height :: Int

      #   e :: {x :: Int, y :: Int} = new Entity

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

    test 'constructor', ->
      class A
        constructor :: Int -> ()
      a :: A = new A 3

    # test 'constructor', ->
    #   shouldBeTypeError """
    #   class A
    #     constructor :: Int -> ()
    #   a :: A = new A ''
    #   """

    # test 'new', ->
    #   shouldBeTypeError """
    #   struct S
    #     foo: String
    #   class A
    #     bar: String
    #   a :: S = new A
    #   """

    # test 'new', ->
    #   shouldBeTypeError """
    #   struct S {
    #     foo: String
    #   }
    #   class A
    #   a :: S = new A
    #   """

    # test 'new', ->
    #   class X
    #     f :: Number -> Number
    #     f: (n) -> n * n
    #   x :: X = new X
    #   n :: Number = x.f 3

    # test 'access proto this in class', ->
    #   class X
    #     constructor :: Number * String -> ()
    #     constructor: (num, fuga) ->
    #       @num = num
    #   x :: X = new X 3, ""

    # test 'throw access proto this in class', ->
    #   shouldBeTypeError """
    #   class X
    #     constructor :: Number -> ()
    #     constructor: (num, fuga) ->
    #       @num = num
    #   x :: X = new X ""
    #   """

    # test 'new', ->
    #   shouldBeTypeError """
    #   class X
    #     f: (n :: Number) :: Number ->
    #       n * n
    #   x :: X = new X
    #   n :: String = x.f 3
    #   """


  suite 'Generics', ->
    # test 'generics', ->
    #   struct Singleton<T> {
    #     getInstance :: () -> T
    #   }
    #   origin :: Singleton<Number> = {
    #     getInstance: -> 3
    #   }
    #   s :: Numbertgra = origin.getInstance()

    # test 'throw generics', ->
    #   shouldBeTypeError """
    #     struct Singleton<T> {
    #       getInstance :: () -> T
    #     }
    #     origin :: Singleton<Number> = getInstance: -> ""
    #     s :: String = origin.getInstance()
    #   """

    # test 'generics hash', ->
    #   struct Hash<K, V> {
    #     get :: K -> V
    #     set :: K * V -> ()
    #   }
    #   hash :: Hash<String, Number> = {
    #     get: (key) -> @[key]
    #     set: (key, val) -> @[key] = val
    #   }

    #   hash.set "a", 1
    #   num :: Number = hash.get "a"

    # test 'throw generics hash', ->
    #   shouldBeTypeError """
    #   struct Hash<K, V> {
    #     get :: K -> V
    #     set :: K * V -> ()
    #   }
    #   hash :: Hash<String, Number> = {
    #     get: (key) -> val
    #     set: (key, val) -> @[key] = val
    #   }
    #   hash.set "a", 1
    #   hash.get 3
    #   """

    # test 'throw generics hash', ->
    #   shouldBeTypeError """
    #   struct Hash<K, V> {
    #     get :: K -> V
    #     set :: K * V -> ()
    #   }
    #   hash :: Hash<String, Number> = {
    #     get: (key) -> val
    #     set: (key, val) -> @[key] = val
    #   }
    #   hash.set 5, 1
    #   """

  suite "implements", ->
    # test 'implements', ->
    #   struct Size
    #     width  :: Int
    #     height :: Int
    #   class Entity implements Size
    #   e :: {width :: Int, height :: Int} = new Entity

    # test 'multi class implements and extends', ->
    #   class Point
    #     x :: Int
    #     y :: Int

    #   struct Size {
    #     width  :: Int
    #     height :: Int
    #   }
    #   class Entity extends Object implements Point, Size
    #   e :: {x :: Int, width :: Int} = new Entity

    # test 'throw implements', ->
    #   shouldBeTypeError """
    #   struct Size {
    #     width  :: Int
    #     height :: Int
    #   }
    #   class Entity implements Size
    #   e :: {z :: Int} = new Entity
    #   """

    # test 'destructive assignment', ->
    #   a :: Int
    #   {a, b, c} = {a: 3, b:5, c:6}

    # test 'throw destructive assignment', ->
    #   shouldBeTypeError """
    #   a :: String
    #   {a, b, c} = {a: 3, b:5, c:6}
    #   """
    # test 'destructive assignment', ->
    #   [a, b, c] = [3, 5, 6]

    # test 'destructive assignment', ->
    #   shouldBeTypeError """
    #   a :: String
    #   [a, b, c] = [3, 5, 6]
    #   """

    # test 'receive this', ->
    #   class X
    #     x :: Int
    #     f: (@x) -> 3

    # test 'receive this with pre-defined function', ->
    #   class X
    #     x :: Int
    #     f :: Int -> Int
    #     f: (@x) -> 3

    # test 'throw destructive assignment', ->
    #   shouldBeTypeError """
    #   class X
    #     x :: String
    #     f :: Int -> Int
    #     f: (@x) -> {b:5, c:6}
    #   """

    # test 'receive this with destructive args', ->
    #   class X
    #     x :: Int
