suite 'Type', ->
  suite 'Assignment', ->
    test 'basic assign', ->
      x :: Number = 3
      eq x, 3

    test 'throw type mismatch', ->
      throws ->
        CoffeeScript.parse """
          x :: Number = "3"
        """

    test 'any type thorough everything', ->
      a :: Any = 3
      a = false
      eq a, false

    test 'avoid polution about prototype', ->
      class X
      X::x = 3
      eq X.prototype.x, 3

