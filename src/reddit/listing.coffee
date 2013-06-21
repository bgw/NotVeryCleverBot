# Getting lists of things from the Reddit API is awkward. Long lists aren't
# delivered in one part, but rather in chunks. This is an Array wrapper that
# provides some basic functionality to iterate over an API `Listing` object.

_ = require "lodash"
async = require "async"
Lazy = require "lazy.js"

class Listing extends Lazy.Sequence
    constructor: ({after}, moreCallback) ->
        @_after = after
        @_moreCallback = moreCallback
        @_isComplete = false

    _more: (callback) ->
        # Error handling
        if @_isComplete then callback new RangeError "Already done with listing"
        # Options
        options = after: @_after
        async.waterfall [
            _.bind @_moreCallback, this, options
            (nextChunk, callback) =>
                delta = unwrapListing nextChunk
                # Register the new elements
                @_after = nextChunk.data.after
                @_isComplete ||= not @_after?
                callback null, delta
        ], callback
        return

    # Calls the given iterator on each element. If an error occurs, it is passed
    # to the iterator in place of an element (See [dtao/lazy.js#27] [dtao]). You
    # should check `instanceof Error`.
    #
    # [dtao]: https://github.com/dtao/lazy.js/issues/27
    each: (iterator) ->
        f = =>
            if @_isComplete then return
            @_more (err, delta) ->
                if err?
                    unless iterator(err) is false
                        _.delay f, 30000
                    return
                # Iterate over delta, and quit if false is explicitly returned
                (if iterator(el) is false then return) for el in delta
                f()
        f()
        return

    forEach: (args...) -> @each args...

createListing = (args...) ->
    new Listing args...

# Utility function to convert an API `Listing` object to an Array of currently
# known elements.
unwrapListing = (source) ->
    if source.kind != "Listing"
        throw new TypeError "Expected 'kind' value to be 'Listing'"
    return _.pluck source.data.children, "data"

_.extend exports,
    createListing: createListing
    _unwrapListing: unwrapListing
