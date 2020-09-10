{formatParserError} = require './helpers'
Nodes = require './nodes'
{Preprocessor} = require './preprocessor'
Parser = require './parser'
TypeWalker = require './type-walker'
{Optimiser} = require './optimiser'
{Compiler} = require './compiler'
reporter = require './reporter'
{TypeError} = require './type-helpers'
cscodegen = try require 'cscodegen'
escodegen = try require 'escodegen'
NewCoffeScript = require 'coffeescript'
ESMRewriter = require '../utils/esm'

pkg = require './../package.json'

escodegenFormat =
  indent:
    style: '  '
    base: 0
  renumber: yes
  hexadecimal: yes
  quotes: 'auto'
  parentheses: no

KofuScript =

  KofuScript: KofuScript
  Compiler: Compiler
  Optimiser: Optimiser
  Parser: Parser
  Preprocessor: Preprocessor
  Nodes: Nodes
  NewCoffeScript: NewCoffeScript

  VERSION: pkg.version

  parse: (coffee, options = {}) ->
    try
      preprocessed = Preprocessor.process coffee, literate: options.literate
      parsed = Parser.parse preprocessed,
        raw: options.raw
        inputSource: options.inputSource
      # type check
      TypeWalker.checkNodes(parsed)
      if reporter.has_errors()
        throw new TypeError reporter.report()
      return (if options.optimise then Optimiser.optimise parsed else parsed)
    catch e
      throw e.message if e instanceof TypeError
      throw e unless e instanceof Parser.SyntaxError
      throw new Error formatParserError preprocessed, e

  compile: (csAst, options) ->
    (Compiler.compile csAst, options).toBasicObject()

  compileTypedToCS: (csAst, options) ->
    (cscodegen csAst)

  # TODO
  cs: (csAst, options) ->
    # TODO: opt: format (default: nice defaults)

  jsWithSourceMap: (jsAst, name = 'unknown', options = {}) ->
    # TODO: opt: minify (default: no)
    throw new Error 'escodegen not found: run `npm install escodegen`' unless escodegen?
    unless {}.hasOwnProperty.call jsAst, 'type'
      jsAst = jsAst.toBasicObject()
    targetName = options.sourceMapFile or (options.sourceMap and (options.output.match /^.*[\\\/]([^\\\/]+)$/)[1])
    escodegen.generate jsAst,
      comment: not options.compact
      sourceMapWithCode: yes
      sourceMap: name
      file: targetName or 'unknown'
      format: if options.compact then escodegen.FORMAT_MINIFY else options.format ? escodegenFormat

  jsEsm: (jsAst, options) ->
    code = (@jsWithSourceMap jsAst, null, options).code
    ESMRewriter code

  js: (jsAst, options) -> (@jsWithSourceMap jsAst, null, options).code

  sourceMap: (jsAst, name, options) -> (@jsWithSourceMap jsAst, name, options).map

  # Equivalent to original CS compile
  cs2js: (input, options = {}) ->
    options.optimise ?= on
    csAST = KofuScript.parse input, options
    jsAST = KofuScript.compile csAST, bare: options.bare
    KofuScript.js jsAST, compact: options.compact or options.minify

  smoothCompile: (input, options = {}) ->
    options.optimise ?= on
    csAST = KofuScript.parse input, options
    jsAST = KofuScript.compile csAST, bare: true
    KofuScript.jsEsm jsAST, compact: options.compact or options.minify

  svelteCompile: (input) ->
    options = {
      optimize: true
      bare: true
      header: true
      compact: true
    }
    @cs2js(input, options)

module.exports = KofuScript

if require.extensions?['.node']?
  KofuScript.register = -> require './register'
  # Throw error with deprecation warning when depending upon implicit `require.extensions` registration
  for ext in ['.coffee', '.litcoffee', '.tcoffee', '.typed.coffee', '.kofu']
    require.extensions[ext] ?= ->
      throw new Error """
      Use KofuScript.register() or require the coffee-script-redux/register module to require #{ext} files.
      """
