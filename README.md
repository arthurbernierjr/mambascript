# MambaScript in Development

## Getting Started

Install and run!

```
$ npm install -g mambacript
$ mamba -c foo.mamba # compile
$ mamba foo.mamba # execute
$ mamba # repl
$ start-mambascript #start a new mambascript project
```

### Extensions you should know about MambaScript

- `.mamba` and `.tcoffee` are compiled by mambascript compiler.
- Compiler uses jashkenas/coffeescript in `require('./foo.coffee')` by default.
- if you want to compile `.coffee` with mambascript, add `--self` option.


# Why work on an old project.

This project is amazing, period. Everything here is exactly what I needed to be added to KOFUJS project in order for it to run the way I want it to run, without having to move over to the clunky TypeScript syntax that I would rather avoid.

## Fixes made

1. Fixed Bug Causing REPL Not to Function
1. Updated CoffeeScript to stable version 2.5+ with JSX support
1. Added .mamba file type

## Updates Coming

1. Documentation on Usage with KOFUJS
1. Updates to Create MambaJS App
1. Make This Mambascript fork the default syntax for KOFUJS

## Current Tasks

1. Discover Additional Bugs
1. Make Production Ready

<hr/>

```iced
	# Concatenate string
	present '-------Concatenate string--------'
	present 'Concatenate -->',  'con' + 'cat' + 'en' + 'ate'

	# typeof operator
	present '-------TYPEOF operator--------'
	present 'Typeof Operator -->', typeof 'arthur'

	# isnt
	present '-------ISNT instead of !== --------'
	present 'ISNT -->' , 'Love' isnt 'Hate'

	# and , && , also
	present '------- also --------'
	present 'ALSO -->', 5 > 3 also 6 > 5

	# or, ||
	present '------- or --------'
	present 'OR -->', true or false

	# not
	present '-------NOT--------'
	present not true

	# is  and Booleans
	present '------- is  and Booleans --------'
	present 'Truthy Booleans true, on, yes'
	present 'Falsey Booleans false, off, no'
	present true is on
	present true is yes
	present false is off
	present false is no


	# Types

	obj =  {
		"MambaScript":	"JavaScript"
		"is": "==="
		"isnt":	"!=="
		"not":	"!"
		"also":	"&&"
		"or":	"||"
		"true yes on":	"true"
		"false no off":	"false"
		"@ this": 	"this"
		"of": "in"
		"in": "no JS Equivalent"
	}

	keys :: String[] = Object.keys obj

	forEvery key in keys then present "[#{key}] in MambaScript is equivalent to [#{obj[key]}] in JavaScript" unless key is 'MambaScript'

	# Strings

	myString :: String = 'arthur'

	present myString.split('').reverse().join('')
	present typeof myString

	# Numbers

	myNumber :: Number = 5

	present 'myNumber is', myNumber
	present myNumber * 2
	present myNumber ** 2
	present myNumber % 3
	present myNumber / 2


	# Booleans
	myBoolean :: Boolean = yes
	present 'myBoolean is', myBoolean

	# Objects
	myObj =
		name: 'arthur'
		age: 32
		lights: on
		hair: true

	present myObj
	# Arrays
	numArr :: Int[] = [1,2,3]
	stringArr :: String[] = ['a', 'b', 'c']
	otherArr :: Any[] = [1, 'a']
	present otherArr

	# Loops & Control Flow

	forEvery number in [0..12] by 2 then present number

	forEvery number in [0..10]
		do (number) ->
			present number * 3

	# eat is a function that accepts a string and returns nothing
	eat :: String -> () = (food :: String ) ->
		present "yum #{food.toUpperCase()} !!!"

	eat food forEvery food in ['toast', 'cheese', 'wine']

	eat food forEvery food in  ['toast', 'cheese', 'wine'] when food isnt 'cheese'
	# Blueprints

	blueprint Human
		name :: String
		age :: Int
		constructor: (age :: Int, name :: String) ->
			@name = name
			@age = age

	blueprint SuperHero inheritsFrom Human
		name :: String
		age :: Int
		powers :: String[]

		constructor: (name :: String, age :: Int, powers...) ->
			super name, age
			@powers = powers

	bigArt = new SuperHero 'Big Art', 33, 'flight', 'super strength'

	present bigArt

	# Functions

	# Structs

	# Generics

```

(Built MambaScript On Top Of) TypedCoffeeScript
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

## Project Status

Current biggest issues is implementation of typescript d.ts importer.

TypeScript AST parser is ready. [mizchi/dts-parser](https://github.com/mizchi/dts-parser "mizchi/dts-parser")

### Current Tasks(v0.12)

- module system
- robust namespace resolver
- splats argument such as `( args...: T[] ) -> `
- this scope in bound function

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

### Module

TypedCoffeeScript has module system like TypeScript

```coffee
module A.B
	class @C
		a :: Int
abc :: A.B.C = new A.B.C
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
