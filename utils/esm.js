const r1     = /^([a-zA-Z_$][a-zA-Z0-9_$]*) +\= +(require)\((('|")[a-zA-Z0-9-_.\/@~]+('|"))\)/gm // const createStore = require('redux')
const r2     = /^([a-zA-Z_$][a-zA-Z0-9_$]*) +\= +(require)\((('|")[a-zA-Z0-9-_.\/@~]+('|"))\)\.([a-zA-Z][a-zA-Z0-9]*)/gm // const createStore = require('redux').createStore
const r3     = /^(\{\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\}) +\= +(require)\((('|")[a-zA-Z0-9-_.\/@~]+('|"))\)/gm // const { createStore } = require('redux')
const r4 = /^(module.exports) +\= (([a-zA-Z_$][a-zA-Z0-9_$]*))/gm
const r5 = /^(eval)\(('|")(export)\s+(["'=a-zA-Z0-9-_.\s\/@~]+)('|")\)/gm

module.exports = function(code){
  return (
    code
      .replace(r2, `import { $6 as _$1 } from $3; \n var $1 = _$1`)
      .replace(r3, `import { _$2 } from $4; \n $2 = _$2`)
      .replace(r4, `export default $3`)
      .replace(r1, `import _$1 from $3; \n var $1 = _$1`)
      .replace(r5, `export $4`)
    )
}
