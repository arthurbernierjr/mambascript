void function () {
    var _, cache$, checkType, checkTypeAnnotation, ClassScope, correctExtends, CS, debug, FunctionScope, ImplicitAnyAnnotation, initializeGlobalTypes, isAcceptable, isAcceptableExtends, isAcceptableFunctionType, isAcceptablePrimitiveSymbol, isAcceptableStruct, reporter, Scope, typeErrorText;
    debug = require('./helpers').debug;
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
    isAcceptablePrimitiveSymbol = function (scope, left, right) {
        if (left.nodeType !== 'primitiveIdentifier')
            throw 'left is not primitive';
        if (left.identifier.typeRef === 'Any')
            return true;
        if (!isAcceptableExtends(scope, left, right))
            return false;
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
        var leftArg, n, rightArg;
        if (null != left.returnType)
            left.returnType;
        else
            left.returnType = ImplicitAnyAnnotation;
        if (null != right.returnType)
            right.returnType;
        else
            right.returnType = ImplicitAnyAnnotation;
        if (!isAcceptable(scope, left.returnType, right.returnType))
            return false;
        return _.all(function (accum$) {
            for (var i$ = 0, length$ = left['arguments'].length; i$ < length$; ++i$) {
                leftArg = left['arguments'][i$];
                n = i$;
                leftArg = 'undefined' !== typeof leftArg && null != leftArg ? leftArg : ImplicitAnyAnnotation;
                rightArg = null != right['arguments'][n] ? right['arguments'][n] : ImplicitAnyAnnotation;
                accum$.push(isAcceptable(scope, leftArg, rightArg));
            }
            return accum$;
        }.call(this, []));
    };
    isAcceptable = function (scope, left, right) {
        var cache$1, leftAnnotation, rightAnnotation;
        if (!(null != left) || !(null != right))
            return true;
        cache$1 = [
            left,
            right
        ].map(function (node) {
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
        leftAnnotation = cache$1[0];
        rightAnnotation = cache$1[1];
        if (!(null != leftAnnotation) || !(null != rightAnnotation))
            return true;
        if (leftAnnotation.nodeType === 'primitiveIdentifier')
            if (leftAnnotation.identifier.typeRef === 'Any')
                return true;
        if (leftAnnotation.nodeType === rightAnnotation.nodeType && rightAnnotation.nodeType === 'members')
            return isAcceptableStruct(scope, leftAnnotation, rightAnnotation);
        if (leftAnnotation.nodeType === rightAnnotation.nodeType && rightAnnotation.nodeType === 'primitiveIdentifier')
            return isAcceptablePrimitiveSymbol(scope, leftAnnotation, rightAnnotation);
        if (leftAnnotation.nodeType === rightAnnotation.nodeType && rightAnnotation.nodeType === 'functionType')
            return isAcceptableFunctionType(scope, leftAnnotation, rightAnnotation);
    };
    typeErrorText = function (left, right) {
        var util;
        util = require('util');
        return 'TypeError: \n' + util.inspect(left, false, null) + ' \n to \n ' + util.inspect(right, false, null);
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
        isAcceptable: isAcceptable
    };
}.call(this);