TypedCoffeeScript
==================================

[![Build Status](https://drone.io/github.com/mizchi/TypedCoffeeScript/status.png)](https://drone.io/github.com/mizchi/TypedCoffeeScript/latest)

CoffeeScript with Types.

This repository is heavily under development and unstable. See below milestone.

## Concepts

* Structual Subtyping
* Superset of CoffeeScript
* Easy to replace coffee (pass unannotated coffee)
* Pessimistic type interfaces

## What is pessimistic type interface?

To pass dynamic type system, TypedCoffeeScript expects symbol to `implicit` node by default. If compiler compares implicit node type and implicit node type and fails, it recover to `implicit` `Any` automatically.

If you add annotation to symbol, compiler can report errors. (This concept is imperfect at `v0.10`)

## Getting Started

Install

```
$ npm install -g typed-coffee-script
$ tcoffee -c foo.coffee # compile
$ tcoffee foo.coffee # execute
```

## Project Status

### `~v0.9`

- Implement basic concepts

### `v0.10`(current version)

- Rewrite internal AST and type interfaces
- Add new command line interface
- Refactor
- Nullable

Now I rewrited internal for adding typescript importer.

TypeScript AST parser is ready. [mizchi/dts-parser](https://github.com/mizchi/dts-parser "mizchi/dts-parser")

- `v0.10.1`
	- MemberAccess in struct definition
	- Infer fuction return type with `return` in Block
	- Destructive Assignment

## Milestone

### `v0.11`

Reimplementation of `~v0.9`

- Generics
- TypeArgument
- Super in class
- Class static member type interface
- Readable warnings

### `v0.12`

- module system
- typealias
  - such as `typealias Bar = Foo<T>[]`
- TypeScript `*.d.ts` importer

### `v0.13`

- Stable(RC for 1.0)
- Add more tests.
- Coverage of types to symbol
- (Fix CoffeeScriptRedux bugs if I can)

## How to contribute

You can use this compiler without type annotation. All test by `CoffeeScriptRedux` passed.

If you encounter bugs, such as type interface... parser..., please report as github issues or pull request to me. I also welcome new syntax proposal.

I DON'T reccomend to use in production yet.

## Known issues

- Take over all coffee-script-redux problems
	- imperfect super
	- object literal parsing in class field
  - and so on

## Examples

### Assigment with type

```coffee
n :: Int = 3
```

### Pre defined symbol

```coffee
x :: Number
x = 3.14
```

### Nullable

```coffee
x :: Number?
x = 3.14
x = null
```

### Typed Array

```coffee
list :: Int[] = [1..10]
listWithNull :: Int?[] = [1, null, 3]
```

In `v0.10`, imperfect to struct.

### Struct

```coffee
struct Point
  x :: Number
  y :: Number
p :: Point = {x: 3, y: 3}
```

### Typed Array

```coffee
line :: Point[] = [{x: 3, y: 4}, {x: 8, y: 5}, p]
```

### Typed Function

```coffee
# pre define
f1 :: Int -> Int
f1 = (n) -> n

# annotation
f2 :: Number -> Point = (n) -> x: n, y: n * 2

# multi arguments
f3 :: (Int, Int) -> Int = (m, n) -> m * n

# another form of arguments
f4 :: Int * Int -> Int = (m, n) -> m * n

# partial applying
fc :: Int -> Int -> Int
fc = (m) -> (n) -> m * n
```

### Class with this scope

```coffee
class X
  # bound to this
  num :: Number
  f   :: Number -> Number

  f: (n) ->
    @num = n

x :: X = new X
n :: Number = x.f 3
```

### Class with implements

```coffee
class Point
  x :: Int
  y :: Int

struct Size
  width  :: Int
  height :: Int

class Entity extends Point implements Size
e :: {x :: Int, width :: Int} = new Entity
```

### Generics and type arguments

Caution: `v0.10` fail it yet.

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
