// Generated by KofuScript 0.1.0-beta4 
var present = console.log; 
// Generated by KofuScript 0.1.0-beta4 
var a, a, a, b, intByConditional, intBySwitch, listMaybeNull, listMaybeNull, listWithNull, nullableIntByConditional, nullableIntBySwitch;
0;
a = 1;
a = null;
b = 1;
a = b;
listWithNull = [
  1,
  2,
  3,
  null,
  5
];
listMaybeNull = null;
listMaybeNull = listWithNull;
intByConditional = Math.random() > .5 ? 1 : 2;
nullableIntByConditional = Math.random() > .5 ? 1 : void 0;
intBySwitch = function () {
  switch (~~(Math.random() * 10)) {
  case 1:
    return 1;
  case 2:
    return 2;
  default:
    return 3;
  }
}.call(this);
nullableIntBySwitch = function () {
  switch (~~(Math.random() * 10)) {
  case 1:
    return 1;
  case 2:
    return 2;
  }
}.call(this);
function isOwn$(o, p) {
  return {}.hasOwnProperty.call(o, p);
}
function extends$(child, parent) {
  for (var key in parent)
    if (isOwn$(parent, key))
      child[key] = parent[key];
  function ctor() {
    this.constructor = child;
  }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor;
  child.__super__ = parent.prototype;
  return child;
}