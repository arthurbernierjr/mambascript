void function () {
    var _, cache$, checkType, checkTypeAnnotation, ClassScope, correctExtends, CS, debug, extendFunctionType, extendTypeWithArguments, formatType, FunctionScope, ImplicitAnyAnnotation, initializeGlobalTypes, isAcceptable, isAcceptableExtends, isAcceptableFunctionType, isAcceptablePrimitiveSymbol, isAcceptableStruct, reporter, resolveType, rewriteTypeWithArg, Scope, typeErrorText, util;
    debug = require('./helpers').debug;
    util = require('util');
    reporter = require('./reporter');
    CS = require('./nodes');
    _ = require('lodash');
    ImplicitAnyAnnotation = {
        implicit: true,
        isPrimitive: true,
        nodeType: 'primitiveIdentifier',
        identifier: { typeRef: 'Any' }
    };
    cache$ = require('./types');
    initializeGlobalTypes = cache$.initializeGlobalTypes;
    Scope = cache$.Scope;
    ClassScope = cache$.ClassScope;
    FunctionScope = cache$.FunctionScope;
    correctExtends = function (scope, annotation) {
        var cur, extendList, next;
        extendList = [annotation];
        cur = annotation;
        while (null != (null != cur && null != cur.heritages ? cur.heritages.extend : void 0)) {
            next = scope.getTypeByIdentifier(cur.heritages.extend);
            if (next) {
                extendList.push(next);
                cur = next;
            } else {
                break;
            }
        }
        return extendList;
    };
    isAcceptableExtends = function (scope, left, right) {
        return _.any(correctExtends(scope, left).map(function (le) {
            return le.identifier.typeRef === right.identifier.typeRef;
        }));
    };
    isAcceptablePrimitiveSymbol = function (scope, left, right, nullable, isArray) {
        if (null == nullable)
            nullable = false;
        if (null == isArray)
            isArray = false;
        if (left.nodeType !== 'primitiveIdentifier')
            throw 'left is not primitive';
        if (left.identifier.typeRef === 'Any')
            return true;
        if (!isAcceptableExtends(scope, left, right)) {
            if (nullable && (right.identifier.typeRef === 'Null' || right.identifier.typeRef === 'Undefined'))
                return true;
            return false;
        }
        if (!!left.identifier.isArray) {
            if (null != (null != right && null != right.identifier ? right.identifier.isArray : void 0)) {
                if (!!(null != right && null != right.identifier ? right.identifier.isArray : void 0) !== true)
                    return false;
            } else {
                return false;
            }
        } else if (!!(null != right && null != right.identifier ? right.identifier.isArray : void 0) !== false)
            return false;
        return true;
    };
    isAcceptableStruct = function (scope, left, right) {
        return _.all(left.properties.map(function (lprop, n) {
            var rprop;
            rprop = _.find(right.properties, function (rp) {
                return (null != rp.identifier ? rp.identifier.typeRef : void 0) === (null != lprop.identifier ? lprop.identifier.typeRef : void 0);
            });
            if (!(null != rprop))
                return null != lprop.typeAnnotation && null != lprop.typeAnnotation.identifier ? lprop.typeAnnotation.identifier.nullable : void 0;
            return isAcceptable(scope, lprop.typeAnnotation, rprop.typeAnnotation);
        }));
    };
    isAcceptableFunctionType = function (scope, left, right) {
        var passArgs;
        if (null != left.returnType)
            left.returnType;
        else
            left.returnType = ImplicitAnyAnnotation;
        if (null != right.returnType)
            right.returnType;
        else
            right.returnType = ImplicitAnyAnnotation;
        passArgs = _.all(left['arguments'].map(function (leftArg, n) {
            var rightArg;
            leftArg = null != leftArg ? leftArg : ImplicitAnyAnnotation;
            rightArg = null != right['arguments'][n] ? right['arguments'][n] : ImplicitAnyAnnotation;
            return isAcceptable(scope, leftArg, rightArg);
        }));
        if (!passArgs)
            return false;
        if ((null != right.returnType && null != right.returnType.identifier ? right.returnType.identifier.typeRef : void 0) === 'Void')
            return true;
        if ((null != left.returnType && null != left.returnType.identifier ? left.returnType.identifier.typeRef : void 0) === 'Void')
            return true;
        return isAcceptable(scope, left.returnType, right.returnType);
    };
    rewriteTypeWithArg = function (scope, node, from, to) {
        var ann, arg, i, n, prop, resolved, typeArgs;
        if (node.nodeType === 'identifier') {
            if (null != node.identifier && null != node.identifier.typeArguments ? node.identifier.typeArguments.length : void 0) {
                typeArgs = function (accum$) {
                    for (var i$ = 0, length$ = node.identifier.typeArguments.length; i$ < length$; ++i$) {
                        i = node.identifier.typeArguments[i$];
                        n = i$;
                        resolved = resolveType(scope, i);
                        accum$.push(resolved.typeAnnotation);
                    }
                    return accum$;
                }.call(this, []);
                ann = scope.getTypeByIdentifier(from.typeAnnotation);
                if (ann)
                    extendTypeWithArguments(scope, ann, typeArgs);
            }
            if ((null != node.identifier ? node.identifier.typeRef : void 0) === from.identifier.typeRef)
                return node.identifier.typeRef = to.identifier.typeRef;
        } else if (node.nodeType === 'members') {
            return function (accum$1) {
                for (var i$1 = 0, length$1 = node.properties.length; i$1 < length$1; ++i$1) {
                    prop = node.properties[i$1];
                    accum$1.push(function () {
                        switch (prop.typeAnnotation.nodeType) {
                        case 'functionType':
                            rewriteTypeWithArg(scope, prop.typeAnnotation.returnType, from, to);
                            return function (accum$2) {
                                for (var i$2 = 0, length$2 = prop.typeAnnotation['arguments'].length; i$2 < length$2; ++i$2) {
                                    arg = prop.typeAnnotation['arguments'][i$2];
                                    accum$2.push(rewriteTypeWithArg(scope, arg, from, to));
                                }
                                return accum$2;
                            }.call(this, []);
                        case 'identifier':
                            if (null != prop.typeAnnotation && null != prop.typeAnnotation.identifier && null != prop.typeAnnotation.identifier.typeArguments ? prop.typeAnnotation.identifier.typeArguments.length : void 0) {
                                typeArgs = function (accum$3) {
                                    for (var i$3 = 0, length$3 = prop.typeAnnotation.identifier.typeArguments.length; i$3 < length$3; ++i$3) {
                                        i = prop.typeAnnotation.identifier.typeArguments[i$3];
                                        n = i$3;
                                        resolved = resolveType(scope, i);
                                        accum$3.push(resolved.typeAnnotation);
                                    }
                                    return accum$3;
                                }.call(this, []);
                                ann = scope.getTypeByIdentifier(prop.typeAnnotation);
                                if (ann)
                                    extendTypeWithArguments(scope, ann, typeArgs);
                            }
                            if ((null != prop.typeAnnotation.identifier ? prop.typeAnnotation.identifier.typeRef : void 0) === from.identifier.typeRef)
                                return prop.typeAnnotation.identifier.typeRef = to.identifier.typeRef;
                        case 'members':
                            return rewriteTypeWithArg(scope, prop.typeAnnotation, from, to);
                        }
                    }.call(this));
                }
                return accum$1;
            }.call(this, []);
        }
    };
    extendFunctionType = function (scope, node) {
        var arg, from, rFrom, rTo, rType, to, type;
        rType = scope.getTypeInScope(node.returnType.identifier.typeRef);
        if (rType.nodeType === 'identifier') {
            rFrom = node.returnType;
            rTo = rType.typeAnnotation;
            rewriteTypeWithArg(scope, node.returnType, rFrom, rTo);
        }
        for (var i$ = 0, length$ = node['arguments'].length; i$ < length$; ++i$) {
            arg = node['arguments'][i$];
            if (arg.nodeType === 'identifier') {
                type = scope.getTypeInScope(arg.identifier.typeRef);
                if (type.nodeType === 'identifier') {
                    from = _.cloneDeep(arg);
                    to = _.cloneDeep(type.typeAnnotation);
                    rewriteTypeWithArg(scope, arg, from, to);
                }
            } else if (arg.nodeType === 'functionType') {
                extendFunctionType(scope, arg);
            }
        }
        return node;
    };
    extendTypeWithArguments = function (scope, node, givenArgs) {
        var a, ann, arg, givenArg, n, ret, typeArgs, typeScope;
        typeScope = new Scope(scope);
        if (null != node.identifier && null != node.identifier.typeArguments ? node.identifier.typeArguments.length : void 0) {
            for (var i$ = 0, length$ = node.identifier.typeArguments.length; i$ < length$; ++i$) {
                arg = node.identifier.typeArguments[i$];
                n = i$;
                givenArg = givenArgs[n];
                if (null != givenArg && null != givenArg.identifier && null != givenArg.identifier.typeArguments ? givenArg.identifier.typeArguments.length : void 0) {
                    typeArgs = givenArg.identifier.typeArguments;
                    ann = scope.getTypeByIdentifier(givenArg);
                    if (ann)
                        ret = extendTypeWithArguments(scope, ann, typeArgs);
                }
                a = {
                    nodeType: 'identifier',
                    identifier: { typeRef: arg.identifier.typeRef },
                    typeAnnotation: {
                        nodeType: 'identifier',
                        identifier: { typeRef: givenArg.identifier.typeRef }
                    }
                };
                typeScope.addType(a);
            }
            for (var i$1 = 0, length$1 = node.identifier.typeArguments.length; i$1 < length$1; ++i$1) {
                arg = node.identifier.typeArguments[i$1];
                n = i$1;
                givenArg = givenArgs[n];
                rewriteTypeWithArg(typeScope, node, arg, givenArg);
            }
        }
        return node;
    };
    resolveType = function (scope, node) {
        var ret;
        if (node.nodeType === 'identifier') {
            ret = scope.getTypeByIdentifier(node);
            if (null != node.identifier && null != node.identifier.typeArguments ? node.identifier.typeArguments.length : void 0)
                ret = extendTypeWithArguments(scope, _.cloneDeep(ret), node.identifier.typeArguments);
            if (!ret) {
                if (node.nodeType === 'identifier')
                    return node;
                throw 'Type: ' + util.inspect(node.identifier.typeRef) + ' is not defined';
            }
            return ret;
        } else if (node.nodeType === 'primitiveIdentifier') {
            return node;
        } else if (node.nodeType === 'members') {
            return node;
        } else if (node.nodeType === 'functionType') {
            return node;
        } else {
            throw (null != node ? node.nodeType : void 0) + ' is not registered nodeType';
        }
    };
    isAcceptable = function (scope, left, right) {
        var cache$1, isSameArrayFlag, leftAnnotation, leftNullable, leftWholeNullable, ret, rightAnnotation, rightNullable;
        if (!(null != left) || !(null != right))
            return true;
        cache$1 = [
            left,
            right
        ].map(function (node) {
            return resolveType(scope, node);
        });
        leftAnnotation = cache$1[0];
        rightAnnotation = cache$1[1];
        if (null != leftAnnotation.identifier && null != leftAnnotation.identifier.identifier && null != leftAnnotation.identifier.identifier.typeArguments ? leftAnnotation.identifier.identifier.typeArguments.length : void 0)
            console.error(leftAnnotation.identifier.identifier.typeArguments);
        if (!(null != leftAnnotation) || !(null != rightAnnotation))
            return true;
        if (leftAnnotation.nodeType === 'primitiveIdentifier')
            if (leftAnnotation.identifier.typeRef === 'Any')
                return true;
        if (left.identifier && right.identifier && rightAnnotation) {
            leftWholeNullable = left.identifier.wholeNullable;
            if (leftWholeNullable && (rightAnnotation.identifier.typeRef === 'Undefined' || rightAnnotation.identifier.typeRef === 'Null'))
                return true;
            isSameArrayFlag = !!left.identifier.isArray === !!right.identifier.isArray || !!left.identifier.isArray === !!rightAnnotation.isArray;
            if (!isSameArrayFlag)
                return false;
        }
        if (leftAnnotation.nodeType === 'identifier') {
            if (leftAnnotation.identifier.typeRef === rightAnnotation.identifier.typeRef) {
                return true;
            } else {
                return false;
            }
        } else if (leftAnnotation.nodeType === 'members') {
            if (rightAnnotation.nodeType === 'members') {
                ret = isAcceptableStruct(scope, leftAnnotation, rightAnnotation);
                return ret;
            } else {
                return false;
            }
        }
        if (leftAnnotation.nodeType === 'primitiveIdentifier')
            if (rightAnnotation.nodeType === 'primitiveIdentifier') {
                if (leftAnnotation.identifier.typeRef === 'Void')
                    return true;
                leftNullable = !!left.identifier.nullable;
                rightNullable = !!right.identifier.nullable;
                if (!leftNullable && rightNullable)
                    return false;
                return isAcceptablePrimitiveSymbol(scope, leftAnnotation, rightAnnotation, leftNullable);
            } else {
                return false;
            }
        if (leftAnnotation.nodeType === 'functionType')
            if (rightAnnotation.nodeType === 'functionType') {
                return isAcceptableFunctionType(scope, leftAnnotation, rightAnnotation);
            } else if (null != leftAnnotation && null != leftAnnotation.returnType ? leftAnnotation.returnType.implicit : void 0) {
                return true;
            } else {
                return false;
            }
        return true;
    };
    util = require('util');
    formatType = function (node, prefix) {
        var args, array, joined, lines, returnType;
        if (null == prefix)
            prefix = '';
        if (node.nodeType === 'members') {
            lines = node.properties.map(function (prop) {
                return prefix + '- ' + formatType(prop, prefix + '  ');
            });
            return '[struct]' + '\n' + lines.join('\n');
        } else if (node.nodeType === 'primitiveIdentifier') {
            return prefix + node.identifier.typeRef;
        } else if (node.nodeType === 'identifier') {
            'identifier';
            array = node.identifier.isArray ? '[]' : '';
            if (null != node.typeAnnotation) {
                return node.identifier.typeRef + array + ' :: ' + formatType(node.typeAnnotation, prefix);
            } else {
                return node.identifier.typeRef + array;
            }
        } else if (node.nodeType === 'functionType') {
            args = node['arguments'].map(function (arg) {
                return prefix + '- ' + formatType(arg, prefix + '  ');
            });
            joined = '\n' + args.join('\n');
            returnType = formatType(node.returnType, prefix + '  ');
            return '[function]\n' + prefix + '[arguments] ' + joined + '\n' + prefix + '[return] ' + returnType + '';
        } else {
            return util.inspect(node, false, null);
        }
    };
    typeErrorText = function (left, right) {
        var header, l, r;
        header = '\nTypeError:';
        l = formatType(left, '  ');
        r = formatType(right, '  ');
        return '' + header + '\nrequired:\n' + l + '\nassignee:\n' + r + '';
    };
    checkType = function (scope, node, left, right) {
        var err, ret;
        ret = isAcceptable(scope, left.typeAnnotation, right.typeAnnotation);
        if (ret) {
            return true;
        } else {
            err = typeErrorText(left.typeAnnotation, right.typeAnnotation);
            if (left.implicit && right.implicit) {
                reporter.add_warning(node, err);
            } else {
                reporter.add_error(node, err);
            }
            return false;
        }
    };
    checkTypeAnnotation = function (scope, node, left, right) {
        var err, ret;
        ret = isAcceptable(scope, left, right);
        if (ret) {
            return true;
        } else {
            err = typeErrorText(left, right);
            if (left.implicit && right.implicit) {
                reporter.add_warning(node, err);
            } else {
                reporter.add_error(node, err);
            }
            return false;
        }
    };
    module.exports = {
        checkType: checkType,
        checkTypeAnnotation: checkTypeAnnotation,
        isAcceptable: isAcceptable,
        resolveType: resolveType,
        extendTypeWithArguments: extendTypeWithArguments,
        extendFunctionType: extendFunctionType
    };
}.call(this);