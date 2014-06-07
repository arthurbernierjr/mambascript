{
  initializeGlobalTypes,
  Scope
} = require '../lib/types'

{isAcceptable} = require '../lib/type-checker'

suite 'TypeChecker', ->
  acceptable = (l, r) -> isAcceptable @scope, l, r

  setup ->
    @scope = new Scope
    initializeGlobalTypes(@scope)

  suite 'isAcceptable', ->
    test 'float accept int', ->
      left =
        nodeType: 'identifier'
        identifier:
          typeRef: 'Float'

      right =
        nodeType: 'identifier'
        identifier:
          typeRef: 'Int'
      ok isAcceptable @scope, left, right
