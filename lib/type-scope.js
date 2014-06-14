void function () {
    var _, debug, ImplicitAny;
    _ = require('lodash');
    ImplicitAny = require('./types').ImplicitAny;
    debug = require('./helpers').debug;
    Scope = function () {
        function Scope(param$) {
            if (null == param$)
                param$ = null;
            this.parent = param$;
            this.id = _.uniqueId();
            if (null != this.parent)
                this.parent.nodes.push(this);
            this.name = '';
            this.nodes = [];
            this.vars = [];
            this.types = [];
            this._this = [];
            this._modules = [];
            this._returnables = [];
        }
        Scope.prototype.getPositionInScope = function () {
            var arr, cur;
            arr = [];
            cur = this;
            while (cur) {
                arr.push(cur.name);
                cur = cur.parent;
            }
            return arr.reverse();
        };
        Scope.prototype.addReturnable = function (typeRef) {
            return this._returnables.push(typeRef);
        };
        Scope.prototype.getReturnables = function () {
            return _.cloneDeep(this._returnables);
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
            var mod, scope;
            scope = new ModuleScope(this);
            scope.name = name;
            mod = {
                nodeType: 'module',
                identifier: { typeRef: name },
                scope: scope
            };
            this._modules.push(mod);
            return scope;
        };
        Scope.prototype.getModule = function (name) {
            var cache$;
            if (null != (cache$ = _.find(this._modules, function (mod) {
                    return mod.identifier.typeRef === name;
                })))
                return cache$.scope;
            else
                return void 0;
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
                if (!('undefined' !== typeof moduleName && null != moduleName))
                    continue;
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
        Scope.prototype.addType = function (node) {
            this.types.push(node);
            return node;
        };
        Scope.prototype.addPrimitiveType = function (node) {
            if (node.nodeType !== 'primitiveIdentifier')
                throw 'nodeType isnt primitiveIdentifier';
            this.types.push(node);
            return node;
        };
        Scope.prototype.addStructType = function (structNode) {
            var ann, mod, propName, ref;
            if (structNode.nodeType !== 'struct')
                throw 'node isnt structNode';
            ref = structNode.name.identifier.typeRef;
            if (_.isString(ref)) {
                mod = this;
                propName = ref;
            } else {
                mod = this.resolveNamespace(ref.left, true);
                propName = ref.right;
            }
            ann = _.clone(structNode.expr);
            ann.identifier = structNode.name.identifier;
            ann.identifier.typeRef = propName;
            return mod.types.push(ann);
        };
        Scope.prototype.getTypeByString = function (typeName) {
            return _.find(this.types, function (i, n) {
                return i.identifier.typeRef === typeName;
            });
        };
        Scope.prototype.getTypeByMemberAccess = function (typeRef) {
            var mod, ns, propName, ret;
            ns = typeRef.left;
            propName = typeRef.right;
            mod = this.resolveNamespace(ns);
            ret = _.find(mod.types, function (node) {
                return node.identifier.typeRef === propName;
            });
            return (null != ret ? ret.nodeType : void 0) === 'struct' ? null != ret ? ret.members : void 0 : ret;
        };
        Scope.prototype.getType = function (typeRef) {
            if (_.isString(typeRef)) {
                return this.getTypeByString(typeRef);
            } else if ((null != typeRef ? typeRef.nodeType : void 0) === 'MemberAccess') {
                return this.getTypeByMemberAccess(typeRef);
            }
        };
        Scope.prototype.getTypeInScope = function (typeRef) {
            var ret;
            ret = this.getType(typeRef) || (null != this.parent ? this.parent.getTypeInScope(typeRef) : void 0) || null;
            return ret;
        };
        Scope.prototype.getTypeByNode = function (node) {
            switch (null != node ? node.nodeType : void 0) {
            case 'members':
                return node;
            case 'primitiveIdentifier':
                return node;
            case 'identifier':
                return this.getTypeInScope(node.identifier.typeRef);
            case 'functionType':
                return ImplicitAny;
            default:
                return ImplicitAny;
            }
        };
        Scope.prototype.getTypeByIdentifier = function (identifier) {
            return this.getTypeInScope(identifier.typeRef);
        };
        Scope.prototype.addThis = function (type, args) {
            if (null == args)
                args = [];
            return this._this.push(type);
        };
        Scope.prototype.getThis = function (propName) {
            return _.find(this._this, function (v) {
                return v.identifier.typeRef === propName;
            });
        };
        Scope.prototype.getThisByNode = function (node) {
            var cache$, typeName;
            typeName = node.identifier.typeRef;
            if (null != (cache$ = this.getThis(typeName)))
                return cache$.typeAnnotation;
            else
                return void 0;
        };
        Scope.prototype.addVar = function (type, args) {
            if (null == args)
                args = [];
            return this.vars.push(type);
        };
        Scope.prototype.getVar = function (typeName) {
            return _.find(this.vars, function (v) {
                return v.identifier.typeRef === typeName;
            });
        };
        Scope.prototype.getVarInScope = function (typeName) {
            return this.getVar(typeName) || (null != this.parent ? this.parent.getVarInScope(typeName) : void 0) || void 0;
        };
        Scope.prototype.getTypeByVarNode = function (node) {
            var cache$, typeName;
            typeName = node.identifier.typeRef;
            if (null != (cache$ = this.getVarInScope(typeName)))
                return cache$.typeAnnotation;
            else
                return void 0;
        };
        Scope.prototype.getTypeByVarName = function (varName) {
            var cache$;
            if (null != (cache$ = this.getVarInScope(varName)))
                return cache$.typeAnnotation;
            else
                return void 0;
        };
        Scope.prototype.checkAcceptableObject = function (left, right) {
            return false;
        };
        Scope.prototype.getHighestCommonType = function (list) {
            var cache$, head, tail;
            cache$ = list;
            head = cache$[0];
            tail = 2 <= cache$.length ? [].slice.call(cache$, 1) : [];
            return _.cloneDeep(_.reduce(tail, function (this$) {
                return function (a, b) {
                    return this$.compareAsParent(a, b);
                };
            }(this), head));
        };
        Scope.prototype.compareAsParent = function (a, b) {
            var isAcceptable, retA, retB;
            isAcceptable = require('./type-checker').isAcceptable;
            if ((null != a && null != a.identifier ? a.identifier.typeRef : void 0) === 'Undefined' || (null != a && null != a.identifier ? a.identifier.typeRef : void 0) === 'Null') {
                b = _.cloneDeep(b);
                if (null != (null != b ? b.identifier : void 0))
                    b.identifier.nullable = true;
                return b;
            }
            if ((null != b && null != b.identifier ? b.identifier.typeRef : void 0) === 'Undefined' || (null != b && null != b.identifier ? b.identifier.typeRef : void 0) === 'Null') {
                a = _.cloneDeep(a);
                if (null != (null != a ? a.identifier : void 0))
                    a.identifier.nullable = true;
                return a;
            }
            retA = isAcceptable(this, a, b);
            retB = isAcceptable(this, b, a);
            if (retA && retB) {
                return b;
            } else if (retA) {
                return a;
            } else if (retB) {
                return b;
            } else {
                return ImplicitAny;
            }
        };
        return Scope;
    }();
    ClassScope = function (super$) {
        extends$(ClassScope, super$);
        function ClassScope() {
            super$.apply(this, arguments);
        }
        ClassScope.prototype.getConstructorType = function () {
            var cache$;
            if (null != (cache$ = _.find(this._this, function (v) {
                    return v.identifier.typeRef === '_constructor_';
                })))
                return cache$.typeAnnotation;
            else
                return void 0;
        };
        return ClassScope;
    }(Scope);
    ModuleScope = function (super$1) {
        extends$(ModuleScope, super$1);
        function ModuleScope() {
            super$1.apply(this, arguments);
        }
        ;
        return ModuleScope;
    }(Scope);
    FunctionScope = function (super$2) {
        extends$(FunctionScope, super$2);
        function FunctionScope() {
            super$2.apply(this, arguments);
        }
        ;
        return FunctionScope;
    }(Scope);
    module.exports = {
        Scope: Scope,
        ClassScope: ClassScope,
        FunctionScope: FunctionScope,
        ModuleScope: ModuleScope
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