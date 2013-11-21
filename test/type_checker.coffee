reporter = require '../lib/reporter'
parse = (coffee) ->
  reporter.errors = []
  parse coffee

suite 'TypeChecker', ->
  suite 'Assignment', ->
    test 'basic assign', ->
      x :: Number = 3
      eq x, 3

    test 'int assign', ->
      x :: Int = 3

    test 'int assign', ->
      throws -> parse """
      x :: Int = 3.5
      """

    test 'primitive extended assign', ->
      x :: Int = 3
      y :: Number = x

    test 'primitive extended assign', ->
      x :: Int = 3
      y :: Float = x

    test 'throw primitive extended assign', ->
      throws -> parse """
      x :: Float = 3.3
      y :: Int = x
      """

    test 'basic assign', ->
      x :: Number = 3
      x = 5
      eq x, 5

    test 'assign function', ->
      f :: Number -> Number = (n) -> n
      g :: Number -> Number = f

    test 'throw type mismatch', ->
      throws ->
        parse """
          x :: Number = "3"
        """

    test 'object assign', ->
      obj :: { x :: Number} = { x : 2}

    test 'throw object literal mitmatching', ->
      throws ->
        parse """
          obj :: { x :: Number } = { x : '' }
        """

    test 'throw at lacking of object member', ->
      throws ->
        parse """
          obj :: { x :: Number, y :: Number } = { x : 3 }
        """

    test 'throw member access error', ->
      throws ->
        parse """
          obj :: { x :: Number } = { x : 3 }
          obj.x = ""
        """

    test 'object literal with newline', ->
      p :: {
        x :: Number
        y :: Number
      } = {x : 1, y: 5}

    test 'any type thorough everything', ->
      a :: Any = 3
      a = false
      eq a, false

    test 'typed function', ->
      f :: Number -> Number = (n :: Number) :: Number ->  n * n

    test 'typed function that has 2 arguments', ->
      f :: Number * Number -> Number = (n :: Number, m :: Number) :: Number ->  n * m

    test 'typed function that has 3 arguments', ->
      f :: Number * Number * Number -> Number = (n :: Number, m :: Number, r :: Number) :: Number ->  n * m * r

    test 'typed function type mismatch', ->
      throws ->
        CoffeeScript.compile """
          f :: Number -> Number = (n :: Number) :: String ->  n * n
        """

    test 'typed function and binding', ->
      f :: Number -> Number = (n :: Number) ->  n * n
      n :: Number  = f 4

    test 'typed function mismatching application', ->
      throws ->
        parse """
          f :: Number -> Number = 3
        """

    test 'typed function with return type', ->
      f :: Number -> Number = (n :: Number) :: Number ->  n * n
      n :: Number  = f 4

    test 'return function type', ->
      fh = (n :: Number) :: (Number -> Number) -> (m)-> n * m
      eq fh(2)(3), 6

    test 'avoid polution about prototype', ->
      class X
      X::x = 3
      eq X.prototype.x, 3

    test 'struct definition', ->
      struct Point {
        x :: Number
        y :: Number
      }
      p :: Point = {x: 3, y: 3}

    test 'struct definition with symbol', ->
      struct A {
        num :: Number
      }

      struct Point {
        x :: Number
        y :: {
          a :: A
          b :: String
        }
      }
      p :: Point = {x: 3, y: {a : {num: 4} , b : 'foo'}}

    test 'nested struct definition', ->
      struct Point {
        x :: Number
        y :: {
          a :: Number
          b :: String
        }
      }
      p :: Point = {x: 3, y: {a : 1 , b : 'foo'}}

    test 'throw struct member access with mismatch type', ->
      throws ->
        parse """
          struct Point {
            x :: Number
            y :: Number
          }
          p :: Point = {x:3, y:3}
          p.x = "hoge"
        """

    test 'void', ->
      nf :: () -> () = -> setTimeout (->), 100
      nf()

    test 'void keyword', ->
      nf :: () -> void = -> setTimeout (->), 100
      nf()

    test 'throw function arguments mismatch', ->
      throws ->
        parse """
          f :: Number -> Number = (n :: Number) :: Number ->  n * n
          (f "hello")
        """

    test 'void keyword', ->
      f :: Number -> Number = (n :: Number) :: Number ->  n * n
      x :: Number = (f 3)

    test 'throw function arguments mismatch', ->
      throws ->
        parse """
          f :: Number -> Number = (n :: Number) :: Number ->  n * n
          y :: String = (f 3)
        """

    test 'typed array', ->
      struct Point {
        x :: Number
        y :: Number
      }
      p :: Point = {x: 3, y: 2}
      tarr :: Point[]  = [{x : 3, y: 3}, {x : 3, y: 3}, p]


    test 'if', ->
      f :: Number -> Number = (n) -> n

      tf :: () -> Boolean = -> true
      a :: Number =
        if tf()
          if true
            f 4
          else
            6
        else if true
          4
        else
          8

    test 'throw if return type mismatch', ->
      throws ->
        parse """
          a :: Number = if true then 3 else ""
        """

    test 'for in' , ->
      list :: Number[] =
        for i :: Number, n in [1..3]
          nn :: Number  = 3
          nn

      list2 :: Number[] =
        for i :: Number, n in [1..3]
          i

      list3 :: Number[] =
        for i :: Number, n in [1..3]
          n

    test 'throw return type mismatch', ->
      throws ->
        parse """
          arr :: Number[] = ("" for i in [1,2,3])
        """

    test 'throw target mismatch', ->
      throws ->
        parse """
          arr :: Number[] = (i for i :: Number in [1,2,""])
        """

    test 'for of', ->
      list :: Number[] =
        for key :: String, val :: Number of {x: 77, y: 6}
          val

    test 'throw target mismatch', ->
      throws -> parse """
      list :: Number[] =
        for key :: String, val :: Number of {x: "hoge", y: 6}
          val
      """

    test 'function return type', ->
      f0 :: () -> Number = () :: Number -> 3

    test 'function return type mismatch with block', ->
      list :: Number[] =
      f1 :: () -> Number = () :: Number ->
        3

    test 'throw function return type mismatch', ->
      throws -> parse """
      f0 :: () -> Number = () :: Number -> ''
      """

    test 'throw function return type mismatch', ->
      throws -> parse """
      f2 :: () -> Number = ->
        return ""
      """

    test 'Range', ->
      list :: Number[] = [1..10]

    test 'throw function return type mismatch', ->
      throws -> parse """
      list :: String[] = [1..10]
      """

    test 'BinOps Num', ->
      a :: Number = (3 + 3 * 6) / 2

    test 'BinOps Int * Int -> Int', ->
      a :: Int = 3 + 5

    test 'BinOps Int * Float -> Float', ->
      a :: Float = 3 + 5.5

    test 'throw BinOps Int * Int -> Int', ->
      throws -> parse """
      a :: Int = 3 + 5.5
      """

    test 'BinOps String', ->
      a :: String = "hello" + "world"

    test 'miscast BinOp', ->
      throws -> parse """
      c :: Number = "" + 3
      """

    test 'Switch', ->
      x :: String =
        switch true
          when 0
            'foo'
          when 1
            'bar'
          else
            'fuga'
    test 'miscast Switch', ->
      throws -> parse """
      x :: Number =
        switch true
          when 0
            1
          else
            'str'
      """

    test 'cant catch undefined', ->
      throws -> parse """
      x :: Number = global?.require
      """

    test 'basic assign', ->
      x :: Number = 3
      eq x, 3

    test 'new', ->
      class X
        f: (n :: Number) :: Number -> 
          n * n
      x :: X = new X
      n :: Number = x.f 3

    test 'new', ->
      throws -> parse """
      class X
        f: (n :: Number) :: Number -> 
          n * n
      x :: X = new X
      n :: String = x.f 3
      """

    test 'generics', ->
      struct Singleton<T> {
        getInstance :: () -> T
      }
      origin :: Singleton<Number> = {
        getInstance: -> 3
      }
      s :: Numbertgra = origin.getInstance()

    test 'throw generics', ->
      throws -> parse """
        struct Singleton<T> {
          getInstance :: () -> T
        }
        origin :: Singleton<Number> = getInstance: -> ""
        s :: String = origin.getInstance()
      """

    test 'generics hash', ->
      struct Hash<K, V> {
        get :: K -> V
        set :: K * V -> ()
      }
      hash :: Hash<String, Number> = {
        get: (key) -> @[key]
        set: (key, val) -> @[key] = val
      }

      hash.set "a", 1
      num :: Number = hash.get "a"

    test 'throw generics hash', ->
      throws -> parse """
      struct Hash<K, V> {
        get :: K -> V
        set :: K * V -> ()
      }
      hash :: Hash<String, Number> = {
        get: (key) -> val
        set: (key, val) -> @[key] = val
      }
      hash.set "a", 1
      hash.get 3
      """

    test 'throw generics hash', ->
      throws -> parse """
      struct Hash<K, V> {
        get :: K -> V
        set :: K * V -> ()
      }
      hash :: Hash<String, Number> = {
        get: (key) -> val
        set: (key, val) -> @[key] = val
      }
      hash.set 5, 1
      """

    test 'throw when function args mismatch', ->
      throws -> parse """
      f :: Number * String -> String = (n, s) ->
        a :: Number = s
      """

    test 'pre-defined syntax', ->
      a :: Number
      a = 3

    test 'throw pre-defined', ->
      throws -> parse """
      a :: Number
      a = "str"
      """

    test 'pre-defined function', ->
      a :: Number -> Number
      a = (n) -> n

    test 'throw pre-defined args mismatch', ->
      throws -> parse """
      a :: Number -> Number
      a = (n) ->
        n2 :: String = n
      """

    test 'pre-defined args in class', ->
      class X
        text :: String
        f :: Number -> Number
        f: (n) ->
          @text = n.toString()

    test 'throw pre-defined args mismatch in class', ->
      throws -> parse """
      class X
        text :: String
        f :: Number -> Number
        f: (n) ->
          @text = n
      """

    test 'throw generics object', ->
      throws -> parse """
      struct Hash<K, V> {
        get :: K -> V
        set :: K * V -> ()
      }

      hash :: Hash<String, Number> =
        get: (key) -> @[key]
        set: (key, val) -> @[key] = val

      hash.set "", 1
      hash.get 1
      """

    test 'access this in class', ->
      class X
        foo :: Number
        constructor: ->
          @foo = 3

    test 'access this proto in class', ->
      class Y
        foo :: Number
        bar: ->
          @foo = 3

    test 'extends properties', ->
      class Point
        x :: Int
        y :: Int

      class Entity extends Point
        width  :: Int
        height :: Int

      e :: {x :: Int, y :: Int} = new Entity     

    test 'throw extends properties', ->
      throws -> parse """
      class Point
        x :: String
        y :: Int

      class Entity extends Point
        width  :: Int
        height :: Int

      e :: {x :: Int, y :: Int} = new Entity     
      """

    test 'throw access this in class', ->
      throws -> parse """
      class Z
        foo :: Number
        constructor: ->
          @foo = 'fuga'
      """

    test 'throw access proto this in class', ->
      throws -> parse """
      class K
        bar :: String
        f : (n) ->
          @bar = 2
      """

    test 'access proto this in class', ->
      class X
        num :: Number
        constructor :: Number -> ()
        constructor: (num) ->
          @num = num

    test 'throw access proto this in class', ->
      throws -> parse """
      class X
        num :: String
        constructor :: Number -> ()
        constructor: (num) ->
          @num = num
      """

    test 'access proto this in class', ->
      class X
        constructor :: Number * String -> ()
        constructor: (num, fuga) ->
          @num = num
      x :: X = new X 3, ""

    test 'throw access proto this in class', ->
      throws -> parse """
      class X
        constructor :: Number -> ()
        constructor: (num, fuga) ->
          @num = num
      x :: X = new X ""
      """

    test 'implements', ->
      struct Size {
        width  :: Int
        height :: Int
      }
      class Entity implements Size
      e :: {width :: Int, height :: Int} = new Entity

    test 'multi class implements and extends', ->
      class Point
        x :: Int
        y :: Int

      struct Size {
        width  :: Int
        height :: Int
      }
      class Entity extends Object implements Point, Size
      e :: {x :: Int, width :: Int} = new Entity

    test 'throw implements', ->
      throws -> parse """
      struct Size {
        width  :: Int
        height :: Int
      }
      class Entity implements Size
      e :: {z :: Int} = new Entity
      """

    test 'destructive assignment', ->
      a :: Int
      {a, b, c} = {a: 3, b:5, c:6}

    test 'throw destructive assignment', ->
      throws -> parse """
      a :: String
      {a, b, c} = {a: 3, b:5, c:6}
      """
    test 'destructive assignment', ->
      [a, b, c] = [3, 5, 6]

    test 'destructive assignment', ->
      throws -> parse """
      a :: String
      [a, b, c] = [3, 5, 6]
      """

    test 'receive this', ->
      class X
        x :: Int
        f: (@x) -> 3

    test 'receive this with pre-defined function', ->
      class X
        x :: Int
        f :: Int -> Int
        f: (@x) -> 3

    test 'throw destructive assignment', ->
      throws -> parse """
      class X
        x :: String
        f :: Int -> Int
        f: (@x) -> 3 b:5, c:6}
      """

    test 'receive this with destructive args', ->
      class X
        x :: Int
        f: ({@x}) -> 3
