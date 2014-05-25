TypedCoffeeScript
==================================

[![Build Status](https://drone.io/github.com/mizchi/TypedCoffeeScript/status.png)](https://drone.io/github.com/mizchi/TypedCoffeeScript/latest)
Superset of CoffeeScript with types

## Concepts

* Allow to compile all coffee-script
* Optional type and restrict member access under definition
* Easy to add type to symbol from the middle of development
* Easy to replace coffee-script
* Check type againt cscodegen AST, not in compiler

## Problems

This repository is heavily under development and dirty codes.

- Take over all coffee-script-redux problems 
	- imperfect super
	- object literal parsing

## Getting started

Install
```
$ npm install -g typed-coffee-script
$ tcoffee -c foo.coffee
```

## Examples

### Assigment with type
```coffee
n :: Int = 3
```

### Pre-defined symbol
```coffee
x :: Number
x = 3.14
```

### Struct

```coffee
struct Point {
  x :: Number
  y :: Number
}
p :: Point = {x: 3, y: 3}
```

### Typed Array

```coffee
line :: Point[] = [{x: 3, y: 4}, {x: 8, y: 5}, p]
```

### Typed Function

```
f :: Int -> Int
f = (n) -> n

# left side type definition
fl :: Number -> Point = (n) ->  {x: n, y: n * 2}
# right side
fr = (n :: Number) :: Number ->  n * n
```

### Generics

```coffee
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
```

### Class with this scope

```coffee
class X
  # bound to this
  num :: Number
  f :: Number -> Number
  f: (n) ->
    @num = n

x :: X = new X
x.f 3
```

### Class with implemtns

```coffee
class Point
  x :: Int
  y :: Int

struct Size {
  width  :: Int
  height :: Int
}

class Entity extends Object implements Point, Size
e :: {x :: Int, width :: Int} = new Entity
```

Forked from CoffeeScript II: The Wrath of Khan
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
