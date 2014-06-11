void function () {
    var _, addValuesByInitializer, cache$, cache$1, cache$2, cache$3, checkNodes, checkType, checkTypeAnnotation, ClassScope, CS, debug, extendType, FunctionScope, ImplicitAny, initializeGlobalTypes, reporter, resolveType, Scope, walk, walkArrayInializer, walkAssignOp, walkBinOp, walkBlock, walkBool, walkClass, walkClassProtoAssignOp, walkCompoundAssignOp, walkConditional, walkDynamicMemberAccessOp, walkDynamicProtoMemberAccessOp, walkFloat, walkFor, walkFunction, walkFunctionApplication, walkIdentifier, walkInt, walkMemberAccess, walkNewOp, walkNull, walkNumbers, walkObjectInitializer, walkOfOp, walkPrimitives, walkProgram, walkProtoMemberAccessOp, walkRange, walkReturn, walkString, walkStruct, walkSwitch, walkThis, walkUndefined, walkVardef;
    debug = require('./helpers').debug;
    reporter = require('./reporter');
    CS = require('./nodes');
    _ = require('lodash');
    cache$ = require('./type-checker');
    checkType = cache$.checkType;
    checkTypeAnnotation = cache$.checkTypeAnnotation;
    cache$1 = require('./type-resolver');
    resolveType = cache$1.resolveType;
    extendType = cache$1.extendType;
    cache$2 = require('./type-scope');
    Scope = cache$2.Scope;
    ClassScope = cache$2.ClassScope;
    FunctionScope = cache$2.FunctionScope;
    cache$3 = require('./types');
    initializeGlobalTypes = cache$3.initializeGlobalTypes;
    ImplicitAny = cache$3.ImplicitAny;
    checkNodes = function (cs_ast) {
        var g, root;
        g = 'undefined' !== typeof window && null != window ? window : global;
        if (!(null != (null != cs_ast.body ? cs_ast.body.statements : void 0)))
            return;
        if (g._root_) {
            root = g._root_;
        } else {
            g._root_ = root = new Scope();
            root.name = 'root';
            initializeGlobalTypes(root);
        }
        walk(cs_ast, root);
        return root;
    };
    walkStruct = function (node, scope) {
        scope.addStructType(_.cloneDeep(node));
        return node.typeAnnotation = ImplicitAny;
    };
    walkVardef = function (node, scope) {
        var symbol, val;
        symbol = node.name.identifier.typeRef;
        if (scope instanceof ClassScope) {
            if (symbol === 'constructor')
                symbol = '_constructor_';
            if (!(val = scope.getThis(symbol))) {
                if (!node.isStatic)
                    return scope.addThis({
                        nodeType: 'variable',
                        identifier: {
                            typeRef: symbol,
                            typeArguments: null != node.name && null != node.name.identifier ? node.name.identifier.typeArguments : void 0
                        },
                        typeAnnotation: node.expr
                    });
            } else if (val.typeAnnotation.implicit && val.typeAnnotation.identifier.typeRef === 'Any') {
                return val.typeAnnotation = node.expr;
            } else {
                return reporter.add_error(node, 'double bind: ' + symbol);
            }
        } else if (!(val = scope.getVar(symbol))) {
            return scope.addVar({
                nodeType: 'variable',
                identifier: {
                    typeRef: symbol,
                    typeArguments: null != node.name && null != node.name.identifier ? node.name.identifier.typeArguments : void 0
                },
                typeAnnotation: node.expr
            });
        } else if (val.typeAnnotation.implicit && val.typeAnnotation.identifier.typeRef === 'Any') {
            return val.typeAnnotation = node.expr;
        } else {
            return reporter.add_error(node, 'double bind: ' + symbol);
        }
    };
    walkProgram = function (node, scope) {
        walk(node.body.statements, scope);
        return node.typeAnnotation = { identifier: 'Program' };
    };
    walkBlock = function (node, scope) {
        var cache$4, lastAnn, returnables;
        walk(node.statements, scope);
        returnables = scope.getReturnables();
        if (null != (cache$4 = _.last(node.statements)) ? cache$4.typeAnnotation : void 0) {
            lastAnn = _.last(node.statements).typeAnnotation;
            returnables.push(lastAnn);
        }
        return node.typeAnnotation = scope.getHighestCommonType(returnables);
    };
    walkReturn = function (node, scope) {
        walk(node.expression, scope);
        if (null != (null != node.expression ? node.expression.typeAnnotation : void 0)) {
            node.typeAnnotation = node.expression.typeAnnotation;
            return scope.addReturnable(node.typeAnnotation);
        }
    };
    walkBinOp = function (node, scope) {
        var cache$4, leftAnnotation, leftRef, rightAnnotation, rightRef;
        walk(node.left, scope);
        walk(node.right, scope);
        cache$4 = [
            node.left.typeAnnotation,
            node.right.typeAnnotation
        ].map(function (node) {
            if (!(null != node))
                return ImplicitAny;
            if (node.nodeType === 'identifier') {
                return scope.getTypeByIdentifier(node);
            } else if (node.nodeType === 'primitiveIdentifier') {
                return node;
            } else if (node.nodeType === 'members') {
                return node;
            } else if (node.nodeType === 'functionType') {
                return node;
            } else {
                throw (null != node ? node.nodeType : void 0) + ' is not registered nodeType';
            }
        });
        leftAnnotation = cache$4[0];
        rightAnnotation = cache$4[1];
        leftRef = null != leftAnnotation && null != leftAnnotation.identifier ? leftAnnotation.identifier.typeRef : void 0;
        rightRef = null != rightAnnotation && null != rightAnnotation.identifier ? rightAnnotation.identifier.typeRef : void 0;
        if (leftRef && rightRef) {
            if (leftRef === 'String' || rightRef === 'String') {
                return node.typeAnnotation = {
                    implicit: true,
                    nodeType: 'primitiveIdentifier',
                    identifier: { typeRef: 'String' }
                };
            } else if (leftRef === 'Int' && rightRef === 'Int') {
                return node.typeAnnotation = {
                    implicit: true,
                    nodeType: 'primitiveIdentifier',
                    identifier: { typeRef: 'Int' }
                };
            } else if ((leftRef === 'Int' || leftRef === 'Float') && (rightRef === 'Int' || rightRef === 'Float')) {
                return node.typeAnnotation = {
                    implicit: true,
                    nodeType: 'primitiveIdentifier',
                    identifier: { typeRef: 'Float' }
                };
            } else if ((leftRef === 'Int' || leftRef === 'Float' || leftRef === 'Number') && (rightRef === 'Int' || rightRef === 'Float' || rightRef === 'Number')) {
                return node.typeAnnotation = {
                    implicit: true,
                    nodeType: 'primitiveIdentifier',
                    identifier: { typeRef: 'Number' }
                };
            } else if (leftRef === rightRef && rightRef === 'Any') {
                if (node instanceof CS.PlusOp) {
                    return node.typeAnnotation = {
                        implicit: true,
                        nodeType: 'primitiveIdentifier',
                        identifier: { typeRef: 'Any' }
                    };
                } else {
                    return node.typeAnnotation = {
                        implicit: true,
                        nodeType: 'primitiveIdentifier',
                        identifier: { typeRef: 'Number' }
                    };
                }
            } else if (null != node.typeAnnotation)
                return node.typeAnnotation;
            else
                return node.typeAnnotation = ImplicitAny;
        } else {
            return node.typeAnnotation = ImplicitAny;
        }
    };
    walkConditional = function (node, scope) {
        var alternateAnnotation, consequentAnnotation, parentType, ret;
        walk(node.condition, scope);
        if (node.consequent)
            walk(node.consequent, scope);
        if (null != node.alternate)
            walk(node.alternate, scope);
        consequentAnnotation = null != node.consequent ? node.consequent.typeAnnotation : void 0;
        alternateAnnotation = null != node.alternate ? node.alternate.typeAnnotation : void 0;
        if (consequentAnnotation && alternateAnnotation) {
            parentType = scope.getHighestCommonType([
                consequentAnnotation,
                alternateAnnotation
            ]);
            return node.typeAnnotation = parentType;
        } else if (consequentAnnotation && !alternateAnnotation) {
            ret = _.cloneDeep(consequentAnnotation);
            if (null != ret.identifier)
                ret.identifier.nullable = true;
            return node.typeAnnotation = ret;
        } else {
            return node.typeAnnotation = ImplicitAny;
        }
    };
    walkSwitch = function (node, scope) {
        var ann, c, canditates, cond;
        if (node.expression)
            walk(node.expression, scope);
        canditates = [];
        for (var i$ = 0, length$ = node.cases.length; i$ < length$; ++i$) {
            c = node.cases[i$];
            for (var i$1 = 0, length$1 = c.conditions.length; i$1 < length$1; ++i$1) {
                cond = c.conditions[i$1];
                walk(c, scope);
            }
            if (c.consequent) {
                walk(c.consequent, scope);
                canditates.push(c.consequent.typeAnnotation);
            }
        }
        if (node.alternate) {
            walk(node.alternate, scope);
            if (null != (null != c.alternate ? c.alternate.typeAnnotation : void 0))
                canditates.push(c.alternate.typeAnnotation);
        }
        ann = scope.getHighestCommonType(canditates);
        if (null != ann) {
            if (null != ann.identifier)
                ann.identifier.nullable = !(null != node.alternate);
            return node.typeAnnotation = null != ann ? ann : ImplicitAny;
        } else {
            return node.typeAnnotation = ImplicitAny;
        }
    };
    walkNewOp = function (node, scope) {
        var ann, arg, args, ctor, ctorAnnotation, givenArgs, left, n, right;
        ctor = null != (null != node.ctor ? node.ctor.ctor : void 0) ? null != node.ctor ? node.ctor.ctor : void 0 : node.ctor;
        args = null != (null != node.ctor ? node.ctor['arguments'] : void 0) ? null != node.ctor ? node.ctor['arguments'] : void 0 : node['arguments'];
        ann = scope.getTypeInScope(ctor.data);
        if (null != ctor.typeArguments ? ctor.typeArguments.length : void 0) {
            givenArgs = ctor.typeArguments;
            ann = extendType(scope, _.cloneDeep(ann), givenArgs);
        }
        if (ann)
            ctorAnnotation = _.find(ann.properties, function (i) {
                return (null != i.identifier ? i.identifier.typeRef : void 0) === '_constructor_';
            });
        for (var i$ = 0, length$ = args.length; i$ < length$; ++i$) {
            arg = args[i$];
            n = i$;
            walk(arg, scope);
            left = null != ctorAnnotation && null != ctorAnnotation.typeAnnotation && null != ctorAnnotation.typeAnnotation['arguments'] ? ctorAnnotation.typeAnnotation['arguments'][n] : void 0;
            right = 'undefined' !== typeof arg && null != arg ? arg.typeAnnotation : void 0;
            if (left && right)
                checkTypeAnnotation(scope, node, left, right);
        }
        return node.typeAnnotation = null != ann ? ann : ImplicitAny;
    };
    walkOfOp = function (node, scope) {
        if (null != node.typeAnnotation)
            node.typeAnnotation;
        else
            node.typeAnnotation = ImplicitAny;
    };
    walkFor = function (node, scope) {
        var bodyType, preAnnotation, targetType;
        walk(node.target, scope);
        if (null != node.valAssignee) {
            preAnnotation = null != node && null != node.valAssignee ? node.valAssignee.typeAnnotation : void 0;
            walk(node.valAssignee, scope);
            if (preAnnotation) {
                node.valAssignee.typeAnnotation = preAnnotation;
            } else if (null != node.target.typeAnnotation && null != node.target.typeAnnotation.identifier ? node.target.typeAnnotation.identifier.isArray : void 0) {
                targetType = _.cloneDeep(node.target.typeAnnotation);
                delete targetType.identifier.isArray;
                node.valAssignee.typeAnnotation = targetType;
            } else {
                node.valAssignee.typeAnnotation = ImplicitAny;
            }
            scope.addVar({
                nodeType: 'variable',
                identifier: { typeRef: node.valAssignee.data },
                typeAnnotation: node.valAssignee.typeAnnotation
            });
        }
        if (null != node.keyAssignee)
            if (node instanceof CS.ForIn) {
                node.keyAssignee.typeAnnotation = {
                    nodeType: 'identifier',
                    identifier: { typeRef: 'Int' }
                };
                scope.addVar({
                    nodeType: 'variable',
                    identifier: { typeRef: node.keyAssignee.data },
                    typeAnnotation: {
                        nodeType: 'identifier',
                        identifier: { typeRef: 'Int' }
                    }
                });
            } else if (node instanceof CS.ForOf) {
                node.keyAssignee.typeAnnotation = {
                    nodeType: 'identifier',
                    identifier: { typeRef: 'String' }
                };
                scope.addVar({
                    nodeType: 'variable',
                    identifier: { typeRef: node.keyAssignee.data },
                    typeAnnotation: {
                        nodeType: 'identifier',
                        identifier: { typeRef: 'String' }
                    }
                });
            }
        walk(node.body, scope);
        if (null != node.body)
            bodyType = _.cloneDeep(node.body.typeAnnotation);
        if (null != bodyType ? bodyType.identifier : void 0) {
            if (null != node.body) {
                bodyType.identifier.isArray = true;
                return node.typeAnnotation = bodyType;
            } else {
                return node.typeAnnotation = ImplicitAny;
            }
        } else {
            return node.typeAnnotation = ImplicitAny;
        }
    };
    walkClassProtoAssignOp = function (node, scope) {
        var annotation, cache$4, left, right, symbol;
        left = node.assignee;
        right = node.expression;
        symbol = left.data;
        if (right['instanceof'](CS.Function) && scope.getThis(symbol)) {
            annotation = null != (cache$4 = scope.getThis(symbol)) ? cache$4.typeAnnotation : void 0;
            if (null != annotation) {
                left.typeAnnotation = annotation;
                scope.addThis({
                    nodeType: 'variable',
                    identifier: { typeRef: symbol },
                    typeAnnotation: annotation
                });
            }
            return walkFunction(right, scope, annotation);
        } else {
            annotation = {
                nodeType: 'variable',
                identifier: { typeRef: symbol },
                typeAnnotation: null
            };
            scope.addThis(annotation);
            walk(right, scope);
            if (right.typeAnnotation)
                return annotation.typeAnnotation = right.typeAnnotation;
        }
    };
    walkCompoundAssignOp = function (node, scope) {
        if (null != node.typeAnnotation)
            node.typeAnnotation;
        else
            node.typeAnnotation = ImplicitAny;
    };
    walkAssignOp = function (node, scope) {
        var left, lprop, member, n, preAnnotation, right, rprop, rpropAnn, symbol, v;
        left = node.assignee;
        right = node.expression;
        symbol = left.data;
        preAnnotation = left.typeAnnotation;
        walk(left, scope);
        if (right['instanceof'](CS.Function) && scope.getVarInScope(symbol)) {
            v = scope.getVarInScope(symbol);
            walkFunction(right, scope, v.typeAnnotation);
        } else if (right['instanceof'](CS.Function) && preAnnotation) {
            walkFunction(right, scope, preAnnotation);
        } else {
            walk(right, scope);
        }
        if (left instanceof CS.ArrayInitialiser) {
            if ((null != right.typeAnnotation && null != right.typeAnnotation.identifier ? right.typeAnnotation.identifier.typeRef : void 0) === 'Any') {
                '';
            } else if (right instanceof CS.ArrayInitialiser) {
                for (var i$ = 0, length$ = left.members.length; i$ < length$; ++i$) {
                    lprop = left.members[i$];
                    n = i$;
                    rprop = null != right && null != right.members ? right.members[n] : void 0;
                    if (lprop && rprop)
                        checkType(scope, node, lprop, rprop);
                }
            } else if (null != right.typeAnnotation && null != right.typeAnnotation.identifier ? right.typeAnnotation.identifier.isArray : void 0) {
                for (var i$1 = 0, length$1 = left.members.length; i$1 < length$1; ++i$1) {
                    lprop = left.members[i$1];
                    n = i$1;
                    rpropAnn = _.cloneDeep(right.typeAnnotation);
                    delete rpropAnn.identifier.isArray;
                    if (lprop && rpropAnn)
                        checkTypeAnnotation(scope, node, lprop.typeAnnotation, rpropAnn);
                }
            }
            return function (accum$) {
                for (var i$2 = 0, length$2 = left.members.length; i$2 < length$2; ++i$2) {
                    member = left.members[i$2];
                    symbol = member.data;
                    accum$.push(!scope.getVarInScope(symbol) ? scope.addVar({
                        nodeType: 'variable',
                        identifier: { typeRef: symbol },
                        typeAnnotation: member.typeAnnotation
                    }) : void 0);
                }
                return accum$;
            }.call(this, []);
        } else if (left instanceof CS.ObjectInitialiser) {
            if ((null != right.typeAnnotation && null != right.typeAnnotation.identifier ? right.typeAnnotation.identifier.typeRef : void 0) === 'Any') {
                '';
            } else if (!checkType(scope, node, left, right))
                return;
            return function (accum$1) {
                for (var i$3 = 0, length$3 = left.members.length; i$3 < length$3; ++i$3) {
                    member = left.members[i$3];
                    symbol = member.key.data;
                    accum$1.push(!scope.getVarInScope(symbol) ? scope.addVar({
                        nodeType: 'variable',
                        identifier: { typeRef: symbol },
                        typeAnnotation: member.typeAnnotation
                    }) : void 0);
                }
                return accum$1;
            }.call(this, []);
        } else if (left['instanceof'](CS.MemberAccessOp)) {
            if (!checkType(scope, node, left, right))
                return;
        } else if (left['instanceof'](CS.Identifier)) {
            if (scope.getVarInScope(symbol) && preAnnotation)
                return reporter.add_error(node, 'double bind: ' + symbol);
            if (null != left.typeAnnotation && null != right.typeAnnotation)
                if (null != (null != left.typeAnnotation ? left.typeAnnotation.properties : void 0)) {
                    if (!checkType(scope, node, left, right))
                        return;
                } else if (!checkType(scope, node, left, right))
                    return;
            if (null != preAnnotation) {
                return scope.addVar({
                    nodeType: 'variable',
                    identifier: { typeRef: symbol },
                    typeAnnotation: preAnnotation
                });
            } else if (null != right.typeAnnotation && !right.typeAnnotation.implicit && (null != left ? left.typeAnnotation.implicit : void 0)) {
                left.typeAnnotation = right.typeAnnotation;
                return scope.addVar({
                    nodeType: 'variable',
                    identifier: { typeRef: symbol },
                    typeAnnotation: right.typeAnnotation
                });
            } else {
                scope.addVar({
                    nodeType: 'variable',
                    identifier: { typeRef: symbol },
                    typeAnnotation: ImplicitAny
                });
                if (null != left.typeAnnotation)
                    return left.typeAnnotation;
                else
                    return left.typeAnnotation = ImplicitAny;
            }
        } else {
            return;
            throw 'unexpected node:' + (null != left ? left.className : void 0);
        }
    };
    walkPrimitives = function (node, scope) {
        switch (false) {
        case !node['instanceof'](CS.String):
            return walkString(node, scope);
        case !node['instanceof'](CS.Bool):
            return walkBool(node, scope);
        case !node['instanceof'](CS.Int):
            return walkInt(node, scope);
        case !node['instanceof'](CS.Float):
            return walkFloat(node, scope);
        case !node['instanceof'](CS.Numbers):
            return walkNumbers(node, scope);
        case !node['instanceof'](CS.Null):
            return walkNull(node, scope);
        case !node['instanceof'](CS.Undefined):
            return walkUndefined(node, scope);
        }
    };
    walkUndefined = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                implicit: true,
                nodeType: 'identifier',
                identifier: { typeRef: 'Undefined' }
            };
    };
    walkNull = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                implicit: true,
                nodeType: 'identifier',
                identifier: { typeRef: 'Null' }
            };
    };
    walkString = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                implicit: true,
                nodeType: 'identifier',
                identifier: { typeRef: 'String' }
            };
    };
    walkInt = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                nodeType: 'identifier',
                implicit: true,
                identifier: { typeRef: 'Int' }
            };
    };
    walkBool = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                nodeType: 'identifier',
                implicit: true,
                identifier: { typeRef: 'Boolean' }
            };
    };
    walkFloat = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                nodeType: 'identifier',
                implicit: true,
                identifier: { typeRef: 'Float' }
            };
    };
    walkNumbers = function (node, scope) {
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                nodeType: 'identifier',
                implicit: true,
                identifier: { typeRef: 'Number' }
            };
    };
    walkIdentifier = function (node, scope) {
        var cache$4, typeAnnotation, typeName;
        typeName = node.data;
        if (scope.getVarInScope(typeName)) {
            typeAnnotation = null != (cache$4 = scope.getVarInScope(typeName)) ? cache$4.typeAnnotation : void 0;
            return node.typeAnnotation = null != typeAnnotation ? typeAnnotation : ImplicitAny;
        } else if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = ImplicitAny;
    };
    walkThis = function (node, scope) {
        return node.typeAnnotation = {
            nodeType: 'members',
            implicit: true,
            identifier: { typeRef: '[this]' },
            properties: scope._this
        };
    };
    walkDynamicMemberAccessOp = function (node, scope) {
        if (null != node.typeAnnotation)
            node.typeAnnotation;
        else
            node.typeAnnotation = ImplicitAny;
    };
    walkDynamicProtoMemberAccessOp = function (node, scope) {
        if (null != node.typeAnnotation)
            node.typeAnnotation;
        else
            node.typeAnnotation = ImplicitAny;
    };
    walkProtoMemberAccessOp = function (node, scope) {
        if (null != node.typeAnnotation)
            node.typeAnnotation;
        else
            node.typeAnnotation = ImplicitAny;
    };
    walkMemberAccess = function (node, scope) {
        var member, type;
        if (node['instanceof'](CS.MemberAccessOp))
            walk(node.expression, scope);
        type = scope.getTypeByIdentifier(node.expression.typeAnnotation);
        if (type) {
            member = _.find(type.properties, function (prop) {
                return (null != prop.identifier ? prop.identifier.typeRef : void 0) === node.memberName;
            });
            return node.typeAnnotation = null != (null != member ? member.typeAnnotation : void 0) ? null != member ? member.typeAnnotation : void 0 : ImplicitAny;
        } else if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = ImplicitAny;
    };
    walkArrayInializer = function (node, scope) {
        var ann, member;
        for (var i$ = 0, length$ = node.members.length; i$ < length$; ++i$) {
            member = node.members[i$];
            walk(member, scope);
        }
        ann = scope.getHighestCommonType(node.members.map(function (m) {
            return m.typeAnnotation;
        }));
        if (null != (null != ann ? ann.identifier : void 0))
            ann.identifier.isArray = true;
        return node.typeAnnotation = ann;
    };
    walkRange = function (node, scope) {
        return node.typeAnnotation = {
            nodeType: 'identifier',
            implicit: true,
            identifier: {
                typeRef: 'Int',
                isArray: true
            }
        };
    };
    walkObjectInitializer = function (node, scope) {
        var cache$4, expression, key, nextScope, obj, props;
        obj = {};
        nextScope = new Scope(scope);
        nextScope.name = 'object';
        props = [];
        for (var i$ = 0, length$ = node.members.length; i$ < length$; ++i$) {
            {
                cache$4 = node.members[i$];
                expression = cache$4.expression;
                key = cache$4.key;
            }
            if (!('undefined' !== typeof key && null != key))
                continue;
            walk(expression, nextScope);
            props.push({
                implicit: true,
                identifier: { typeRef: key.data },
                nodeType: 'identifier',
                typeAnnotation: expression.typeAnnotation
            });
        }
        if (null != node.typeAnnotation)
            return node.typeAnnotation;
        else
            return node.typeAnnotation = {
                properties: props,
                nodeType: 'members',
                implicit: true,
                identifier: { typeRef: '[object]' }
            };
    };
    walkClass = function (node, scope) {
        var arg, classScope, impl, parentAnnotation, statement, staticAnn, symbol;
        classScope = new ClassScope(scope);
        symbol = null != (null != node.nameAssignee ? node.nameAssignee.data : void 0) ? null != node.nameAssignee ? node.nameAssignee.data : void 0 : '_class' + _.uniqueId();
        staticAnn = {
            properties: [],
            nodeType: 'members',
            implicit: true,
            identifier: { typeRef: symbol }
        };
        classScope.name = symbol;
        if (null != node.typeArguments ? node.typeArguments.length : void 0)
            for (var i$ = 0, length$ = node.typeArguments.length; i$ < length$; ++i$) {
                arg = node.typeArguments[i$];
                classScope.addType({
                    nodeType: 'identifier',
                    identifier: { typeRef: arg.identifier.typeRef }
                });
            }
        if (null != node.impl ? node.impl.length : void 0)
            for (var i$1 = 0, length$1 = node.impl.length; i$1 < length$1; ++i$1) {
                impl = node.impl[i$1];
                parentAnnotation = scope.getTypeInScope(impl.identifier.typeRef);
                if (parentAnnotation)
                    parentAnnotation.properties.map(function (prop) {
                        return classScope.addThis(_.cloneDeep(prop));
                    });
            }
        if (null != node.parent) {
            parentAnnotation = scope.getTypeInScope(node.parent.data);
            if (parentAnnotation)
                parentAnnotation.properties.map(function (prop) {
                    return classScope.addThis(_.cloneDeep(prop));
                });
        }
        if (null != (null != node.body ? node.body.statements : void 0))
            for (var i$2 = 0, length$2 = node.body.statements.length; i$2 < length$2; ++i$2) {
                statement = node.body.statements[i$2];
                if (!(statement.nodeType === 'vardef'))
                    continue;
                if (statement.isStatic) {
                    staticAnn.properties.push({
                        nodeType: 'variable',
                        identifier: _.cloneDeep(statement.name.identifier),
                        typeAnnotation: _.cloneDeep(statement.expr)
                    });
                } else {
                    walkVardef(statement, classScope);
                }
            }
        scope.addVar({
            nodeType: 'variable',
            identifier: { typeRef: symbol },
            typeAnnotation: staticAnn
        });
        scope.addType({
            nodeType: 'members',
            newable: true,
            identifier: {
                typeRef: symbol,
                typeArguments: null != node.typeArguments ? node.typeArguments : []
            },
            properties: _.map(_.cloneDeep(classScope._this), function (prop) {
                prop.nodeType = 'identifier';
                return prop;
            })
        });
        if (null != node.ctor)
            walkFunction(node.ctor.expression, classScope, classScope.getConstructorType());
        if (node.body instanceof CS.Block)
            return function (accum$) {
                for (var i$3 = 0, length$3 = node.body.statements.length; i$3 < length$3; ++i$3) {
                    statement = node.body.statements[i$3];
                    if (!(statement.nodeType !== 'vardef'))
                        continue;
                    accum$.push(walk(statement, classScope));
                }
                return accum$;
            }.call(this, []);
    };
    addValuesByInitializer = function (scope, initializerNode, preAnnotation) {
        var member, symbol;
        if (null == preAnnotation)
            preAnnotation = null;
        if (initializerNode instanceof CS.ArrayInitialiser) {
            return function (accum$) {
                for (var i$ = 0, length$ = initializerNode.members.length; i$ < length$; ++i$) {
                    member = initializerNode.members[i$];
                    symbol = member.data;
                    accum$.push(!scope.getVar(symbol) ? scope.addVar({
                        nodeType: 'variable',
                        identifier: { typeRef: symbol },
                        typeAnnotation: null != member.typeAnnotation ? member.typeAnnotation : ImplicitAny
                    }) : void 0);
                }
                return accum$;
            }.call(this, []);
        } else if (initializerNode instanceof CS.ObjectInitialiser) {
            return function (accum$1) {
                for (var i$1 = 0, length$1 = initializerNode.members.length; i$1 < length$1; ++i$1) {
                    member = initializerNode.members[i$1];
                    symbol = member.key.data;
                    accum$1.push(!scope.getVar(symbol) ? scope.addVar({
                        nodeType: 'variable',
                        identifier: { typeRef: symbol },
                        typeAnnotation: null != member.typeAnnotation ? member.typeAnnotation : ImplicitAny
                    }) : void 0);
                }
                return accum$1;
            }.call(this, []);
        }
    };
    walkFunction = function (node, scope, preAnnotation) {
        var annotation, functionScope, left, right;
        if (null == preAnnotation)
            preAnnotation = null;
        functionScope = new Scope(scope);
        if (scope instanceof ClassScope)
            functionScope._this = scope._this;
        if (null != preAnnotation) {
            if (null != node.typeAnnotation) {
                annotation = _.cloneDeep(node.typeAnnotation);
                if (null != annotation.returnType)
                    annotation.returnType;
                else
                    annotation.returnType = ImplicitAny;
                if (null != annotation['arguments'])
                    annotation['arguments'];
                else
                    annotation['arguments'] = null != annotation['arguments'] ? annotation['arguments'].map(function (arg) {
                        return null != arg ? arg : ImplicitAny;
                    }) : void 0;
                if (null != annotation['arguments'])
                    annotation['arguments'];
                else
                    annotation['arguments'] = [];
                if (!checkTypeAnnotation(scope, node, annotation, preAnnotation))
                    return;
            }
            node.typeAnnotation = preAnnotation;
            if (null != node.parameters)
                node.parameters.map(function (param, n) {
                    var member, memberAnn, preAnn, t, type;
                    if (null != param.typeAnnotation)
                        if (!checkTypeAnnotation(scope, node, preAnnotation['arguments'][n], param.typeAnnotation))
                            return;
                    if (param instanceof CS.MemberAccessOp)
                        walk(param, functionScope);
                    if (null != param.typeAnnotation)
                        param.typeAnnotation;
                    else
                        param.typeAnnotation = null != (null != preAnnotation['arguments'] ? preAnnotation['arguments'][n] : void 0) ? null != preAnnotation['arguments'] ? preAnnotation['arguments'][n] : void 0 : ImplicitAny;
                    if (param instanceof CS.Identifier) {
                        return functionScope.addVar({
                            nodeType: 'variable',
                            identifier: { typeRef: param.data },
                            typeAnnotation: param.typeAnnotation
                        });
                    } else if (param instanceof CS.ArrayInitialiser) {
                        preAnn = null != preAnnotation['arguments'] ? preAnnotation['arguments'][n] : void 0;
                        if (preAnn)
                            for (var i$ = 0, length$ = param.members.length; i$ < length$; ++i$) {
                                member = param.members[i$];
                                type = _.cloneDeep(resolveType(scope, preAnn));
                                type.identifier.isArRay = false;
                                if (type.nodeType === 'primitiveIdentifier') {
                                    t = _.cloneDeep(preAnn);
                                    delete t.identifier.isArray;
                                    member.typeAnnotation = t;
                                } else {
                                    member.typeAnnotation = null != type ? type : ImplicitAny;
                                }
                            }
                        return addValuesByInitializer(scope, param);
                    } else if (param instanceof CS.ObjectInitialiser) {
                        preAnn = null != preAnnotation['arguments'] ? preAnnotation['arguments'][n] : void 0;
                        if (preAnn)
                            for (var i$1 = 0, length$1 = param.members.length; i$1 < length$1; ++i$1) {
                                member = param.members[i$1];
                                type = resolveType(scope, preAnn);
                                if (type.nodeType === 'members') {
                                    memberAnn = _.find(type.properties, function (prop) {
                                        return (null != prop.identifier ? prop.identifier.typeRef : void 0) === (null != member.key ? member.key.data : void 0);
                                    });
                                    member.typeAnnotation = null != (null != memberAnn ? memberAnn.typeAnnotation : void 0) ? null != memberAnn ? memberAnn.typeAnnotation : void 0 : ImplicitAny;
                                }
                            }
                        return addValuesByInitializer(scope, param);
                    }
                });
        } else if (null != node.parameters)
            node.parameters.map(function (param, n) {
                walk(param, functionScope);
                if (param instanceof CS.Identifier) {
                    return functionScope.addVar({
                        nodeType: 'variable',
                        identifier: { typeRef: param.data },
                        typeAnnotation: null != param.typeAnnotation ? param.typeAnnotation : ImplicitAny
                    });
                } else if (param instanceof CS.ObjectInitialiser) {
                    return addValuesByInitializer(scope, param);
                } else if (param instanceof CS.ArrayInitialiser) {
                    return addValuesByInitializer(scope, param);
                }
            });
        if (null != node.body) {
            if (node.body instanceof CS.Function) {
                walkFunction(node.body, functionScope, node.typeAnnotation.returnType);
            } else {
                walk(node.body, functionScope);
            }
            if (!preAnnotation)
                if (null != node.typeAnnotation)
                    node.typeAnnotation.returnType = node.body.typeAnnotation;
            if (null != node.typeAnnotation)
                node.typeAnnotation;
            else
                node.typeAnnotation = {
                    implicit: true,
                    nodeType: 'functionType',
                    returnType: null,
                    'arguments': []
                };
            left = null != node.typeAnnotation.returnType ? node.typeAnnotation.returnType : node.typeAnnotation.returnType = ImplicitAny;
            right = null != node.body.typeAnnotation ? node.body.typeAnnotation : node.body.typeAnnotation = ImplicitAny;
            if (!checkTypeAnnotation(scope, node, left, right))
                return;
        }
    };
    walkFunctionApplication = function (node, scope) {
        var a, arg, givenArg, i, left, n, param, preAnn, right, type, typeArguments, typeScope;
        walk(node['function'], scope);
        for (var i$ = 0, length$ = node['arguments'].length; i$ < length$; ++i$) {
            arg = node['arguments'][i$];
            n = i$;
            walk(arg, scope);
        }
        type = scope.getVarInScope(node['function'].data);
        if (null != type && null != type.identifier && null != type.identifier.typeArguments ? type.identifier.typeArguments.length : void 0) {
            typeScope = new Scope(scope);
            typeArguments = node['function'].typeArguments;
            for (var i$1 = 0, length$1 = (null != type.identifier ? type.identifier.typeArguments : void 0).length; i$1 < length$1; ++i$1) {
                arg = (null != type.identifier ? type.identifier.typeArguments : void 0)[i$1];
                n = i$1;
                givenArg = null != typeArguments ? typeArguments[n] : void 0;
                typeScope.addType({
                    nodeType: 'identifier',
                    identifier: { typeRef: arg.identifier.typeRef },
                    typeAnnotation: {
                        nodeType: 'identifier',
                        identifier: { typeRef: givenArg.identifier.typeRef }
                    }
                });
            }
            node['function'].typeAnnotation = extendType(typeScope, _.cloneDeep(node['function'].typeAnnotation));
        }
        if ((null != node['function'].typeAnnotation ? node['function'].typeAnnotation.nodeType : void 0) === 'functionType') {
            node.typeAnnotation = null != node['function'].typeAnnotation.returnType ? node['function'].typeAnnotation.returnType : ImplicitAny;
        } else if ((null != node['function'].typeAnnotation ? node['function'].typeAnnotation.nodeType : void 0) === 'primitiveIdentifier') {
            if (null != node.typeAnnotation)
                node.typeAnnotation;
            else
                node.typeAnnotation = ImplicitAny;
        }
        return function (accum$) {
            for (var i$2 = 0, length$2 = node['arguments'].length; i$2 < length$2; ++i$2) {
                arg = node['arguments'][i$2];
                n = i$2;
                left = null != node['function'].typeAnnotation && null != node['function'].typeAnnotation['arguments'] ? node['function'].typeAnnotation['arguments'][n] : void 0;
                right = null != arg ? arg.typeAnnotation : void 0;
                if (arg instanceof CS.Function)
                    if ((null != node['function'].typeAnnotation && null != node['function'].typeAnnotation.identifier ? node['function'].typeAnnotation.identifier.typeRef : void 0) !== 'Any') {
                        preAnn = null != node['function'].typeAnnotation && null != node['function'].typeAnnotation['arguments'] ? node['function'].typeAnnotation['arguments'][n] : void 0;
                        if (preAnn) {
                            for (var i$3 = 0, length$3 = arg.parameters.length; i$3 < length$3; ++i$3) {
                                param = arg.parameters[i$3];
                                i = i$3;
                                a = preAnn['arguments'][i];
                                param.typeAnnotation = preAnn['arguments'][i];
                            }
                            delete arg.typeAnnotation;
                            delete arg.body.typeAnnotation;
                            walkFunction(arg, scope, preAnn);
                            right = preAnn;
                        }
                    }
                accum$.push(left && right ? checkTypeAnnotation(scope, node, left, right) : void 0);
            }
            return accum$;
        }.call(this, []);
    };
    walk = function (node, scope) {
        var s;
        if (!(null != node))
            return;
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
            return walkStruct(node, scope);
        case !(node.nodeType === 'vardef'):
            return walkVardef(node, scope);
        case !node['instanceof'](CS.Program):
            return walkProgram(node, scope);
        case !node['instanceof'](CS.Block):
            return walkBlock(node, scope);
        case !node['instanceof'](CS.Return):
            return walkReturn(node, scope);
        case !node['instanceof'](CS.NewOp):
            return walkNewOp(node, scope);
        case !(node['instanceof'](CS.PlusOp) || node['instanceof'](CS.MultiplyOp) || node['instanceof'](CS.DivideOp) || node['instanceof'](CS.SubtractOp)):
            return walkBinOp(node, scope);
        case !node['instanceof'](CS.Switch):
            return walkSwitch(node, scope);
        case !node['instanceof'](CS.Conditional):
            return walkConditional(node, scope);
        case !node['instanceof'](CS.Undefined):
            return walkUndefined(node, scope);
        case !node['instanceof'](CS.OfOp):
            return walkOfOp(node, scope);
        case !(node['instanceof'](CS.ForIn) || node['instanceof'](CS.ForOf)):
            return walkFor(node, scope);
        case !node['instanceof'](CS.Primitives):
            return walkPrimitives(node, scope);
        case !node['instanceof'](CS.Null):
            return walkNull(node, scope);
        case !node['instanceof'](CS.This):
            return walkThis(node, scope);
        case !node['instanceof'](CS.Identifier):
            return walkIdentifier(node, scope);
        case !node['instanceof'](CS.ClassProtoAssignOp):
            return walkClassProtoAssignOp(node, scope);
        case !node['instanceof'](CS.DynamicProtoMemberAccessOp):
            return walkDynamicProtoMemberAccessOp(node, scope);
        case !node['instanceof'](CS.DynamicMemberAccessOp):
            return walkDynamicMemberAccessOp(node, scope);
        case !node['instanceof'](CS.ProtoMemberAccessOp):
            return walkProtoMemberAccessOp(node, scope);
        case !node['instanceof'](CS.MemberAccessOps):
            return walkMemberAccess(node, scope);
        case !node['instanceof'](CS.ArrayInitialiser):
            return walkArrayInializer(node, scope);
        case !node['instanceof'](CS.Range):
            return walkRange(node, scope);
        case !node['instanceof'](CS.ObjectInitialiser):
            return walkObjectInitializer(node, scope);
        case !node['instanceof'](CS.Class):
            return walkClass(node, scope);
        case !node['instanceof'](CS.Function):
            return walkFunction(node, scope);
        case !node['instanceof'](CS.FunctionApplication):
            return walkFunctionApplication(node, scope);
        case !node['instanceof'](CS.CompoundAssignOp):
            return walkCompoundAssignOp(node, scope);
        case !node['instanceof'](CS.AssignOp):
            return walkAssignOp(node, scope);
        }
    };
    module.exports = { checkNodes: checkNodes };
}.call(this);