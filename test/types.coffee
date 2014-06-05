# {
#   checkAcceptableObject,
#   initializeGlobalTypes,
#   Scope,
#   ArrayType
# } = require '../src/types'

# reporter = require '../src/reporter'
# {ok} = require 'assert'
# ng = (v) -> !v

# root = new Scope
# initializeGlobalTypes root

# fail_typecheck = ->
#   ok reporter.has_errors() is true
#   reporter.errors = []

# suite 'Types', ->

#   suite '.checkAcceptableObject', ->

#     test 'string <> string', ->
#       ok false is checkAcceptableObject 'Number', 'Number', root

#     test 'Any <> string', ->
#       ok false is checkAcceptableObject 'Any', 'String', root

#     test 'String <> Possibities[String...]', ->
#       ok false is checkAcceptableObject 'String', possibilities: ['String', 'String'], root

#     test 'String <> Possibities[...]', ->
#       ok !!checkAcceptableObject 'String', possibilities: ['Number', 'String'], root

#     suite 'Object', ->
#       test 'throw Object <> string'
#         # checkAcceptableObject {}, 'Number'
#         # fail_typecheck()

#       test 'Fill all', ->
#         ok false is checkAcceptableObject {x: 'Number'}, {x: 'Number'}, root

#       test 'Fill all with unused right params', ->
#         ok false is checkAcceptableObject {x: 'Number'}, {x: 'Number', y: 'Number'}, root

#       test 'throw not filled right', ->
#         ok !!checkAcceptableObject {x: 'Number', y: 'Number'}, {x: 'Number'}, root

#     suite 'Array', ->
#       test 'pure array', ->
#         ok false is checkAcceptableObject "Array", (array: 'String'), root

#       test 'throw non-array definition', ->
#         ok !!checkAcceptableObject "Number", (array: 'String'), root

#       test 'fill array', ->
#         ok false is checkAcceptableObject (new ArrayType "Number"), (new ArrayType "Number"), root

#       test 'fill array with raw object', ->
#         ok false is checkAcceptableObject (array: {n: 'String'}), (array: {n:'String'}), root

#       test 'throw not filled array', ->
#         ok !!checkAcceptableObject (new ArrayType "Number"), (new ArrayType "String"), root

#       test 'fill all array possibilities ', ->
#         ok false is checkAcceptableObject (array: {n: 'String'}), (array:[{n:'String'}, {n: 'String'}]), root

#       test 'fill array with complecated object', ->
#         ok false is checkAcceptableObject (array: {
#           x: 'Number'
#           y: 'Number'
#         }), (array:[
#           {x: 'Number', y: 'Number'},
#           {x: 'Number', y: 'Number', name: 'String'}
#         ]), root

#       test 'throw not filled array(with complecated object)', ->
#         ok !!checkAcceptableObject (array: {
#           x: 'Number'
#           y: 'Number'
#         }), (array:[
#           {x: 'Number', y: 'Number'},
#           {x: 'Number', name: 'String'}
#         ]), root
