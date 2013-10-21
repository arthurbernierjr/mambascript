# TODO

やらなきゃならんことのメモ

## 謎のsetVar不在

```
/Users/mizchi/proj/CoffeeScriptRedux/lib/module.js:62
        throw e;
              ^
TypeError: Object output has no method 'setVar'
  at /Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:226:28
  at Array.map (native)
  at walk (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:224:21)
  at /Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:169:14
  at Array.forEach (native)
  at walk (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:168:17)
  at walk (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:230:12)
  at /Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:169:14
  at Array.forEach (native)
  at walk (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:168:17)
  at walk (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:228:12)
  at /Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:169:14
  at Array.forEach (native)
  at walk (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:168:17)
  at walk (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:230:12)
  at /Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:169:14
  at Array.forEach (native)
  at walk (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:168:17)
  at Object.checkNodes (/Users/mizchi/proj/CoffeeScriptRedux/lib/type.js:160:10)
  at Object.CoffeeScript.parse (/Users/mizchi/proj/CoffeeScriptRedux/lib/module.js:53:12)
  at Object.require.extensions..coffee (/Users/mizchi/proj/CoffeeScriptRedux/lib/register.js:15:26)
  at Module.load (module.js:356:32)
  at Function.Module._load (module.js:312:12)
  at Module.require (module.js:364:17)
  at require (module.js:380:17)
  at /Users/mizchi/proj/CoffeeScriptRedux/node_modules/mocha/lib/mocha.js:152:27
  at Array.forEach (native)
  at Mocha.loadFiles (/Users/mizchi/proj/CoffeeScriptRedux/node_modules/mocha/lib/mocha.js:149:14)
  at Mocha.run (/Users/mizchi/proj/CoffeeScriptRedux/node_modules/mocha/lib/mocha.js:306:31)
  at Object.<anonymous> (/Users/mizchi/proj/CoffeeScriptRedux/node_modules/mocha/bin/_mocha:343:7)
  at Module._compile (module.js:456:26)
  at Object.Module._extensions..js (module.js:474:10)
  at Module.load (module.js:356:32)
  at Function.Module._load (module.js:312:12)
  at Function.Module.runMain (module.js:497:10)
  at startup (node.js:119:16)
  at node.js:901:3
```

* for の反復子をスコープへ追加

for i :: Number in [1..10]
  console.log i


* Implicit型と明示的なAnyの整理

とりあえず処理系側で全部推論してみる
勝手に推論にして成功する限りはその型としておく。
明示的な型キャストが入った瞬間に壊れた場合、暗黙の型推論は捨てて明示的な型指定を優先する

* argumentsの中の lambda のスコープ

* Bound Function のスコープ

(hoge) =>
  this.x = hoge

* typed funciton の引数マッチ

setTimeout (-> console.log 10), 10

* BinaryOperatorの推論

4 + 3

JSの仕様上Number(Int, Float) or String でok

* Int, Floatの追加

* class 宣言の中のスコープ定義

class X
  x :: Number

* type 宣言

type Point
  x :: Number
  y :: Number

* Object Literalの推論

obj :: { x :: Number } = { x : '' }
