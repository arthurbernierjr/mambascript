{
  checkAcceptableObject,
  ArrayType
} = require '../src/types'

suite 'Types', ->
  suite '.checkAcceptableObject', ->

    test 'string <> string', ->
      checkAcceptableObject 'Number', 'Number'

    test 'Any <> string', ->
      checkAcceptableObject 'Any', 'String'

    test 'String <> Possibities[String...]', ->
      checkAcceptableObject 'String', possibilities: ['String', 'String']

    test 'String <> Possibities[...]', ->
      throws -> checkAcceptableObject 'String', possibilities: ['Number', 'String']

    suite 'Object', ->
      test 'throw Object <> string', ->
        throws -> checkAcceptableObject {}, 'Number'

      test 'Fill all', ->
        checkAcceptableObject {x: 'Number'}, {x: 'Number'}

      test 'Fill all with unused right params', ->
        checkAcceptableObject {x: 'Number'}, {x: 'Number', y: 'Number'}

      test 'throw not filled right', ->
        throws -> checkAcceptableObject {x: 'Number', y: 'Number'}, {x: 'Number'}

    suite 'Array', ->
      test 'pure array', ->
        checkAcceptableObject "Array", (array: 'String')

      test 'throw non-array definition', ->
        throws -> checkAcceptableObject "Number", (array: 'String')

      test 'fill array', ->
        checkAcceptableObject (new ArrayType "Number"), (new ArrayType "Number")

      test 'fill array with raw object', ->
        checkAcceptableObject (array: {n: 'String'}), (array: {n:'String'})

      test 'throw not filled array', ->
        throws -> checkAcceptableObject (new ArrayType "Number"), (new ArrayType "String")

      test 'fill all array possibilities ', ->
        checkAcceptableObject (array: {n: 'String'}), (array:[{n:'String'}, {n: 'String'}])

      test 'fill array with complecated object', ->
        checkAcceptableObject (array: {
          x: 'Number'
          y: 'Number'
        }), (array:[
          {x: 'Number', y: 'Number'},
          {x: 'Number', y: 'Number', name: 'String'}
        ])

      test 'throw not filled array(with complecated object)', ->
        throws ->
          checkAcceptableObject (array: {
            x: 'Number'
            y: 'Number'
          }), (array:[
            {x: 'Number', y: 'Number'},
            {x: 'Number', name: 'String'}
          ])

    suite 'Generics', ->
      test 'fill array', ->
        checkAcceptableObject {}
