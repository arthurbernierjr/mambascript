やらなきゃならんことのメモ

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
