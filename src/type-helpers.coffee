# ref: http://coffeescriptcookbook.com/chapters/classes_and_objects/cloning
@clone = clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime()) 

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags) 

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance

# rewrite :: Object * Hash<String, String> -> ()
@rewrite = rewrite = (obj, replacer) ->
  return if (typeof obj) in ['string', 'number']
  for key, val of obj
    if (typeof val) is 'string'
      if replacer[val]?
        obj[key] = replacer[val]
    else if val instanceof Object
      rewrite(val, replacer)

class @TypeError
  constructor: (@message) ->
