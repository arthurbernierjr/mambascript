void function () {
    var _, cache$, checkNodes, ClassScope, CS, debug, FunctionScope, g, identifier, ImplicitAnyAnnotation, initializeGlobalTypes, isAcceptable, pj, render, reporter, Scope, typeErrorText, walk, walk_arrayInializer, walk_assignOp, walk_binOp, walk_block, walk_bool, walk_class, walk_classProtoAssignOp, walk_conditional, walk_float, walk_for, walk_function, walk_functionApplication, walk_identifier, walk_int, walk_memberAccess, walk_newOp, walk_numbers, walk_objectInitializer, walk_primitives, walk_program, walk_range, walk_return, walk_string, walk_struct, walk_switch, walk_this, walk_vardef;
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
    CS = require('./nodes');
    _ = require('lodash');
    ImplicitAnyAnnotation = {
        implicit: true,
        identifier: {
            typeName: 'Any',
            typeArguments: [],
            isArray: false,
            isPrimitive: true
        }
    };
    identifier = function (name) {
        return {
            typeName: name,
            isArray: false,
            typeArguments: []
        };
    };
    typeErrorText = function (left, right) {
        return 'TypeError: ' + JSON.stringify(left) + ' expect to ' + JSON.stringify(right);
    };
    cache$ = require('./types');
    initializeGlobalTypes = cache$.initializeGlobalTypes;
    Scope = cache$.Scope;
    ClassScope = cache$.ClassScope;
    FunctionScope = cache$.FunctionScope;
    isAcceptable = function (scope, left, right) {
        if (!_.isObject(left) && !_.isObject(right)) {
            if (left === 'Any')
                return true;
            return _.isEqual(left, right);
        }
        debug('isAcceptable', null != left.typeAnnotation && null != left.typeAnnotation.identifier ? left.typeAnnotation.identifier.typeName : void 0);
        if (_.isString(null != left.typeAnnotation && null != left.typeAnnotation.identifier ? left.typeAnnotation.identifier.typeName : void 0) && _.isString(null != right.typeAnnotation && null != right.typeAnnotation.identifier ? right.typeAnnotation.identifier.typeName : void 0))
            return isAcceptable(scope, left.typeAnnotation.identifier.typeName, right.typeAnnotation.identifier.typeName);
        return _.all(left.typeAnnotation.properties.map(function (lprop, n) {
            var rprop;
            rprop = _.find(right.typeAnnotation.properties, function (rp) {
                return rp.identifier.typeName === lprop.identifier.typeName;
            });
            if (!(null != rprop))
                return false;
            return (null != lprop.typeAnnotation && null != lprop.typeAnnotation.properties ? lprop.typeAnnotation.properties.length : void 0) && (null != rprop.typeAnnotation && null != rprop.typeAnnotation.properties ? rprop.typeAnnotation.properties.length : void 0) ? isAcceptable(scope, lprop, rprop) : isAcceptable(scope, lprop.typeAnnotation.identifier.typeName, rprop.typeAnnotation.identifier.typeName);
        }));
    };
    g = 'undefined' !== typeof window && null != window ? window : global;
    checkNodes = function (cs_ast) {
        var i, root;
        if (!(null != (null != cs_ast.body ? cs_ast.body.statements : void 0)))
            return;
        if (g._root_) {
            root = g._root_;
        } else {
            g._root_ = root = new Scope();
            root.name = 'root';
            for (var cache$1 = [
                        'global',
                        'exports',
                        'module'
                    ], i$ = 0, length$ = cache$1.length; i$ < length$; ++i$) {
                i = cache$1[i$];
                root.addVar(i, 'Any', true);
            }
            initializeGlobalTypes(root);
        }
        walk(cs_ast, root);
        return root;
    };
    walk_struct = function (node, scope) {
        return scope.addType(node);
    };
    walk_vardef = function (node, scope) {
        var symbol;
        return;
        symbol = node.name === 'constructor' ? '_constructor_' : node.name;
        if (scope instanceof ClassScope) {
            return scope.addThis(symbol, node.expr);
        } else {
            return scope.addVar(symbol, node.expr);
        }
    };
    walk_program = function (node, scope) {
        walk(node.body.statements, scope);
        return node.typeAnnotation = { identifier: 'Program' };
    };
    walk_block = function (node, scope) {
        var last_typeAnnotation;
        walk(node.statements, scope);
        last_typeAnnotation = null != node.statements[node.statements.length - 1] ? node.statements[node.statements.length - 1].typeAnnotation : void 0;
        return node.typeAnnotation = last_typeAnnotation;
    };
    walk_return = function (node, scope) {
        return;
        walk(node.expression, scope);
        if (null != (null != node.expression && null != node.expression.typeAnnotation ? node.expression.typeAnnotation.identifier : void 0)) {
            scope.addReturnable(node.expression.typeAnnotation.identifier);
            return node.typeAnnotation = node.expression.typeAnnotation;
        }
    };
    walk_binOp = function (node, scope) {
        var left_type, right_type;
        return;
        walk(node.left, scope);
        walk(node.right, scope);
        left_type = null != node.left && null != node.left.typeAnnotation ? node.left.typeAnnotation.identifier : void 0;
        right_type = null != node.right && null != node.right.typeAnnotation ? node.right.typeAnnotation.identifier : void 0;
        if (left_type && right_type) {
            if (left_type === 'String' || right_type === 'String') {
                return node.typeAnnotation = { identifier: 'String' };
            } else if (left_type === 'Int' && right_type === 'Int') {
                return node.typeAnnotation = { identifier: 'Int' };
            } else if ((left_type === 'Int' || left_type === 'Float') && (right_type === 'Int' || right_type === 'Float')) {
                return node.typeAnnotation = { identifier: 'Float' };
            } else if ((left_type === 'Int' || left_type === 'Float' || left_type === 'Number') && (right_type === 'Int' || right_type === 'Float' || right_type === 'Number')) {
                return node.typeAnnotation = { identifier: 'Number' };
            } else if (left_type === right_type) {
                return node.typeAnnotation = { identifier: left_type };
            }
        } else {
            return node.typeAnnotation = { identifier: 'Any' };
        }
    };
    walk_conditional = function (node, scope) {
        var alternate_typeAnnotation, possibilities, typeAnnotation;
        return;
        walk(node.condition, scope);
        walk(node.consequent, scope);
        if (null != node.alternate)
            walk(node.alternate, scope);
        alternate_typeAnnotation = null != (null != node.alternate ? node.alternate.typeAnnotation : void 0) ? null != node.alternate ? node.alternate.typeAnnotation : void 0 : { identifier: 'Undefined' };
        possibilities = [];
        for (var cache$1 = [
                    null != node.consequent ? node.consequent.typeAnnotation : void 0,
                    alternate_typeAnnotation
                ], i$ = 0, length$ = cache$1.length; i$ < length$; ++i$) {
            typeAnnotation = cache$1[i$];
            if (!('undefined' !== typeof typeAnnotation && null != typeAnnotation))
                continue;
            if (null != (null != typeAnnotation.identifier ? typeAnnotation.identifier.possibilities : void 0)) {
                for (var i$1 = 0, length$1 = typeAnnotation.identifier.possibilities.length; i$1 < length$1; ++i$1) {
                    identifier = typeAnnotation.identifier.possibilities[i$1];
                    possibilities.push(identifier);
                }
            } else if (null != typeAnnotation.identifier) {
                possibilities.push(typeAnnotation.identifier);
            }
        }
        return node.typeAnnotation = { identifier: { possibilities: possibilities } };
    };
    walk_switch = function (node, scope) {
        var alternate_typeAnnotation, c, cond, possibilities;
        return;
        walk(node.expression, scope);
        for (var i$ = 0, length$ = node.cases.length; i$ < length$; ++i$) {
            c = node.cases[i$];
            for (var i$1 = 0, length$1 = c.conditions.length; i$1 < length$1; ++i$1) {
                cond = c.conditions[i$1];
                walk(c, scope);
            }
            walk(c.consequent, scope);
        }
        walk(node.consequent, scope);
        if (null != node.alternate)
            walk(node.alternate, scope);
        alternate_typeAnnotation = null != (null != node.alternate ? node.alternate.typeAnnotation : void 0) ? null != node.alternate ? node.alternate.typeAnnotation : void 0 : { identifier: 'Undefined' };
        possibilities = [];
        for (var i$2 = 0, length$2 = node.cases.length; i$2 < length$2; ++i$2) {
            c = node.cases[i$2];
            if (!(null != c.typeAnnotation))
                continue;
            possibilities.push(c.consequent.typeAnnotation);
        }
        possibilities.push(alternate_typeAnnotation.identifier);
        return node.typeAnnotation = { identifier: { possibilities: possibilities } };
    };
    walk_newOp = function (node, scope) {
        var arg, args, err, Type;
        return;
        for (var i$ = 0, length$ = node['arguments'].length; i$ < length$; ++i$) {
            arg = node['arguments'][i$];
            walk(arg, scope);
        }
        Type = scope.getTypeInScope(node.ctor.data);
        if (Type) {
            args = null != node['arguments'] ? node['arguments'].map(function (arg) {
                return null != arg.typeAnnotation ? arg.typeAnnotation.identifier : void 0;
            }) : void 0;
            if (err = scope.checkAcceptableObject(Type.identifier._constructor_, {
                    'arguments': null != args ? args : [],
                    returnType: 'Any'
                })) {
                err = typeErrorText(Type.identifier._constructor_, {
                    'arguments': null != args ? args : [],
                    returnType: 'Any'
                });
                return reporter.add_error(node, err);
            }
        }
        return node.typeAnnotation = { identifier: null != Type ? Type.identifier : void 0 };
    };
    walk_for = function (node, scope) {
        var err, nop;
        walk(node.target, scope);
        if (null != node.valAssignee)
            scope.addVar(node.valAssignee.data, null != (null != node.valAssignee && null != node.valAssignee.typeAnnotation ? node.valAssignee.typeAnnotation.identifier : void 0) ? null != node.valAssignee && null != node.valAssignee.typeAnnotation ? node.valAssignee.typeAnnotation.identifier : void 0 : 'Any');
        if (null != node.keyAssignee)
            scope.addVar(node.keyAssignee.data, null != (null != node.keyAssignee && null != node.keyAssignee.typeAnnotation ? node.keyAssignee.typeAnnotation.identifier : void 0) ? null != node.keyAssignee && null != node.keyAssignee.typeAnnotation ? node.keyAssignee.typeAnnotation.identifier : void 0 : 'Any');
        if (null != node.valAssignee)
            if (null != (null != node.target.typeAnnotation && null != node.target.typeAnnotation.identifier ? node.target.typeAnnotation.identifier.array : void 0)) {
                if (err = scope.checkAcceptableObject(node.valAssignee.typeAnnotation.identifier, node.target.typeAnnotation.identifier.array)) {
                    err = typeErrorText(node.valAssignee.typeAnnotation.identifier, node.target.typeAnnotation.identifier.array);
                    return reporter.add_error(node, err);
                }
            } else if ((null != node.target && null != node.target.typeAnnotation ? node.target.typeAnnotation.identifier : void 0) instanceof Object) {
                if (node.target.typeAnnotation.identifier instanceof Object)
                    for (nop in node.target.typeAnnotation.identifier) {
                        identifier = node.target.typeAnnotation.identifier[nop];
                        if (err = scope.checkAcceptableObject(node.valAssignee.typeAnnotation.identifier, identifier)) {
                            err = typeErrorText(node.valAssignee.typeAnnotation.identifier, identifier);
                            return reporter.add_error(node, err);
                        }
                    }
            }
        walk(node.body, scope);
        node.typeAnnotation = null != node.target ? node.target.typeAnnotation : void 0;
        delete scope._vars[null != node.valAssignee ? node.valAssignee.data : void 0];
        return delete scope._vars[null != node.keyAssignee ? node.keyAssignee.data : void 0];
    };
    walk_classProtoAssignOp = function (node, scope) {
        var left, right, symbol;
        return;
        left = node.assignee;
        right = node.expression;
        symbol = left.data;
        walk(left, scope);
        if (right['instanceof'](CS.Function) && scope.getThis(symbol)) {
            walk_function(right, scope, scope.getThis(symbol).identifier);
        } else {
            walk(right, scope);
        }
        symbol = left.data;
        if (null != right.typeAnnotation)
            return scope.addThis(symbol, right.typeAnnotation.identifier);
    };
    walk_assignOp = function (node, scope) {
        var arg, err, index, l, l_type, left, member, n, preRegisteredTypeAnnotation, r, right, symbol, T;
        left = node.assignee;
        right = node.expression;
        symbol = left.data;
        preRegisteredTypeAnnotation = left.typeAnnotation;
        walk(left, scope);
        if (preRegisteredTypeAnnotation && ((null != right.typeAnnotation && null != right.typeAnnotation.identifier ? right.typeAnnotation.identifier.identifier : void 0) === (null != left.typeAnnotation && null != left.typeAnnotation.identifier ? left.typeAnnotation.identifier.identifier : void 0) && (null != left.typeAnnotation && null != left.typeAnnotation.identifier ? left.typeAnnotation.identifier.identifier : void 0) === 'Function')) {
            if (scope.checkAcceptableObject(left.typeAnnotation.identifier.returnType, right.typeAnnotation.identifier.returnType)) {
                err = typeErrorText(left.typeAnnotation.identifier.returnType, right.typeAnnotation.identifier.returnType);
                return reporter.add_error(node, err);
            }
            for (var i$ = 0, length$ = left.typeAnnotation.identifier['arguments'].length; i$ < length$; ++i$) {
                arg = left.typeAnnotation.identifier['arguments'][i$];
                n = i$;
                if (scope.checkAcceptableObject(null != left.typeAnnotation.identifier['arguments'][n] ? left.typeAnnotation.identifier['arguments'][n].identifier : void 0, null != right.typeAnnotation.identifier['arguments'][n] ? right.typeAnnotation.identifier['arguments'][n].identifier : void 0)) {
                    err = typeErrorText(left.typeAnnotation.identifier, right.typeAnnotation.identifier);
                    return reporter.add_error(node, err);
                }
            }
        }
        if (('function' === typeof right['instanceof'] ? right['instanceof'](CS.Function) : void 0) && scope.getVarInScope(symbol)) {
            walk_function(right, scope, scope.getVarInScope(symbol).identifier);
        } else if (('function' === typeof right['instanceof'] ? right['instanceof'](CS.Function) : void 0) && preRegisteredTypeAnnotation) {
            walk_function(right, scope, left.typeAnnotation.identifier);
        } else {
            walk(right, scope);
        }
        if (left['instanceof'](CS.ArrayInitialiser)) {
            return function (accum$) {
                for (var i$1 = 0, length$1 = left.members.length; i$1 < length$1; ++i$1) {
                    member = left.members[i$1];
                    index = i$1;
                    if (!(null != member.data))
                        continue;
                    l = null != left.typeAnnotation && null != left.typeAnnotation.identifier && null != left.typeAnnotation.identifier.array ? left.typeAnnotation.identifier.array[index] : void 0;
                    r = null != right.typeAnnotation && null != right.typeAnnotation.identifier && null != right.typeAnnotation.identifier.array ? right.typeAnnotation.identifier.array[index] : void 0;
                    if (err = scope.checkAcceptableObject(l, r)) {
                        err = typeErrorText(l, r);
                        reporter.add_error(node, err);
                    }
                    accum$.push(l ? scope.addVar(member.data, l, true) : scope.addVar(member.data, 'Any', false));
                }
                return accum$;
            }.call(this, []);
        } else if (null != (null != left ? left.members : void 0)) {
            return function (accum$1) {
                for (var i$2 = 0, length$2 = left.members.length; i$2 < length$2; ++i$2) {
                    member = left.members[i$2];
                    if (!(null != (null != member.key ? member.key.data : void 0)))
                        continue;
                    accum$1.push(scope.getVarInScope(member.key.data) ? (l_type = scope.getVarInScope(member.key.data).identifier, (err = scope.checkAcceptableObject(l_type, null != right.typeAnnotation && null != right.typeAnnotation.identifier ? right.typeAnnotation.identifier[member.key.data] : void 0)) ? (err = typeErrorText(l_type, null != right.typeAnnotation && null != right.typeAnnotation.identifier ? right.typeAnnotation.identifier[member.key.data] : void 0), reporter.add_error(node, err)) : void 0) : scope.addVar(member.key.data, 'Any', false));
                }
                return accum$1;
            }.call(this, []);
        } else if (left['instanceof'](CS.MemberAccessOp)) {
            if (left.expression['instanceof'](CS.This)) {
                T = scope.getThis(left.memberName);
                if (null != T)
                    left.typeAnnotation = T;
                if (null != T)
                    if (err = scope.checkAcceptableObject(left.typeAnnotation.identifier, right.typeAnnotation.identifier)) {
                        err = typeErrorText(left.typeAnnotation.identifier, right.typeAnnotation.identifier);
                        return reporter.add_error(node, err);
                    }
            } else if (null != (null != left.typeAnnotation ? left.typeAnnotation.identifier : void 0) && null != (null != right.typeAnnotation ? right.typeAnnotation.identifier : void 0)) {
                if (left.typeAnnotation.identifier !== 'Any')
                    if (err = scope.checkAcceptableObject(left.typeAnnotation.identifier, right.typeAnnotation.identifier)) {
                        err = typeErrorText(left.typeAnnotation.identifier, right.typeAnnotation.identifier);
                        return reporter.add_error(node, err);
                    }
            }
        } else if (left['instanceof'](CS.Identifier)) {
            if (scope.getVarInScope(symbol) && preRegisteredTypeAnnotation)
                return reporter.add_error(node, 'double bind: ' + symbol);
            if (null != left.typeAnnotation && null != right.typeAnnotation) {
                debug('assign', left);
                debug('assign', right);
                if (null != (null != left.typeAnnotation ? left.typeAnnotation.properties : void 0)) {
                    if (!isAcceptable(scope, left, right)) {
                        err = typeErrorText(left.typeAnnotation, right.typeAnnotation);
                        return reporter.add_error(node, err);
                    }
                } else if (!isAcceptable(scope, scope.getTypeInScope(left.typeAnnotation.typeName), right)) {
                    err = typeErrorText(left.typeAnnotation, right.typeAnnotation);
                    return reporter.add_error(node, err);
                }
            }
            if (!preRegisteredTypeAnnotation && (null != right.typeAnnotation ? right.typeAnnotation.explicit : void 0)) {
                return scope.addVar(symbol, right.typeAnnotation.identifier, true);
            } else {
                return scope.addVar(symbol, left.typeAnnotation.identifier, true);
            }
        } else {
            return scope.addVar(symbol, 'Any', false);
        }
    };
    walk_primitives = function (node, scope) {
        switch (false) {
        case !node['instanceof'](CS.String):
            return walk_string(node, scope);
        case !node['instanceof'](CS.Bool):
            return walk_bool(node, scope);
        case !node['instanceof'](CS.Int):
            return walk_int(node, scope);
        case !node['instanceof'](CS.Float):
            return walk_float(node, scope);
        case !node['instanceof'](CS.Numbers):
            return walk_numbers(node, scope);
        }
    };
    walk_string = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                implicit: true,
                identifier: {
                    typeName: 'String',
                    typeArguments: [],
                    isArray: false,
                    isPrimitive: true
                }
            };
    };
    walk_int = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                implicit: true,
                identifier: {
                    typeName: 'Int',
                    typeArguments: [],
                    isArray: false,
                    isPrimitive: true
                }
            };
    };
    walk_float = function (node, scope) {
        return;
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                identifier: 'Float',
                primitive: true
            };
    };
    walk_numbers = function (node, scope) {
        return;
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                identifier: 'Number',
                primitive: true
            };
    };
    walk_bool = function (node, scope) {
        return;
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                identifier: 'Boolean',
                primitive: true
            };
    };
    walk_identifier = function (node, scope) {
        var symbolName, Var;
        symbolName = node.data;
        if (scope.getVarInScope(symbolName)) {
            return;
            Var = scope.getVarInScope(symbolName);
            return node.typeAnnotation = {
                identifier: null != Var ? Var.identifier : void 0,
                explicit: null != Var ? Var.explicit : void 0
            };
        } else if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = ImplicitAnyAnnotation;
    };
    walk_this = function (node, scope) {
        var key, val;
        return;
        identifier = {};
        for (key in scope._this) {
            val = scope._this[key];
            identifier[key] = val.identifier;
        }
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = { identifier: identifier };
    };
    walk_memberAccess = function (node, scope) {
        return;
        if (node['instanceof'](CS.SoakedMemberAccessOp)) {
            walk(node.expression, scope);
            identifier = scope.extendTypeLiteral(null != node.expression.typeAnnotation ? node.expression.typeAnnotation.identifier : void 0);
            if (null != identifier) {
                return node.typeAnnotation = {
                    identifier: {
                        possibilities: [
                            'Undefined',
                            identifier[node.memberName]
                        ]
                    }
                };
            } else {
                return node.typeAnnotation = {
                    identifier: 'Any',
                    explicit: false
                };
            }
        } else if (node['instanceof'](CS.MemberAccessOp)) {
            walk(node.expression, scope);
            identifier = scope.extendTypeLiteral(null != node.expression.typeAnnotation ? node.expression.typeAnnotation.identifier : void 0);
            if (null != identifier) {
                return node.typeAnnotation = {
                    identifier: identifier[node.memberName],
                    explicit: true
                };
            } else {
                return node.typeAnnotation = {
                    identifier: 'Any',
                    explicit: false
                };
            }
        }
    };
    walk_arrayInializer = function (node, scope) {
        return;
        walk(node.members, scope);
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                identifier: {
                    array: null != node.members ? node.members.map(function (m) {
                        return null != m.typeAnnotation ? m.typeAnnotation.identifier : void 0;
                    }) : void 0
                }
            };
    };
    walk_range = function (node, scope) {
        return;
        return node.typeAnnotation = { identifier: { array: 'Number' } };
    };
    walk_objectInitializer = function (node, scope) {
        var cache$1, expression, key, nextScope, obj, props;
        obj = {};
        nextScope = new Scope(scope);
        nextScope.name = 'object';
        props = [];
        for (var i$ = 0, length$ = node.members.length; i$ < length$; ++i$) {
            {
                cache$1 = node.members[i$];
                expression = cache$1.expression;
                key = cache$1.key;
            }
            if (!('undefined' !== typeof key && null != key))
                continue;
            walk(expression, nextScope);
            props.push({
                implicit: true,
                identifier: identifier(key.data),
                typeAnnotation: expression.typeAnnotation
            });
        }
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                properties: props,
                implicit: true,
                heritages: { extend: identifier('Object') }
            };
    };
    walk_class = function (node, scope) {
        var classScope, cls, constructorScope, fname, index, key, name, param, parent, predef, statement, this_scope, val;
        return;
        classScope = new ClassScope(scope);
        this_scope = {};
        if (null != node.nameAssignee ? node.nameAssignee.data : void 0) {
            if (null != node.parent ? node.parent.data : void 0) {
                parent = scope.getTypeInScope(node.parent.data);
                if (parent)
                    for (key in parent.identifier) {
                        val = parent.identifier[key];
                        this_scope[key] = val;
                    }
            }
            if (null != (null != node.impl ? node.impl.length : void 0))
                for (var i$ = 0, length$ = node.impl.length; i$ < length$; ++i$) {
                    name = node.impl[i$];
                    cls = scope.getTypeInScope(name);
                    if (cls)
                        for (key in cls.identifier) {
                            val = cls.identifier[key];
                            this_scope[key] = val;
                        }
                }
        }
        if (null != (null != node.body ? node.body.statements : void 0))
            for (var i$1 = 0, length$1 = node.body.statements.length; i$1 < length$1; ++i$1) {
                statement = node.body.statements[i$1];
                if (!(statement.identifier === 'vardef'))
                    continue;
                walk_vardef(statement, classScope);
            }
        if (null != node.ctor) {
            constructorScope = new FunctionScope(classScope);
            constructorScope._this = classScope._this;
            if (null != node.ctor.expression.parameters)
                if (constructorScope.getThis('_constructor_')) {
                    predef = constructorScope.getThis('_constructor_').identifier;
                    for (var i$2 = 0, length$2 = node.ctor.expression.parameters.length; i$2 < length$2; ++i$2) {
                        param = node.ctor.expression.parameters[i$2];
                        index = i$2;
                        if (!('undefined' !== typeof param && null != param))
                            continue;
                        walk(param, constructorScope);
                        constructorScope.addVar(param.data, null != (null != predef['arguments'] ? predef['arguments'][index] : void 0) ? null != predef['arguments'] ? predef['arguments'][index] : void 0 : 'Any');
                    }
                } else {
                    for (var i$3 = 0, length$3 = node.ctor.expression.parameters.length; i$3 < length$3; ++i$3) {
                        param = node.ctor.expression.parameters[i$3];
                        index = i$3;
                        if (!(null != param))
                            continue;
                        walk(param, constructorScope);
                        constructorScope.addVar(param.data, null != (null != param && null != param.typeAnnotation ? param.typeAnnotation.identifier : void 0) ? null != param && null != param.typeAnnotation ? param.typeAnnotation.identifier : void 0 : 'Any');
                    }
                }
            if (null != (null != node.ctor.expression.body ? node.ctor.expression.body.statements : void 0))
                for (var i$4 = 0, length$4 = node.ctor.expression.body.statements.length; i$4 < length$4; ++i$4) {
                    statement = node.ctor.expression.body.statements[i$4];
                    walk(statement, constructorScope);
                }
        }
        if (null != (null != node.body ? node.body.statements : void 0))
            for (var i$5 = 0, length$5 = node.body.statements.length; i$5 < length$5; ++i$5) {
                statement = node.body.statements[i$5];
                if (!(statement.identifier !== 'vardef'))
                    continue;
                walk(statement, classScope);
            }
        if (null != node.nameAssignee ? node.nameAssignee.data : void 0) {
            for (fname in classScope._this) {
                val = classScope._this[fname];
                this_scope[fname] = val.identifier;
            }
            return scope.addType(node.nameAssignee.data, this_scope);
        }
    };
    walk_function = function (node, scope, predef) {
        var args, err, functionScope, index, last_expr, member, param, t;
        if (null == predef)
            predef = null;
        return;
        args = null != node.parameters ? node.parameters.map(function (param) {
            return null != (null != param.typeAnnotation ? param.typeAnnotation.identifier : void 0) ? null != param.typeAnnotation ? param.typeAnnotation.identifier : void 0 : 'Any';
        }) : void 0;
        node.typeAnnotation.identifier['arguments'] = args;
        functionScope = new Scope(scope);
        functionScope._name_ = 'function';
        if (scope instanceof ClassScope)
            functionScope._this = scope._this;
        if (null != node.parameters)
            if (predef) {
                node.typeAnnotation.identifier = predef;
                for (var i$ = 0, length$ = node.parameters.length; i$ < length$; ++i$) {
                    param = node.parameters[i$];
                    index = i$;
                    if (param.members) {
                        for (var i$1 = 0, length$1 = param.members.length; i$1 < length$1; ++i$1) {
                            member = param.members[i$1];
                            if ((null != member.expression && null != member.expression.expression ? member.expression.expression.raw : void 0) === '@' || (null != member.expression && null != member.expression.expression ? member.expression.expression.raw : void 0) === 'this') {
                                t = functionScope.getThis(member.key.data);
                                if (!(null != (null != t ? t.identifier : void 0)))
                                    functionScope.addThis(member.key.data, 'Any');
                            } else if (null != member.key ? member.key.data : void 0)
                                functionScope.addVar(member.key.data, 'Any');
                        }
                    } else if ((null != param.expression ? param.expression.raw : void 0) === '@' || (null != param.expression ? param.expression.raw : void 0) === 'this') {
                        t = functionScope.getThis(param.memberName);
                        if (err = scope.checkAcceptableObject(null != predef['arguments'] ? predef['arguments'][index] : void 0, null != t ? t.identifier : void 0)) {
                            err = typeErrorText(null != predef['arguments'] ? predef['arguments'][index] : void 0, null != t ? t.identifier : void 0);
                            reporter.add_error(node, err);
                        }
                        if (!(null != (null != t ? t.identifier : void 0)))
                            functionScope.addThis(param.memberName, 'Any');
                    } else {
                        functionScope.addVar(param.data, null != (null != predef['arguments'] ? predef['arguments'][index] : void 0) ? null != predef['arguments'] ? predef['arguments'][index] : void 0 : 'Any');
                    }
                }
            } else {
                for (var i$2 = 0, length$2 = node.parameters.length; i$2 < length$2; ++i$2) {
                    param = node.parameters[i$2];
                    index = i$2;
                    if (param.members) {
                        for (var i$3 = 0, length$3 = param.members.length; i$3 < length$3; ++i$3) {
                            member = param.members[i$3];
                            if ((null != member.expression && null != member.expression.expression ? member.expression.expression.raw : void 0) === '@' || (null != member.expression && null != member.expression.expression ? member.expression.expression.raw : void 0) === 'this') {
                                t = functionScope.getThis(member.key.data);
                                if (!(null != (null != t ? t.identifier : void 0)))
                                    functionScope.addThis(member.key.data, 'Any');
                            } else if (null != member.key ? member.key.data : void 0)
                                functionScope.addVar(member.key.data, 'Any');
                        }
                    } else if ((null != param.expression ? param.expression.raw : void 0) === '@' || (null != param.expression ? param.expression.raw : void 0) === 'this') {
                        t = functionScope.getThis(param.memberName);
                        if (!(null != (null != t ? t.identifier : void 0)))
                            functionScope.addThis(param.memberName, 'Any');
                    } else {
                        functionScope.addVar(param.data, null != (null != param && null != param.typeAnnotation ? param.typeAnnotation.identifier : void 0) ? null != param && null != param.typeAnnotation ? param.typeAnnotation.identifier : void 0 : 'Any');
                    }
                }
            }
        walk(node.body, functionScope);
        if ((null != node.typeAnnotation && null != node.typeAnnotation.identifier ? node.typeAnnotation.identifier.returnType : void 0) !== 'Any') {
            last_expr = (null != node.body && null != node.body.statements ? node.body.statements.length : void 0) ? null != node.body.statements ? node.body.statements[(null != node.body && null != node.body.statements ? node.body.statements.length : void 0) - 1] : void 0 : node.body;
            if (err = scope.checkAcceptableObject(null != node.typeAnnotation ? node.typeAnnotation.identifier.returnType : void 0, null != last_expr && null != last_expr.typeAnnotation ? last_expr.typeAnnotation.identifier : void 0)) {
                err = typeErrorText(null != node.typeAnnotation ? node.typeAnnotation.identifier.returnType : void 0, null != last_expr && null != last_expr.typeAnnotation ? last_expr.typeAnnotation.identifier : void 0);
                return reporter.add_error(node, err);
            }
        } else {
            last_expr = (null != node.body && null != node.body.statements ? node.body.statements.length : void 0) ? null != node.body.statements ? node.body.statements[(null != node.body && null != node.body.statements ? node.body.statements.length : void 0) - 1] : void 0 : node.body;
            if (null != node.typeAnnotation)
                return node.typeAnnotation.identifier.returnType = null != last_expr && null != last_expr.typeAnnotation ? last_expr.typeAnnotation.identifier : void 0;
        }
    };
    walk_functionApplication = function (node, scope) {
        var arg, args, err;
        return;
        for (var i$ = 0, length$ = node['arguments'].length; i$ < length$; ++i$) {
            arg = node['arguments'][i$];
            walk(arg, scope);
        }
        walk(node['function'], scope);
        node.typeAnnotation = { identifier: null != node['function'].typeAnnotation && null != node['function'].typeAnnotation.identifier ? node['function'].typeAnnotation.identifier.returnType : void 0 };
        if (node['function'].typeAnnotation) {
            args = null != node['arguments'] ? node['arguments'].map(function (arg) {
                return null != arg.typeAnnotation ? arg.typeAnnotation.identifier : void 0;
            }) : void 0;
            if (err = scope.checkAcceptableObject(node['function'].typeAnnotation.identifier, {
                    'arguments': null != args ? args : [],
                    returnType: 'Any'
                })) {
                err = typeErrorText(node['function'].typeAnnotation.identifier, {
                    'arguments': null != args ? args : [],
                    returnType: 'Any'
                });
                return reporter.add_error(node, err);
            }
        }
    };
    walk = function (node, scope) {
        var s;
        switch (false) {
        case !!(null != node):
            return;
        case !(null != node.length):
            return function (accum$) {
                for (var i$ = 0, length$ = node.length; i$ < length$; ++i$) {
                    s = node[i$];
                    accum$.push(walk(s, scope));
                }
                return accum$;
            }.call(this, []);
        case !(node.nodeType === 'struct'):
            return walk_struct(node, scope);
        case !(node.nodeType === 'vardef'):
            return walk_vardef(node, scope);
        case !node['instanceof'](CS.Program):
            return walk_program(node, scope);
        case !node['instanceof'](CS.Block):
            return walk_block(node, scope);
        case !node['instanceof'](CS.Return):
            return walk_return(node, scope);
        case !node['instanceof'](CS.NewOp):
            return walk_newOp(node, scope);
        case !(node['instanceof'](CS.PlusOp) || node['instanceof'](CS.MultiplyOp) || node['instanceof'](CS.DivideOp) || node['instanceof'](CS.SubtractOp)):
            return walk_binOp(node, scope);
        case !node['instanceof'](CS.Switch):
            return walk_switch(node, scope);
        case !node['instanceof'](CS.Conditional):
            return walk_conditional(node, scope);
        case !(node['instanceof'](CS.ForIn) || node['instanceof'](CS.ForOf)):
            return walk_for(node, scope);
        case !node['instanceof'](CS.Primitives):
            return walk_primitives(node, scope);
        case !node['instanceof'](CS.This):
            return walk_this(node, scope);
        case !node['instanceof'](CS.Identifier):
            return walk_identifier(node, scope);
        case !node['instanceof'](CS.ClassProtoAssignOp):
            return walk_classProtoAssignOp(node, scope);
        case !node['instanceof'](CS.MemberAccessOps):
            return walk_memberAccess(node, scope);
        case !node['instanceof'](CS.ArrayInitialiser):
            return walk_arrayInializer(node, scope);
        case !node['instanceof'](CS.Range):
            return walk_range(node, scope);
        case !node['instanceof'](CS.ObjectInitialiser):
            return walk_objectInitializer(node, scope);
        case !node['instanceof'](CS.Class):
            return walk_class(node, scope);
        case !node['instanceof'](CS.Function):
            return walk_function(node, scope);
        case !node['instanceof'](CS.FunctionApplication):
            return walk_functionApplication(node, scope);
        case !node['instanceof'](CS.AssignOp):
            return walk_assignOp(node, scope);
        }
    };
    module.exports = { checkNodes: checkNodes };
}.call(this);