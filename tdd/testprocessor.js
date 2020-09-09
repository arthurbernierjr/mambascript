const KofuScript = require('../lib/module')

module.exports = {
  process: (src) => {
    const csAst = KofuScript.parse(src, {bare: true});
    const jsAst = KofuScript.compile(csAst, {bare: true});
    const js = KofuScript.js(jsAst, {bare: true});
    return js
  }
}
