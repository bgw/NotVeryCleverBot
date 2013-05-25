# It can be handy to iterate over all new comments or links as they arrive to
# reddit. This provides the stream container for `commentStream` (and maybe an
# `articleStream` if that ever gets implemented). API should be somewhat
# compatible with `Listing` objects.

_ = require "underscore"
Q = require "q"
listing = require "./listing"

unwrapListing = listing._unwrapListing

class Stream
    constructor: ({before, streamCacheSize}, @moreCallback) ->
        @_before = before
        @isComplete = false # always false
        # Sometimes the reddit API might give us something twice. The cache
        # helps to weed out duplicates. It still might miss a few though.
        @_streamCacheSize = if (s = streamCacheSize)? then s else 1000
        @_streamCache = []

    more: (callback) ->
        # Use moreCallback to find the next elements
        Q.ninvoke(this, "moreCallback", limit: 100, before: @_before)
        .then((nextChunk) =>
            @_before = nextChunk.data.before
            # The timestamps should be placed into reverse-chronological order
            # as much as possible
            delta = unwrapListing(nextChunk).reverse()
            # Remove duplicates
            delta = _.filter delta, ({name}) => name not in @_streamCache
            @_streamCache = _.last @_streamCache.concat(_.pluck(delta, "name")),
                                   @_streamCacheSize
            return delta
        )
        .nodeify(callback) # Respect our callback
        return this

    each: (iterator) ->
        f = =>
            Q.ninvoke(this, "more")
            .fail(iterator)
            .then((delta) ->
                _.each delta, _.partial(iterator, undefined)
                return delta
            )
            .done((delta) ->
                # If you poll too quickly, you'll get a bunch of responses with
                # only a couple of entries. It's better to wait and reduce the
                # number of API calls.
                if delta.length < 90 then _.delay(f, 30000) else f()
            )
        f()
        return this

    forEach: (args...) -> @each args...

createStream = (args...) ->
    new Stream args...

_.extend exports,
    Stream: Stream
    createStream: createStream
