// Generated by KofuScript 0.1.0-beta4 
var present = console.log; 
// Generated by KofuScript 0.1.0-beta4 
var ira, obj, Person;
present((5 > 3 && 3 > 1) === true);
Person = function () {
  function Person() {
  }
  ;
  return Person;
}();
ira = new Person;
present(ira instanceof Person);
obj = {
  age: 33,
  weight: 250,
  height: 73
};
delete obj.age;
present(obj);
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