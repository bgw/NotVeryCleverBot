# Getting lists of things from the Reddit API is awkward. Long lists aren't
# delivered in one part, but rather in chunks. This is an Array wrapper that
# provides some basic functionality to iterate over an API `Listing` object.

_ = require "underscore"
Q = require "q"

createListing = ({after, limit}, moreCallback) ->
    return (->
        @_after = after
        @limit = limit ?= 100
        @moreCallback = moreCallback
        @isComplete = false
        return _.extend @, proto
    ).call([])

proto =
    # `more (error, listing, delta) -> ...`
    more: (callback) ->
        # Error handling
        if @isComplete then throw new RangeError "Already done with listing"
        # Options
        options =
            limit: Math.min(@limit - @length, 100)
            after: @_after
        Q.ninvoke(this, "moreCallback", options)
        .then((nextChunk) =>
            delta = unwrapListing nextChunk
            # Register the new elements
            @_after = nextChunk.data.after
            @push delta...
            @isComplete ||= not @_after? || @length >= @limit
            # Chain the promise
            return delta
        )
        .nodeify(callback)
        return this

    # Get elements until we're complete
    each: (iterator) ->
        _.each this, _.partial(iterator, undefined)
        f = =>
            if @isComplete then return
            Q.ninvoke(this, "more")
            .fail(iterator)
            .then((delta) ->
                _.each delta, _.partial(iterator, undefined)
                return delta
            )
            .done(f)
        f()
        return this

    forEach: (args...) -> @each args...

# Utility function to convert an API `Listing` object to an Array of currently
# known elements.
unwrapListing = (source) ->
    if source.kind != "Listing"
        throw new TypeError "Expected 'kind' value to be 'Listing'"
    return _.pluck source.data.children, "data"

_.extend exports,
    createListing: createListing
    _unwrapListing: unwrapListing
