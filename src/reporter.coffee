pj = try require 'prettyjson'
render = (obj) -> pj?.render obj
{TypeError} = require './type-helpers'

class Reporter
  constructor: ->
    @errors = []
    @warnings = []

  has_errors: -> @errors.length > 0

  has_warnings: -> @warnings.length > 0

  # () -> String
  report: ->
    errors = @errors.map ([node, text])->
      """
      #{text}
        at | #{node.raw}
      """

    """
    [Error]
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
    console.log prefix + "[#{node.name}]"
    for key, val of node._vars
      console.log prefix, ' +', key, '::', JSON.stringify(val)
    for next in node.nodes
      @dump next, prefix + '  '

module.exports = new Reporter