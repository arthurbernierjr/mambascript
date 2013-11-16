{
  checkAcceptableObject,
  ArrayType
} = require '../src/types'
reporter = require '../src/reporter'
{ok} = require 'assert'

fail_typecheck = ->
  ok reporter.has_errors() is true
  reporter.errors = []

suite 'Types', ->
  suite '.checkAcceptableObject', ->

    test 'string <> string', ->
      checkAcceptableObject 'Number', 'Number'

    test 'Any <> string', ->
      checkAcceptableObject 'Any', 'String'

    test 'String <> Possibities[String...]', ->
      checkAcceptableObject 'String', possibilities: ['String', 'String']

    test 'String <> Possibities[...]', ->
      checkAcceptableObject 'String', possibilities: ['Number', 'String']
      fail_typecheck()

    suite 'Object', ->
      test 'throw Object <> string'
        # checkAcceptableObject {}, 'Number'
        # fail_typecheck()

      test 'Fill all', ->
        checkAcceptableObject {x: 'Number'}, {x: 'Number'}

      test 'Fill all with unused right params', ->
        checkAcceptableObject {x: 'Number'}, {x: 'Number', y: 'Number'}

      test 'throw not filled right', ->
        checkAcceptableObject {x: 'Number', y: 'Number'}, {x: 'Number'}
        fail_typecheck()

    suite 'Array', ->
      test 'pure array', ->
        checkAcceptableObject "Array", (array: 'String')

      test 'throw non-array definition', ->
        checkAcceptableObject "Number", (array: 'String')
        fail_typecheck()

      test 'fill array', ->
        checkAcceptableObject (new ArrayType "Number"), (new ArrayType "Number")

      test 'fill array with raw object', ->
        checkAcceptableObject (array: {n: 'String'}), (array: {n:'String'})

      test 'throw not filled array', ->
        checkAcceptableObject (new ArrayType "Number"), (new ArrayType "String")
        fail_typecheck()

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
        checkAcceptableObject (array: {
          x: 'Number'
          y: 'Number'
        }), (array:[
          {x: 'Number', y: 'Number'},
          {x: 'Number', name: 'String'}
        ])
        fail_typecheck()
