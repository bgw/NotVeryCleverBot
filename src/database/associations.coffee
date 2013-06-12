# We don't use Sequelize's association support, as it requires way too many
# manipulations and lookups to initialized efficiently. An informed
# implementation of the same operations is much more efficient.
#
# This module has the implementation of some helper functions that should make
# it easy to write instance methods that look and behave like real associations.
# Not everything works (eager loading being one), but it's "good enough".
#
# One additional pattern exists. While true associations would require using an
# emitter function (such as `success` or `done`), our generated functions all
# optionally take a `callback` argument as their last.

_ = require "lodash"

# Given a query generation function, makes a new getter like one Sequelize would
# make for us.
#
# - `associatedModel` isn't necessarily the current model, but rather the one we
#   perform the lookup in. For example, a `getComment` method will have
#   `Comment` as its `associatedModel`. If you wish for lazy evaluation, this
#   can be a function taking no arguments that returns a model.
# - `finder` is the name of the function to call on the `associatedModel`. This
#   probably going to be either `"find"` or `"findAll"`.
# - `queryGen` should return a sequelize query when executed in the context of
#   our runtime `this`. That way, it can pull properties from `this`.
getter = (associatedModel, finder, queryGen) ->
    (args...) ->
        # `associatedModel` may be a function returning a model (for lazy eval).
        associatedModel = associatedModel?() || associatedModel
        # Pull out a callback if it exists.
        if args.length and _.isFunction _.last(args)
            [args, callback] = [_initial(args), _.last(args)]
        # Make an empty query if there is none provided.
        args[0] ?= {}
        # Merge the base query from queryGen into the provided query.
        _.merge args[0], queryGen()
        # Perform the find operation and get the emitter.
        operation = associatedModel[finder](args...)
        # If there was a callback provided (above), associate it.
        if callback? then operation.done callback
        # Return the emitter like Sequelize would've done.
        return operation

# Convenience versions of `getter`
getOne = (associatedModel, queryGen) ->
    getter associatedModel, "find", queryGen
getMany = (associatedModel, queryGen) ->
    getter associatedModel, "findAll", queryGen

_.extend exports, {getter, getOne, getMany}
