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

## Getting Started

Install and run!

```
$ npm install -g typed-coffee-script
$ tcoffee -c foo.typed.coffee # compile
$ tcoffee foo.typed.coffee # execute
$ tcoffee # repl
```

### Extensions you should know about TypedCoffeeScript

- `.tcoffee` and `.typed.coffee` are compiled by TypedCoffeeScript compiler.
- Compiler uses jashkenas/coffeescript in `require('./foo.coffee')` by default.
- if you want to compile `.coffee` with TypedCoffeeScript, add `--self` option.

## Project Status

Current biggest issues is implementation of typescript d.ts importer.

TypeScript AST parser is ready. [mizchi/dts-parser](https://github.com/mizchi/dts-parser "mizchi/dts-parser")

### Current Tasks(v0.12)

- module system
- robust namespace resolver
- splats argument such as `( args...: T[] ) -> `

#### Wip

- TypeScript `*.d.ts` importer
- typealias such as `typealias Bar = Foo<T>[]`

## Milestone

### `v0.13`

- Be stable(RC for 1.0)
- Add more tests.
- Coverage of types to symbol
- Infer super arguments in class
- (Fix CoffeeScriptRedux bugs if I can)

## Known bugs

- Compiler can't resolve module namespace when namespace has more than three dots, such as `A.B.C.d`
- Take over all coffee-script-redux problems
	- super with member access `super().member`
	- object literal parsing in class field

## How to contribute

You can use this compiler without type annotation. All test by `CoffeeScriptRedux` passed.

If you encounter bugs, such as type interface... parser..., please report as github issues or pull request to me. I also welcome new syntax proposal.

I DON'T reccomend to use in production yet.

## CHANGE LOG

### `v0.11`

- Generics
- TypeArgument
- Fix examples
- Recognise extensions in require
- Runnable by `tcoffee foo.typed.coffee` that has `require`
- Class static member type interface
- Struct with implements

### `v0.10`

- Rewrite internal AST and type interfaces
- Add new command line interface
- Refactor
- Nullable
- MemberAccess in struct definition
- Infer fuction return type with `return` in Block
- Destructive Assignment
- self hosting

### `~v0.9`

- Implement basic concepts

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
  @name :: String
  x :: Number
  y :: Number
p :: Point = {x: 3, y: 3}
name :: String = Point.name

struct Point3d implements Point
  z :: Number
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

```coffee
# struct
struct Value<T, U>
	value :: U
struct Id<A, B>
	id :: Value<A, B>
obj :: Id<Int, String> =
  id:
    value: 'value'

# function type arguments
map<T, U> :: T[] * (T -> U) -> U[]
map = (list, fn) ->
  for i in list
    fn(i)
list :: String[] = map<Int, String> [1..10], (n) -> 'i'

# class type arguments
class Class<A>
  f :: Int -> Int
  constructor :: A -> ()
  constructor: (a) ->
c = new Class<Int>(1)
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
