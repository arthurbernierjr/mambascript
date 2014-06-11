child_process = require 'child_process'
fs = require 'fs'
path = require 'path'

CoffeeScript = require './module'
{runModule} = require './run'

module.exports = not require.extensions['.coffee']?

{argv} = require('optimist')
  .boolean('self')

compile = (module, filename, opts) ->
  input = fs.readFileSync filename, 'utf8'
  csAst = CoffeeScript.parse input, opts
  jsAst = CoffeeScript.compile csAst
  js = CoffeeScript.js jsAst
  runModule module, js, jsAst, filename

compileWithOriginalCoffee = (module, filename, opts = {}) ->
  OriginalCoffee = require 'coffee-script'

  input = fs.readFileSync filename, 'utf8'
  js = OriginalCoffee.compile input, opts
  runModule module, js, null, filename

require.extensions['.typed.coffee'] = (module, filename) ->
  compile module, filename, raw: yes, typeCheck: true

require.extensions['.coffee'] = (module, filename) ->
  if argv.self
    compile module, filename, raw: yes
  else
    compileWithOriginalCoffee module, filename, raw: yes, bare: argv.bare

require.extensions['.litcoffee'] = (module, filename) ->
  compile module, filename, raw: yes, literate: yes

require.extensions['.tcoffee'] = (module, filename) ->
  compile module, filename, raw: yes, typeCheck: true

# patch child_process.fork to default to the coffee binary as the execPath for coffee/litcoffee files
{fork} = child_process
unless fork.coffeePatched
  coffeeBinary = path.resolve 'bin', 'tcoffee'
  child_process.fork = (file, args = [], options = {}) ->
    if (path.extname file) in ['.coffee', '.litcoffee', '.tcoffee', '.typed.coffee']
      if not Array.isArray args
        args = []
        options = args or {}
      options.execPath or= coffeeBinary
    fork file, args, options
  child_process.fork.coffeePatched = yes

delete require.cache[__filename]
