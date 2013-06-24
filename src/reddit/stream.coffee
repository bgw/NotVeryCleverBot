# It can be handy to iterate over all new comments or links as they arrive to
# Reddit. This provides the stream container for `commentStream` (and maybe an
# `articleStream` if that ever gets implemented). API should be somewhat
# compatible with `Listing` objects.
#
# Inspiration for this module comes from [praw's `comment_stream`] [praw].
#
# [praw]: https://github.com/praw-dev/praw/blob/master/praw/helpers.py

_ = require "lodash"
Lazy = require "lazy.js"
async = require "async"
listing = require "./listing"

unwrapListing = listing._unwrapListing

class Stream extends Lazy.Sequence
    constructor: ({streamCacheSize}, @moreCallback) ->
        @isComplete = false # always false
        # Sometimes the Reddit API might give us something twice. The cache
        # helps to weed out duplicates. It still might miss a few though.
        @_streamCacheSize = streamCacheSize ?= 5000
        @_streamCache = []

    _more: (callback) ->
        # Use moreCallback to find the next elements
        async.waterfall [
            _.bind @moreCallback, this, limit: 100, before: @_before
            (nextChunk, callback) =>
                # The timestamps should be placed into reverse-chronological
                # order as much as possible.
                delta = unwrapListing(nextChunk).reverse()
                # Sometimes we're given no entries from the API. This might be
                # because our `before` value is bad or too old. In that case it
                # should be reset (undefined). Otherwise, it is our last item.
                @_before = _.last(delta)?.name
                # Remove duplicates
                inCache = _.partial _.has, _.object(@_streamCache)
                delta = _.filter delta, ({name}) => not inCache name
                # Place new entries in cache
                @_streamCache = @_streamCache.concat _.pluck(delta, "name")
                @_streamCache = _.last @_streamCache, @_streamCacheSize
                callback null, delta
        ], (err, delta) ->
            callback err, delta
        return

    # Calls the given iterator on each element. If an error occurs, it is passed
    # to the iterator in place of an element (See [dtao/lazy.js#27] [dtao]). You
    # should check `instanceof Error`.
    #
    # [dtao]: https://github.com/dtao/lazy.js/issues/27
    each: (iterator) ->
        f = =>
            @_more (err, delta) ->
                if err?
                    unless iterator(err) is false
                        _.delay f, 30000
                    return
                # Iterate over delta, and quit if false is explicitly returned
                (if iterator(el) is false then return) for el in delta
                # If you poll too quickly, you'll get a bunch of responses with
                # only a couple of entries. It's better to wait and reduce the
                # number of API calls.
                if delta.length < 90 then _.delay(f, 30000) else f()
        f()
        return

createStream = (args...) ->
    new Stream args...

_.extend exports, {Stream, createStream}
