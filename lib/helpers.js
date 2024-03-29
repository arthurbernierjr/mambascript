// Generated by MambaScript 0.5.2 
var present = console.log; 
// Generated by MambaScript 0.5.2 
var beingDeclared, cleanMarkers, colourise, COLOURS, concat, concatMap, CS, difference, envEnrichments, envEnrichments_, foldl, humanReadable, map, nub, numberLines, pointToErrorLocation, SUPPORTS_COLOUR, usedAsExpression, usedAsExpression_;
cache$ = require('./functional-helpers');
concat = cache$.concat;
concatMap = cache$.concatMap;
difference = cache$.difference;
foldl = cache$.foldl;
map = cache$.map;
nub = cache$.nub;
CS = require('./nodes');
COLOURS = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};
SUPPORTS_COLOUR = ('undefined' !== typeof process && null != process && null != process.stderr ? process.stderr.isTTY : void 0) && !process.env.NODE_DISABLE_COLORS;
colourise = function (colour, str) {
  if (SUPPORTS_COLOUR) {
    return '' + COLOURS[colour] + str + '\x1b[39m';
  } else {
    return str;
  }
};
this.numberLines = numberLines = function (input, startLine) {
  var currLine, i, line, lines, numbered, pad, padSize;
  if (null == startLine)
    startLine = 1;
  lines = input.split('\n');
  padSize = ('' + (lines.length + startLine - 1)).length;
  numbered = function (accum$) {
    for (var i$ = 0, length$ = lines.length; i$ < length$; ++i$) {
      line = lines[i$];
      i = i$;
      currLine = '' + (i + startLine);
      pad = Array(padSize + 1).join('0').slice(currLine.length);
      accum$.push('' + pad + currLine + ' : ' + lines[i]);
    }
    return accum$;
  }.call(this, []);
  return numbered.join('\n');
};
cleanMarkers = function (str) {
  return str.replace(/[\uEFEF\uEFFE\uEFFF]/g, '');
};
this.humanReadable = humanReadable = function (str) {
  return str.replace(/\uEFEF/g, '(INDENT)').replace(/\uEFFE/g, '(DEDENT)').replace(/\uEFFF/g, '(TERM)');
};
this.formatParserError = function (input, e) {
  var found, message, realColumn, unicode;
  realColumn = cleanMarkers(('' + input.split('\n')[e.line - 1] + '\n').slice(0, e.column)).length;
  if (!(null != e.found))
    return 'Syntax error on line ' + e.line + ', column ' + realColumn + ': unexpected end of input. Below you should be able to see where the error is contained, keep in mind this error normally comes from you not being mindful of your indentation, or ending lines with operators. You have to maintain the same consistent indentation throughout your program. If you think that you found a bug in the language this error is generated from src/helpers.mamba help me improve it';
  found = JSON.stringify(humanReadable(e.found));
  found = found.replace(/^"|"$/g, '').replace(/'/g, "\\'").replace(/\\"/g, '"');
  unicode = e.found.charCodeAt(0).toString(16).toUpperCase();
  unicode = '\\u' + '0000'.slice(unicode.length) + unicode;
  message = 'Syntax error on line ' + e.line + ', column ' + realColumn + ": unexpected '" + found + "' with the unicode value of (" + unicode + '). Below you should be able to see where the error is contained, keep in mind this error normally comes from you not being mindful of your indentation, or ending lines with operators. You have to maintain the same consistent indentation throughout your program. If you think that you found a bug in the language this error is generated from src/helpers.mamba help me improve it';
  return '' + message + '\n' + pointToErrorLocation(input, e.line, realColumn);
};
this.pointToErrorLocation = pointToErrorLocation = function (source, line, column, numLinesOfContext) {
  var currentLineOffset, lines, numberedLines, padSize, postLines, preLines, startLine;
  if (null == numLinesOfContext)
    numLinesOfContext = 3;
  lines = source.split('\n');
  if (!lines[lines.length - 1])
    lines.pop();
  currentLineOffset = line - 1;
  startLine = currentLineOffset - numLinesOfContext;
  if (startLine < 0)
    startLine = 0;
  preLines = lines.slice(startLine, +currentLineOffset + 1 || 9e9);
  preLines[preLines.length - 1] = colourise('yellow', preLines[preLines.length - 1]);
  postLines = lines.slice(currentLineOffset + 1, +(currentLineOffset + numLinesOfContext) + 1 || 9e9);
  numberedLines = numberLines(cleanMarkers([].slice.call(preLines).concat([].slice.call(postLines)).join('\n')), startLine + 1).split('\n');
  preLines = numberedLines.slice(0, preLines.length);
  postLines = numberedLines.slice(preLines.length);
  column = cleanMarkers(('' + lines[currentLineOffset] + '\n').slice(0, column)).length;
  padSize = (currentLineOffset + 1 + postLines.length).toString(10).length;
  return [].slice.call(preLines).concat(['' + colourise('red', Array(padSize + 1).join('^')) + ' : ' + Array(column).join(' ') + colourise('red', '^')], [].slice.call(postLines)).join('\n');
};
this.beingDeclared = beingDeclared = function (assignment) {
  switch (false) {
  case !!(null != assignment):
    return [];
  case !assignment['instanceof'](CS.Identifiers):
    return [assignment.data];
  case !assignment['instanceof'](CS.Rest):
    return beingDeclared(assignment.expression);
  case !assignment['instanceof'](CS.MemberAccessOps):
    return [];
  case !assignment['instanceof'](CS.DefaultParam):
    return beingDeclared(assignment.param);
  case !assignment['instanceof'](CS.ArrayInitialiser):
    return concatMap(assignment.members, beingDeclared);
  case !assignment['instanceof'](CS.ObjectInitialiser):
    return concatMap(assignment.vals(), beingDeclared);
  default:
    throw new Error('beingDeclared: Non-exhaustive patterns in case: ' + assignment.className + " 'Non-exhaustive patterns' means that you have a set of pattern matches that don't cover all possible combinations. If you're really, really certain that a case is impossible, then use something like new Error 'this will never happen because blah blah blah'. If you can't explain why it'll never happen, then you should consider handling it properly. :), All in all something is ambiguous, If you think that you found a bug in the language this error is generated from src/helpers.mamba help me improve it");
  }
};
this.declarationsFor = function (node, inScope) {
  var vars;
  vars = envEnrichments(node, inScope);
  return foldl(new CS.Undefined().g(), vars, function (expr, v) {
    return new CS.AssignOp(new CS.Identifier(v).g(), expr).g();
  });
};
usedAsExpression_ = function (ancestors) {
  var grandparent, parent;
  parent = ancestors[0];
  grandparent = ancestors[1];
  switch (false) {
  case !!(null != parent):
    return true;
  case !parent['instanceof'](CS.Program, CS.Class):
    return false;
  case !parent['instanceof'](CS.SeqOp):
    return this === parent.right && usedAsExpression(parent, ancestors.slice(1));
  case !(parent['instanceof'](CS.Block) && parent.statements.indexOf(this) !== parent.statements.length - 1):
    return false;
  case !(parent['instanceof'](CS.Functions) && parent.body === this && null != grandparent && grandparent['instanceof'](CS.Constructor)):
    return false;
  default:
    return true;
  }
};
this.usedAsExpression = usedAsExpression = function (node, ancestors) {
  return usedAsExpression_.call(node, ancestors);
};
envEnrichments_ = function (inScope) {
  var possibilities;
  if (null == inScope)
    inScope = [];
  possibilities = nub(function () {
    switch (false) {
    case !this['instanceof'](CS.AssignOp):
      return concat([
        beingDeclared(this.assignee),
        envEnrichments(this.expression)
      ]);
    case !this['instanceof'](CS.Class):
      return concat([
        beingDeclared(this.nameAssignee),
        envEnrichments(this.parent)
      ]);
    case !this['instanceof'](CS.ForIn, CS.ForOf):
      return concat([
        beingDeclared(this.keyAssignee),
        beingDeclared(this.valAssignee),
        envEnrichments(this.target),
        envEnrichments(this.step),
        envEnrichments(this.filter),
        envEnrichments(this.body)
      ]);
    case !this['instanceof'](CS.Try):
      return concat([
        beingDeclared(this.catchAssignee),
        envEnrichments(this.body),
        envEnrichments(this.catchBody),
        envEnrichments(this.finallyBody)
      ]);
    case !this['instanceof'](CS.Functions):
      return [];
    default:
      return concatMap(this.childNodes, function (this$) {
        return function (child) {
          if (in$(child, this$.listMembers)) {
            return concatMap(this$[child], function (m) {
              return envEnrichments(m, inScope);
            });
          } else {
            return envEnrichments(this$[child], inScope);
          }
        };
      }(this));
    }
  }.call(this));
  return difference(possibilities, inScope);
};
this.envEnrichments = envEnrichments = function (node) {
  var args;
  args = arguments.length > 1 ? [].slice.call(arguments, 1) : [];
  if (null != node) {
    return envEnrichments_.apply(node, args);
  } else {
    return [];
  }
};
this.debug = function (flag) {
  var args, argv, i, util;
  args = arguments.length > 1 ? [].slice.call(arguments, 1) : [];
  util = require('util');
  argv = require('kofu-optimist').alias('d', 'debug').argv;
  if (arguments.length > 1) {
    if (!argv.debug || flag === argv.debug) {
      return function (accum$) {
        for (var i$ = 0, length$ = args.length; i$ < length$; ++i$) {
          i = args[i$];
          console.error('' + flag + ' ------- [');
          console.error(util.inspect(i, false, null, true));
          accum$.push(console.error('] ~~~~~~~~~ '));
        }
        return accum$;
      }.call(this, []);
    }
  } else {
    return console.error(flag);
  }
};
function in$(member, list) {
  for (var i = 0, length = list.length; i < length; ++i)
    if (i in list && list[i] === member)
      return true;
  return false;
}
