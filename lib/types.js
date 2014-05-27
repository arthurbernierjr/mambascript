void function () {
    var _, cache$, checkAcceptableObject, clone, debug, find, initializeGlobalTypes, pj, render, reporter, rewrite, typeErrorText;
    pj = function () {
        try {
            return require('prettyjson');
        } catch (e$) {
            return;
        }
    }.call(this);
    render = function (obj) {
        if (null != pj)
            return pj.render(obj);
    };
    debug = require('./helpers').debug;
    reporter = require('./reporter');
    cache$ = require('./type-helpers');
    clone = cache$.clone;
    rewrite = cache$.rewrite;
    reporter = require('./reporter');
    find = require('./functional-helpers').find;
    _ = require('lodash');
    typeErrorText = function (left, right) {
        return 'TypeError: ' + JSON.stringify(left) + ' expect to ' + JSON.stringify(right);
    };
    Type = function () {
        function Type() {
        }
        return Type;
    }();
    ObjectType = function (super$) {
        extends$(ObjectType, super$);
        function ObjectType(param$) {
            this.typeName = param$;
        }
        return ObjectType;
    }(Type);
    ArrayType = function (super$1) {
        extends$(ArrayType, super$1);
        function ArrayType(typeName) {
            this.array = typeName;
        }
        return ArrayType;
    }(Type);
    Possibilites = function (super$2) {
        extends$(Possibilites, super$2);
        function Possibilites(arr) {
            var i;
            if (null == arr)
                arr = [];
            for (var i$ = 0, length$ = arr.length; i$ < length$; ++i$) {
                i = arr[i$];
                this.push(i);
            }
        }
        return Possibilites;
    }(Array);
    checkAcceptableObject = function (this$) {
        return function (left, right, scope) {
            var cur, extended_list, i, key, l_arg, lval, r, results;
            if (null != (null != left ? left._base_ : void 0) && null != left._templates_)
                left = left._base_;
            if (null != (null != right ? right.possibilities : void 0)) {
                results = function (accum$) {
                    for (var i$ = 0, length$ = right.possibilities.length; i$ < length$; ++i$) {
                        r = right.possibilities[i$];
                        accum$.push(checkAcceptableObject(left, r, scope));
                    }
                    return accum$;
                }.call(this$, []);
                return results.every(function (i) {
                    return !i;
                }) ? false : results.filter(function (i) {
                    return i;
                }).join('\n');
            }
            if (left === 'Any')
                return false;
            if (null != left ? left['arguments'] : void 0) {
                if (left === void 0 || left === 'Any')
                    return;
                if (null != left['arguments'])
                    left['arguments'];
                else
                    left['arguments'] = [];
                results = function (accum$1) {
                    for (var i$1 = 0, length$1 = left['arguments'].length; i$1 < length$1; ++i$1) {
                        l_arg = left['arguments'][i$1];
                        i = i$1;
                        accum$1.push(checkAcceptableObject(l_arg, right['arguments'][i], scope));
                    }
                    return accum$1;
                }.call(this$, []);
                return results.every(function (i) {
                    return !i;
                }) ? false : results.filter(function (i) {
                    return i;
                }).join('\n');
                if (right.returnType !== 'Any')
                    return checkAcceptableObject(left.returnType, right.returnType, scope);
                return false;
            }
            if (null != (null != left ? left.array : void 0)) {
                if (right.array instanceof Array) {
                    results = function (accum$2) {
                        for (var i$2 = 0, length$2 = right.array.length; i$2 < length$2; ++i$2) {
                            r = right.array[i$2];
                            accum$2.push(checkAcceptableObject(left.array, r, scope));
                        }
                        return accum$2;
                    }.call(this$, []);
                    return results.every(function (i) {
                        return !i;
                    }) ? false : results.filter(function (i) {
                        return i;
                    }).join('\n');
                } else {
                    return checkAcceptableObject(left.array, right.array, scope);
                }
            } else if (null != (null != right ? right.array : void 0)) {
                if (left === 'Array' || left === 'Any' || left === void 0) {
                    return false;
                } else {
                    return typeErrorText(left, right);
                }
            } else if (typeof left === 'string' && typeof right === 'string') {
                cur = scope.getTypeInScope(left);
                extended_list = [left];
                while (cur._extends_) {
                    extended_list.push(cur._extends_);
                    cur = scope.getTypeInScope(cur._extends_);
                }
                if (left === 'Any' || right === 'Any' || in$(right, extended_list)) {
                    return false;
                } else {
                    return typeErrorText(left, right);
                }
            } else if (typeof left === 'object' && typeof right === 'object') {
                results = function (accum$3) {
                    for (key in left) {
                        lval = left[key];
                        accum$3.push(right[key] === void 0 && ('undefined' !== typeof lval && null != lval) && !(key === 'returnType' || key === 'type' || key === 'possibilities') ? '\'' + key + '\' is not defined on right' : checkAcceptableObject(lval, right[key], scope));
                    }
                    return accum$3;
                }.call(this$, []);
                return results.every(function (i) {
                    return !i;
                }) ? false : results.filter(function (i) {
                    return i;
                }).join('\n');
            } else if (left === void 0 || right === void 0) {
                return false;
            } else {
                return typeErrorText(left, right);
            }
        };
    }(this);
    initializeGlobalTypes = function (node) {
        node.addType({
            identifier: {
                typeName: 'Any',
                typeArguments: [],
                isArray: false
            }
        });
        node.addType({
            identifier: {
                typeName: 'String',
                typeArguments: [],
                isArray: false,
                isPrimitive: true
            }
        });
        return node.addType({
            identifier: {
                typeName: 'Int',
                typeArguments: [],
                isArray: false,
                isPrimitive: true
            }
        });
    };
    VarSymbol = function () {
        function VarSymbol(param$) {
            var cache$1;
            {
                cache$1 = param$;
                this.typeName = cache$1.typeName;
                this.explicit = cache$1.explicit;
            }
            if (null != this.explicit)
                this.explicit;
            else
                this.explicit = false;
        }
        return VarSymbol;
    }();
    TypeSymbol = function () {
        function TypeSymbol(param$) {
            var cache$1;
            {
                cache$1 = param$;
                this.typeName = cache$1.typeName;
                this.typeArguments = cache$1.typeArguments;
                this.isArray = cache$1.isArray;
                this.heritages = cache$1.heritages;
                this.isPrimitive = cache$1.isPrimitive;
            }
        }
        return TypeSymbol;
    }();
    Scope = function () {
        function Scope(param$) {
            var instance$;
            instance$ = this;
            this.extendTypeLiteral = function (a) {
                return Scope.prototype.extendTypeLiteral.apply(instance$, arguments);
            };
            if (null == param$)
                param$ = null;
            this.parent = param$;
            if (null != this.parent)
                this.parent.nodes.push(this);
            this.name = '';
            this.nodes = [];
            this._vars = {};
            this._types = [];
            this._this = {};
            this._modules = {};
            this._returnables = [];
        }
        Scope.prototype.addReturnable = function (symbol, typeName) {
            return this._returnables.push(typeName);
        };
        Scope.prototype.getReturnables = function () {
            return this._returnables;
        };
        Scope.prototype.getRoot = function () {
            var root;
            if (!this.parent)
                return this;
            root = this.parent;
            while (true) {
                if (root.parent) {
                    root = root.parent;
                } else {
                    break;
                }
            }
            return root;
        };
        Scope.prototype.addModule = function (name) {
            var scope;
            scope = new Scope(this);
            scope.name = name;
            return this._modules[name] = scope;
        };
        Scope.prototype.getModule = function (name) {
            return this._modules[name];
        };
        Scope.prototype.getModuleInScope = function (name) {
            return this.getModule(name) || (null != this.parent ? this.parent.getModuleInScope(name) : void 0) || void 0;
        };
        Scope.prototype.addType = function (structNode) {
            var cur, mod, moduleName, name, node, ns, symbol;
            if (typeof structNode.identifier.typeName === 'string') {
                this._types.push(structNode);
                return structNode;
            } else if (typeof structNode.identifier.typeName === 'object') {
                symbol = structNode.identifier.typeName;
                ns = [];
                name = symbol.right;
                cur = symbol.left;
                while (true) {
                    if (typeof cur === 'string') {
                        ns.unshift(cur);
                        break;
                    } else {
                        ns.unshift(cur.right);
                        cur = cur.left;
                    }
                }
                cur = this;
                for (var i$ = 0, length$ = ns.length; i$ < length$; ++i$) {
                    moduleName = ns[i$];
                    mod = cur.getModuleInScope(moduleName);
                    if (!mod)
                        mod = cur.addModule(moduleName);
                    cur = mod;
                }
                node = _.clone(structNode);
                node.identifier.typeName = name;
                return cur.addType(node);
            }
        };
        Scope.prototype.getType = function (typeName) {
            var cur, mod, moduleName, name, ns;
            if (typeof typeName !== 'object')
                return find(this._types, function (i) {
                    return i.identifier.typeName === typeName;
                });
            ns = [];
            name = typeName.right;
            cur = typeName.left;
            while (true) {
                if (typeof cur === 'string') {
                    ns.unshift(cur);
                    break;
                } else {
                    ns.unshift(cur.right);
                    cur = cur.left;
                }
            }
            cur = this;
            for (var i$ = 0, length$ = ns.length; i$ < length$; ++i$) {
                moduleName = ns[i$];
                mod = cur.getModuleInScope(moduleName);
                if (!mod)
                    return null;
                cur = mod;
            }
            return cur.getType(name);
        };
        Scope.prototype.getTypeInScope = function (symbol) {
            return this.getType(symbol) || (null != this.parent ? this.parent.getTypeInScope(symbol) : void 0) || void 0;
        };
        Scope.prototype.addThis = function (symbol, typeName) {
            var n, obj, replacer, rewrite_to, T, t;
            if (null != (null != typeName ? typeName._base_ : void 0)) {
                T = this.getType(typeName._base_);
                if (!T)
                    return void 0;
                obj = clone(T.typeName);
                if (T._templates_) {
                    rewrite_to = typeName._templates_;
                    replacer = {};
                    for (var i$ = 0, length$ = T._templates_.length; i$ < length$; ++i$) {
                        t = T._templates_[i$];
                        n = i$;
                        replacer[t] = rewrite_to[n];
                    }
                    rewrite(obj, replacer);
                }
                return this._this[symbol] = new VarSymbol({ typeName: obj });
            } else {
                return this._this[symbol] = new VarSymbol({ typeName: typeName });
            }
        };
        Scope.prototype.getThis = function (symbol) {
            return this._this[symbol];
        };
        Scope.prototype.addVar = function (symbol, typeName, explicit) {
            var n, obj, replacer, rewrite_to, T, t;
            if (null != (null != typeName ? typeName._base_ : void 0)) {
                T = this.getType(typeName._base_);
                if (!T)
                    return void 0;
                obj = clone(T.typeName);
                if (T._templates_) {
                    rewrite_to = typeName._templates_;
                    replacer = {};
                    for (var i$ = 0, length$ = T._templates_.length; i$ < length$; ++i$) {
                        t = T._templates_[i$];
                        n = i$;
                        replacer[t] = rewrite_to[n];
                    }
                    rewrite(obj, replacer);
                }
                return this._vars[symbol] = new VarSymbol({
                    typeName: obj,
                    explicit: explicit
                });
            } else {
                return this._vars[symbol] = new VarSymbol({
                    typeName: typeName,
                    explicit: explicit
                });
            }
        };
        Scope.prototype.getVar = function (symbol) {
            return this._vars[symbol];
        };
        Scope.prototype.getVarInScope = function (symbol) {
            return this.getVar(symbol) || (null != this.parent ? this.parent.getVarInScope(symbol) : void 0) || void 0;
        };
        Scope.prototype.isImplicitVarInScope = function (symbol) {
            return this.isImplicitVar(symbol) || (null != this.parent ? this.parent.isImplicitVarInScope(symbol) : void 0) || void 0;
        };
        Scope.prototype.extendTypeLiteral = function (node) {
            var i, key, ret, typeName, val;
            if (typeof node === 'string' || (null != node ? node.nodeType : void 0) === 'MemberAccess') {
                Type = this.getTypeInScope(node);
                typeName = null != Type ? Type.typeName : void 0;
                switch (typeof typeName) {
                case 'object':
                    return this.extendTypeLiteral(typeName);
                case 'string':
                    return typeName;
                }
            } else if (typeof node === 'object') {
                if (node instanceof Array) {
                    return function (accum$) {
                        for (var i$ = 0, length$ = node.length; i$ < length$; ++i$) {
                            i = node[i$];
                            accum$.push(this.extendTypeLiteral(i));
                        }
                        return accum$;
                    }.call(this, []);
                } else {
                    ret = {};
                    for (key in node) {
                        val = node[key];
                        ret[key] = this.extendTypeLiteral(val);
                    }
                    return ret;
                }
            }
        };
        Scope.prototype.checkAcceptableObject = function (left, right) {
            var l, r;
            l = this.extendTypeLiteral(left);
            r = this.extendTypeLiteral(right);
            return checkAcceptableObject(l, r, this);
        };
        return Scope;
    }();
    ClassScope = function (super$3) {
        extends$(ClassScope, super$3);
        function ClassScope() {
            super$3.apply(this, arguments);
        }
        ;
        return ClassScope;
    }(Scope);
    FunctionScope = function (super$4) {
        extends$(FunctionScope, super$4);
        function FunctionScope() {
            super$4.apply(this, arguments);
        }
        ;
        return FunctionScope;
    }(Scope);
    module.exports = {
        checkAcceptableObject: checkAcceptableObject,
        initializeGlobalTypes: initializeGlobalTypes,
        VarSymbol: VarSymbol,
        TypeSymbol: TypeSymbol,
        Scope: Scope,
        ClassScope: ClassScope,
        FunctionScope: FunctionScope,
        ArrayType: ArrayType,
        ObjectType: ObjectType,
        Type: Type,
        Possibilites: Possibilites
    };
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
        child.prototype = new ctor();
        child.__super__ = parent.prototype;
        return child;
    }
    function in$(member, list) {
        for (var i = 0, length = list.length; i < length; ++i)
            if (i in list && list[i] === member)
                return true;
        return false;
    }
}.call(this);