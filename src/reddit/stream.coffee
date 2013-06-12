# It can be handy to iterate over all new comments or links as they arrive to
# Reddit. This provides the stream container for `commentStream` (and maybe an
# `articleStream` if that ever gets implemented). API should be somewhat
# compatible with `Listing` objects.

_ = require "lodash"
async = require "async"
listing = require "./listing"

unwrapListing = listing._unwrapListing

class Stream
    constructor: ({before, streamCacheSize}, @moreCallback) ->
        @_before = before
        @isComplete = false # always false
        # Sometimes the Reddit API might give us something twice. The cache
        # helps to weed out duplicates. It still might miss a few though.
        @_streamCacheSize = if (s = streamCacheSize)? then s else 5000
        @_streamCache = []

    more: (callback) ->
        # Use moreCallback to find the next elements
        async.waterfall [
            _.bind @moreCallback, this, limit: 100, before: @_before
            (nextChunk, callback) =>
                # The timestamps should be placed into reverse-chronological
                # order as much as possible
                delta = unwrapListing(nextChunk).reverse()
                @_before = _.last(delta).name
                # Remove duplicates
                inCache = _.partial _.has, _.object(@_streamCache)
                delta = _.filter delta, ({name}) => not inCache name
                # Place new entries in cache
                @_streamCache = @_streamCache.concat _.pluck(delta, "name")
                @_streamCache = _.last @_streamCache, @_streamCacheSize
                callback null, delta
        ], callback
        return this

    each: (iterator) ->
        f = =>
            @more (err, delta) ->
                if err? then return iterator err
                _.each delta, _.partial iterator, null
                # If you poll too quickly, you'll get a bunch of responses with
                # only a couple of entries. It's better to wait and reduce the
                # number of API calls.
                if delta.length < 90 then _.delay(f, 30000) else f()
        f()
        return this

    forEach: Stream::each

createStream = (args...) ->
    new Stream args...

_.extend exports,
    Stream: Stream
    createStream: createStream
