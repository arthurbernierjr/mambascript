{
  checkAcceptableObject,
  ArrayType
} = require '../src/types'
reporter = require '../src/reporter'
{ok} = require 'assert'
ng = (v) -> !v

fail_typecheck = ->
  ok reporter.has_errors() is true
  reporter.errors = []

suite 'Types', ->
  suite '.checkAcceptableObject', ->

    test 'string <> string', ->
      ok false is checkAcceptableObject 'Number', 'Number'

    test 'Any <> string', ->
      ok false is checkAcceptableObject 'Any', 'String'

    test 'String <> Possibities[String...]', ->
      ok false is checkAcceptableObject 'String', possibilities: ['String', 'String']

    test 'String <> Possibities[...]', ->
      ok !!checkAcceptableObject 'String', possibilities: ['Number', 'String']

    suite 'Object', ->
      test 'throw Object <> string'
        # checkAcceptableObject {}, 'Number'
        # fail_typecheck()

      test 'Fill all', ->
        ok false is checkAcceptableObject {x: 'Number'}, {x: 'Number'}

      test 'Fill all with unused right params', ->
        ok false is checkAcceptableObject {x: 'Number'}, {x: 'Number', y: 'Number'}

      test 'throw not filled right', ->
        ok !!checkAcceptableObject {x: 'Number', y: 'Number'}, {x: 'Number'}

    suite 'Array', ->
      test 'pure array', ->
        ok false is checkAcceptableObject "Array", (array: 'String')

      test 'throw non-array definition', ->
        ok !!checkAcceptableObject "Number", (array: 'String')

      test 'fill array', ->
        ok false is checkAcceptableObject (new ArrayType "Number"), (new ArrayType "Number")

      test 'fill array with raw object', ->
        ok false is checkAcceptableObject (array: {n: 'String'}), (array: {n:'String'})

      test 'throw not filled array', ->
        ok !!checkAcceptableObject (new ArrayType "Number"), (new ArrayType "String")

      test 'fill all array possibilities ', ->
        ok false is checkAcceptableObject (array: {n: 'String'}), (array:[{n:'String'}, {n: 'String'}])

      test 'fill array with complecated object', ->
        ok false is checkAcceptableObject (array: {
          x: 'Number'
          y: 'Number'
        }), (array:[
          {x: 'Number', y: 'Number'},
          {x: 'Number', y: 'Number', name: 'String'}
        ])

      test 'throw not filled array(with complecated object)', ->
        ok !!checkAcceptableObject (array: {
          x: 'Number'
          y: 'Number'
        }), (array:[
          {x: 'Number', y: 'Number'},
          {x: 'Number', name: 'String'}
        ])
