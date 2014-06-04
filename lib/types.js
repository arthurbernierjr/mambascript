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
            this.typeRef = param$;
        }
        return ObjectType;
    }(Type);
    ArrayType = function (super$1) {
        extends$(ArrayType, super$1);
        function ArrayType(typeRef) {
            this.array = typeRef;
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
    checkAcceptableObject = function (left, right, scope) {
        return false;
    };
    initializeGlobalTypes = function (node) {
        var AnyType, FloatType, IntType, NumberType, StringType;
        AnyType = {
            nodeType: 'primitiveIdentifier',
            identifier: {
                typeRef: 'Any',
                isPrimitive: true
            }
        };
        StringType = {
            nodeType: 'primitiveIdentifier',
            identifier: {
                typeRef: 'String',
                isPrimitive: true
            }
        };
        IntType = {
            nodeType: 'primitiveIdentifier',
            identifier: {
                typeRef: 'Int',
                isPrimitive: true
            }
        };
        FloatType = {
            nodeType: 'primitiveIdentifier',
            identifier: {
                typeRef: 'Float',
                isPrimitive: true
            },
            heritages: {
                extend: {
                    identifier: {
                        typeRef: 'Int',
                        isPrimitive: true
                    }
                }
            }
        };
        NumberType = {
            nodeType: 'primitiveIdentifier',
            identifier: {
                typeRef: 'Number',
                isPrimitive: true
            },
            heritages: {
                extend: {
                    identifier: {
                        typeRef: 'Float',
                        isPrimitive: true
                    }
                }
            }
        };
        node.addPrimitiveType(AnyType);
        node.addPrimitiveType(StringType);
        node.addPrimitiveType(IntType);
        node.addPrimitiveType(FloatType);
        return node.addPrimitiveType(NumberType);
    };
    VarSymbol = function () {
        function VarSymbol(param$) {
            var cache$1;
            {
                cache$1 = param$;
                this.typeRef = cache$1.typeRef;
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
                this.typeRef = cache$1.typeRef;
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
        Scope.prototype.addReturnable = function (symbol, typeRef) {
            return this._returnables.push(typeRef);
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
        Scope.prototype.resolveNamespace = function (ref, autoCreate) {
            var cur, mod, moduleName, ns;
            if (null == autoCreate)
                autoCreate = false;
            ns = [];
            cur = ref;
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
                    if (autoCreate) {
                        mod = cur.addModule(moduleName);
                    } else {
                        return null;
                    }
                cur = mod;
            }
            return cur;
        };
        Scope.prototype.addPrimitiveType = function (node) {
            if (node.nodeType !== 'primitiveIdentifier')
                throw 'nodeType isnt primitiveIdentifier';
            this._types.push(node);
            return node;
        };
        Scope.prototype.addStructType = function (structNode) {
            var mod, node, propName, ref;
            if (structNode.nodeType !== 'struct')
                throw 'node isnt structNode';
            ref = structNode.identifier.identifier.typeRef;
            if (_.isString(ref)) {
                mod = this;
                propName = ref;
            } else {
                mod = this.resolveNamespace(ref.left, true);
                propName = ref.right;
            }
            node = _.clone(structNode);
            node.identifier.typeRef = propName;
            delete node.data;
            delete node.line;
            delete node.offset;
            delete node.column;
            delete node.raw;
            node = {
                nodeType: 'struct',
                identifier: { typeRef: propName },
                members: node.typeAnnotation
            };
            return mod._types.push(node);
        };
        Scope.prototype.getTypeByString = function (typeName) {
            var ret;
            ret = find(this._types, function (i) {
                return i.identifier.typeRef === typeName;
            });
            return ret.nodeType === 'struct' ? ret.members : ret;
        };
        Scope.prototype.getTypeByMemberAccess = function (typeRef) {
            var mod, ns, property, ret;
            ns = typeRef.left;
            property = typeRef.right;
            mod = this.resolveNamespace(ns);
            ret = _.find(mod._types, function (node) {
                return node.identifier.typeRef === property;
            });
            return ret.nodeType === 'struct' ? ret.members : ret;
        };
        Scope.prototype.getType = function (typeRef) {
            if (_.isString(typeRef)) {
                return this.getTypeByString(typeRef);
            } else if ((null != typeRef ? typeRef.nodeType : void 0) === 'MemberAccess') {
                return this.getTypeByMemberAccess(typeRef);
            }
        };
        Scope.prototype.getTypeInScope = function (typeRef) {
            return this.getType(typeRef) || (null != this.parent ? this.parent.getTypeInScope(typeRef) : void 0) || null;
        };
        Scope.prototype.getTypeByIdentifier = function (node) {
            if (node.nodeType !== 'identifier')
                throw 'node is not identifier node';
            switch (node.nodeType) {
            case 'members':
                return node;
            case 'identifier':
                return this.getTypeInScope(node.identifier.typeRef);
            }
        };
        Scope.prototype.addThis = function (symbol, typeRef) {
            var n, obj, replacer, rewrite_to, T, t;
            if (null != (null != typeRef ? typeRef._base_ : void 0)) {
                T = this.getType(typeRef._base_);
                if (!T)
                    return void 0;
                obj = clone(T.typeRef);
                if (T._templates_) {
                    rewrite_to = typeRef._templates_;
                    replacer = {};
                    for (var i$ = 0, length$ = T._templates_.length; i$ < length$; ++i$) {
                        t = T._templates_[i$];
                        n = i$;
                        replacer[t] = rewrite_to[n];
                    }
                    rewrite(obj, replacer);
                }
                return this._this[symbol] = new VarSymbol({ typeRef: obj });
            } else {
                return this._this[symbol] = new VarSymbol({ typeRef: typeRef });
            }
        };
        Scope.prototype.getThis = function (symbol) {
            return this._this[symbol];
        };
        Scope.prototype.addVar = function (symbol, typeRef, explicit) {
            var n, obj, replacer, rewrite_to, T, t;
            if (null != (null != typeRef ? typeRef._base_ : void 0)) {
                T = this.getType(typeRef._base_);
                if (!T)
                    return void 0;
                obj = clone(T.typeRef);
                if (T._templates_) {
                    rewrite_to = typeRef._templates_;
                    replacer = {};
                    for (var i$ = 0, length$ = T._templates_.length; i$ < length$; ++i$) {
                        t = T._templates_[i$];
                        n = i$;
                        replacer[t] = rewrite_to[n];
                    }
                    rewrite(obj, replacer);
                }
                return this._vars[symbol] = new VarSymbol({
                    typeRef: obj,
                    explicit: explicit
                });
            } else {
                return this._vars[symbol] = new VarSymbol({
                    typeRef: typeRef,
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
            var i, key, ret, typeRef, val;
            if (typeof node === 'string' || (null != node ? node.nodeType : void 0) === 'MemberAccess') {
                Type = this.getTypeInScope(node);
                typeRef = null != Type ? Type.typeRef : void 0;
                switch (typeof typeRef) {
                case 'object':
                    return this.extendTypeLiteral(typeRef);
                case 'string':
                    return typeRef;
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
}.call(this);