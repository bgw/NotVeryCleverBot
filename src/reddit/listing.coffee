# Getting lists of things from the Reddit API is awkward. Long lists aren't
# delivered in one part, but rather in chunks. This is an Array wrapper that
# provides some basic functionality to iterate over an API `Listing` object.

_ = require "underscore"

createListing = ({after, limit}, moreCallback) ->
    return (->
        @moreCallback = moreCallback
        @__after = after
        @limit = limit ?= 100
        @isComplete = false
        return _.extend @, proto
    ).call([])

proto =
    # `more (listing, delta) -> ...`
    more: (callback) ->
        # Error handling
        if @isComplete then throw new RangeError "Already done with listing"
        # Options
        options =
            limit: Math.min(@limit - @length, 100)
            after: @__after
        # Prevent multiple calls at the same time
        prevMore = @more
        @more = undefined
        @moreCallback options, (error, nextChunk) =>
            if error? then return callback error
            # Allow `more` to be called again
            @more = prevMore
            # Register the new elements
            @unshift (delta = unwrapListing nextChunk)...
            @__after = nextChunk.data.after
            @isComplete ||= not @__after? || @length >= @limit
            callback undefined, @, delta

    # Get elements until we're complete
    eachAsync: (iterator) ->
        _.each @, iterator
        f = =>
            if @isComplete then return
            @more (error, l, delta) =>
                _.each delta, iterator
                f()
        f()

    forEachAsync: (args...) -> @eachAsync args...

# Utility function to convert an API `Listing` object to an Array of currently
# known elements.
unwrapListing = (source) ->
    if source.kind != "Listing"
        throw new TypeError "Expected 'kind' value to be 'Listing'"
    return _.map source.data.children, (el) -> el.data

_.extend exports,
    createListing: createListing
