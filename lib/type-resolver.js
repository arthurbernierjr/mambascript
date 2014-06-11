void function () {
    var _, cache$, ClassScope, extendFunctionType, extendIdentifierType, extendMembers, extendType, FunctionScope, resolveType, rewriteType, Scope;
    _ = require('lodash');
    cache$ = require('./type-scope');
    Scope = cache$.Scope;
    ClassScope = cache$.ClassScope;
    FunctionScope = cache$.FunctionScope;
    rewriteType = function (scope, node, from, to) {
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
                ann = scope.getTypeByNode(from.typeAnnotation);
                if (ann)
                    extendType(scope, ann, typeArgs);
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
                            rewriteType(scope, prop.typeAnnotation.returnType, from, to);
                            return function (accum$2) {
                                for (var i$2 = 0, length$2 = prop.typeAnnotation['arguments'].length; i$2 < length$2; ++i$2) {
                                    arg = prop.typeAnnotation['arguments'][i$2];
                                    accum$2.push(rewriteType(scope, arg, from, to));
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
                                ann = scope.getTypeByNode(prop.typeAnnotation);
                                if (ann)
                                    extendType(scope, ann, typeArgs);
                            }
                            if ((null != prop.typeAnnotation.identifier ? prop.typeAnnotation.identifier.typeRef : void 0) === from.identifier.typeRef)
                                return prop.typeAnnotation.identifier.typeRef = to.identifier.typeRef;
                        case 'members':
                            return rewriteType(scope, prop.typeAnnotation, from, to);
                        }
                    }.call(this));
                }
                return accum$1;
            }.call(this, []);
        }
    };
    extendIdentifierType = function (scope, node) {
        var ann, from, to;
        ann = scope.getTypeInScope(node.identifier.typeRef);
        if (ann.nodeType === 'identifier') {
            if (!(null != ann.typeAnnotation))
                throw new Error('identifier with annotation required');
            from = node;
            to = ann.typeAnnotation;
            return rewriteType(scope, node, from, to);
        }
    };
    extendFunctionType = function (scope, node) {
        var arg;
        extendIdentifierType(scope, node.returnType);
        for (var i$ = 0, length$ = node['arguments'].length; i$ < length$; ++i$) {
            arg = node['arguments'][i$];
            if (arg.nodeType === 'identifier') {
                extendIdentifierType(scope, arg);
            } else if (arg.nodeType === 'functionType') {
                extendFunctionType(scope, arg);
            }
        }
        return node;
    };
    extendMembers = function (scope, node, givenArgs) {
        var ann, arg, givenArg, n, typeArgs, typeScope;
        typeScope = new Scope(scope);
        if (null != node.identifier && null != node.identifier.typeArguments ? node.identifier.typeArguments.length : void 0)
            for (var i$ = 0, length$ = node.identifier.typeArguments.length; i$ < length$; ++i$) {
                arg = node.identifier.typeArguments[i$];
                n = i$;
                givenArg = givenArgs[n];
                if (null != givenArg && null != givenArg.identifier && null != givenArg.identifier.typeArguments ? givenArg.identifier.typeArguments.length : void 0) {
                    typeArgs = givenArg.identifier.typeArguments;
                    if (ann = scope.getTypeByNode(givenArg))
                        extendType(scope, ann, typeArgs);
                }
                typeScope.addType({
                    nodeType: 'identifier',
                    identifier: _.cloneDeep(arg.identifier),
                    typeAnnotation: {
                        nodeType: 'identifier',
                        identifier: _.cloneDeep(givenArg.identifier)
                    }
                });
            }
        return function (accum$) {
            for (var i$1 = 0, length$1 = node.identifier.typeArguments.length; i$1 < length$1; ++i$1) {
                arg = node.identifier.typeArguments[i$1];
                n = i$1;
                givenArg = givenArgs[n];
                accum$.push(rewriteType(typeScope, node, arg, givenArg));
            }
            return accum$;
        }.call(this, []);
    };
    extendType = function (scope, node, givenArgs) {
        if (node.nodeType === 'members') {
            extendMembers(scope, node, givenArgs);
        } else if (node.nodeType === 'functionType') {
            extendFunctionType(scope, node);
        }
        return node;
    };
    resolveType = function (scope, node) {
        var ret;
        if (node.nodeType === 'identifier') {
            ret = scope.getTypeByNode(node);
            if (null != node.identifier && null != node.identifier.typeArguments ? node.identifier.typeArguments.length : void 0)
                ret = extendType(scope, _.cloneDeep(ret), node.identifier.typeArguments);
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
    module.exports = {
        resolveType: resolveType,
        extendType: extendType
    };
}.call(this);