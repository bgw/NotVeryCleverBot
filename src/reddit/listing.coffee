# Getting lists of things from the Reddit API is awkward. Long lists aren't
# delivered in one part, but rather in chunks. This is an Array wrapper that
# provides some basic functionality to iterate over an API `Listing` object.

_ = require "underscore"

createListing = ({after, limit}, moreCallback) ->
    return (->
        @__after = after
        @limit = limit ?= 100
        @moreCallback = moreCallback
        @isComplete = false
        @listingType = "listing"
        return _.extend @, proto
    ).call([])

# Like `createListing`, but for unending lists. This is useful for streams of
# data, like comments. Because storing all these entries would take an
# infinitely increasing amount of memory, there are no array elements stored
# here. The data is only available via `more` or other related functions.
createStream = ({after}, moreCallback) ->
    return (->
        @__after = after
        @moreCallback = moreCallback
        return _.extend @, proto
    ).call
        listingType: "stream"

proto =
    # `more (error, listing, delta) -> ...`
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
            if error?
                return callback error
            delta = unwrapListing nextChunk
            # Allow `more` to be called again
            @more = prevMore
            # Register the new elements
            @__after = nextChunk.data.after
            if @listingType is "listing"
                @push delta...
                @isComplete ||= not @__after? || @length >= @limit
            callback undefined, @, delta

    # Get elements until we're complete
    eachAsync: (iterator) ->
        if @listingType is "listing" then _.each @, iterator
        f = =>
            if @isComplete then return
            @more (error, l, delta) =>
                console.log error
                if error?
                    iterator error
                else
                    _.each delta, _.partial(iterator, undefined)
                f()
        f()

    forEachAsync: (args...) -> @eachAsync args...

# Utility function to convert an API `Listing` object to an Array of currently
# known elements.
unwrapListing = (source) ->
    if source.kind != "Listing"
        throw new TypeError "Expected 'kind' value to be 'Listing'"
    a = () -> undefined
    return _.map source.data.children, (el) -> el.data

_.extend exports,
    createListing: createListing
    createStream: createStream
