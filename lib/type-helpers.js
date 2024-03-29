// Generated by MambaScript 0.5.2 
var present = console.log; 
// Generated by MambaScript 0.5.2 
var ArrayInterface, clone, NumberInterface, ObjectInterface, rewrite;
this.clone = clone = function (obj) {
  var flags, key, newInstance;
  if (!(null != obj) || typeof obj !== 'object')
    return obj;
  if (obj instanceof Date)
    return new Date(obj.getTime());
  if (obj instanceof RegExp) {
    flags = '';
    if (null != obj.global)
      flags += 'g';
    if (null != obj.ignoreCase)
      flags += 'i';
    if (null != obj.multiline)
      flags += 'm';
    if (null != obj.sticky)
      flags += 'y';
    return new RegExp(obj.source, flags);
  }
  newInstance = new obj.constructor;
  for (key in obj) {
    newInstance[key] = clone(obj[key]);
  }
  return newInstance;
};
this.rewrite = rewrite = function (obj, replacer) {
  var key, val;
  if (typeof obj === 'string' || typeof obj === 'number')
    return;
  return function (accum$) {
    for (key in obj) {
      val = obj[key];
      accum$.push(typeof val === 'string' ? null != replacer[val] ? obj[key] = replacer[val] : void 0 : val instanceof Object ? rewrite(val, replacer) : void 0);
    }
    return accum$;
  }.call(this, []);
};
this.TypeError = function () {
  function TypeError(param$) {
    this.message = param$;
  }
  return TypeError;
}();
NumberInterface = {
  toString: {
    name: 'function',
    'arguments': [],
    returnType: 'String'
  }
};
ArrayInterface = {
  length: 'Number',
  push: {
    name: 'function',
    'arguments': ['T'],
    returnType: 'void'
  },
  unshift: {
    name: 'function',
    'arguments': ['T'],
    returnType: 'void'
  },
  shift: {
    name: 'function',
    'arguments': [],
    returnType: 'T'
  },
  toString: {
    name: 'function',
    'arguments': [],
    returnType: 'String'
  }
};
ObjectInterface = function () {
  return {
    toString: {
      name: 'function',
      'arguments': [],
      returnType: 'String'
    },
    keys: {
      name: 'function',
      'arguments': ['Any'],
      returnType: { array: 'String' }
    }
  };
};
