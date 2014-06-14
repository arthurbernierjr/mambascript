root = window ? global ? this
root._module_ = (ns, f, context = root) =>
  context ?= root
  hist = []
  for name in ns.split('.')
    unless context[name]?
      context[name] = {}
    context = context[name]
    hist.push context
  f.apply context, hist

suite 'Module', ->
  test 'simple arrays', ->
    module X
      @x = 3
    eq X.x, 3

  test 'simple arrays', ->
    module X.Y
      @x = 3
    eq X.Y.x, 3

  test 'simple arrays', ->
    module X.Y
      Y.x = 3
    eq X.Y.x, 3
