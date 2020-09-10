pj = try require 'prettyjson'
render = (obj) -> pj?.render obj
{TypeError} = require './type-helpers'
{debug} = require './helpers'
require('colors')

class Reporter
  constructor: ->
    @errors = []
    @warnings = []

  has_errors: ->
    @errors = @errors.filter ([node, text])->
      node.raw is not undefined
    @errors.length > 0

  has_warnings: ->
    @warnings = @warnings.filter ([node, text])->
      node.raw is not undefined
    @warnings.length > 0

  # () -> String
  report: ->
    errors = @errors.map ([node, text])->
      "L#{node.line} #{node.raw.inverse} #{text.red}"

    """
    #{errors.join '\n'}
    """

  add_error: (node, text) =>
    @errors.push [node, text]

  clean: =>
    @errors = []

  add_warning: (node, ws...) =>
    @warnings.push [node, ws.join '']

  # for debug
  dump: (node, prefix = '') ->
    console.error prefix + "[#{node.name}]"
    console.error prefix, ' vars::'
    for key, val of node._vars
      console.error prefix, ' +', key, '::', JSON.stringify(val)

    console.error prefix, ' types::'
    for type in node._types
      console.error prefix, ' +', type.identifier.typeName
      if type.properties
        for prop in type.properties
          console.error prefix, '    @', prop.identifier.typeName, prop.typeAnnotation

    for next in node.nodes
      @dump next, prefix + '  '

module.exports = new Reporter
