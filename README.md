TypedCoffeeScript
==================================

Superset of CoffeeScript with types

## Concept

* Allow to compile all coffee-script
* Optional type and restrict member access under definition
* Easy to add type to symbol from the middle of development
* Easy to replace coffee-script
* Check type againt cscodegen AST, not in compiler

## Examples

```coffeescript
# define struct
struct Point {
  x :: Number
  y :: Number
}

# structure
p :: Point = {x: 3, y: 3}
line :: Point[] = [{x: 3, y: 4}, {x: 8, y: 5}, p]

# typed function
f1 :: Number -> Number = (n) ->  n * n
f2 = (n :: Number) ->  n * n

# pre-defined symbol
f3 :: Number -> Number
f3 = (n) ->  n * n

# generics
struct Hash<K, V> {
  get :: K -> V
  set :: K * V -> ()
}
hash :: Hash<String, Number> = {
  get: (key) -> @[key]
  set: (key, val) -> @[key] = val
}
hash.set "a", 1
num :: Number = hash.get "a"

# class property field
class X
  num :: Number
  f :: Number -> Number
  f: (n) ->
    @num = n
x :: X = new X
x.f 3
```

When TypeError occur, AST type checker notifies you why.
See test/type_checker.coffee in detail.

## Install

```
$ npm install typed-coffee-script
```

Now, this project aliased to `tcoffee`

```
$ tcoffee --js  < scratch.coffee > scratch.js
```

## Milestone to v1.0.0

* ✅ Struct definition
* ✅ Typed function definition
* ✅ Function call with typecheck
* ✅ Typed Array
* ✅ Member access
* ✅ If statement
* ✅ ForIn statement
* ✅ ForOf statement
* ✅ Range
* ✅ Function
* ✅ BinaryOperator
* ✅ Generics
* ✅ Scope about this and class
* Generate pure coffee
* Share type context with some scripts


CoffeeScript II: The Wrath of Khan
==================================

```
          {
       }   }   {
      {   {  }  }
       }   }{  {
      {  }{  }  }             _____       __  __
     ( }{ }{  { )            / ____|     / _|/ _|
   .- { { }  { }} -.        | |     ___ | |_| |_ ___  ___
  (  ( } { } { } }  )       | |    / _ \|  _|  _/ _ \/ _ \
  |`-..________ ..-'|       | |___| (_) | | | ||  __/  __/
  |                 |        \_____\___/|_| |_| \___|\___|       .-''-.
  |                 ;--.                                       .' .-.  )
  |                (__  \     _____           _       _       / .'  / /
  |                 | )  )   / ____|         (_)     | |     (_/   / /
  |                 |/  /   | (___   ___ _ __ _ _ __ | |_         / /
  |                 (  /     \___ \ / __| '__| | '_ \| __|       / /
  |                 |/       ____) | (__| |  | | |_) | |_       . '
  |                 |       |_____/ \___|_|  |_| .__/ \__|     / /    _.-')
   `-.._________..-'                           | |           .' '  _.'.-''
                                               |_|          /  /.-'_.'
                                                           /    _.'
                                                          ( _.-'
```

### Status

Complete enough to use for nearly every project. See the [roadmap to 2.0](https://github.com/michaelficarra/CoffeeScriptRedux/wiki/Roadmap).

### Getting Started

    npm install -g coffee-script-redux
    coffee --help
    coffee --js <input.coffee >output.js

Before transitioning from Jeremy's compiler, see the
[intentional deviations from jashkenas/coffee-script](https://github.com/michaelficarra/CoffeeScriptRedux/wiki/Intentional-Deviations-From-jashkenas-coffee-script)
wiki page.

### Development

    git clone git://github.com/michaelficarra/CoffeeScriptRedux.git && cd CoffeeScriptRedux && npm install
    make clean && git checkout -- lib && make -j build && make test

### Notable Contributors

I'd like to thank the following financial contributors for their large
donations to [the Kickstarter project](http://www.kickstarter.com/projects/michaelficarra/make-a-better-coffeescript-compiler)
that funded the initial work on this compiler.
Together, you donated over $10,000. Without you, I wouldn't have been able to do this.

* [Groupon](http://groupon.com/), who is generously allowing me to work in their offices
* [Trevor Burnham](http://trevorburnham.com)
* [Shopify](http://www.shopify.com)
* [Abakas](http://abakas.com)
* [37signals](http://37signals.com)
* [Brightcove](http://www.brightcove.com)
* [Gaslight](http://gaslight.co)
* [Pantheon](https://www.getpantheon.com)
* Benbria
* Sam Stephenson
* Bevan Hunt
* Meryn Stol
* Rob Tsuk
* Dion Almaer
* Andrew Davey
* Thomas Burleson
* Michael Kedzierski
* Jeremy Kemper
* Kyle Cordes
* Jason R. Lauman
* Martin Drenovac (Envizion Systems - Aust)
* Julian Bilcke
* Michael Edmondson

And of course, thank you [Jeremy](https://github.com/jashkenas) (and all the other
[contributors](https://github.com/jashkenas/coffee-script/graphs/contributors))
for making [the original CoffeeScript compiler](https://github.com/jashkenas/coffee-script).
