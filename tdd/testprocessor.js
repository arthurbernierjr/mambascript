const MambaScript = require('../lib/module')

module.exports = {
  process: (src) => {
    const csAst = MambaScript.parse(src, {bare: true});
    const jsAst = MambaScript.compile(csAst, {bare: true});
    const js = MambaScript.js(jsAst, {bare: true});
    return js
  }
}
