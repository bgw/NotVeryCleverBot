# Provide data from <http://redditanalytics.com>

_ = require "lodash"
Lazy = require "lazy.js"
request = require "request"
nodeStream = require "stream"
logger = require "../logger"

class CommentStream extends Lazy.Sequence
    constructor: (options={}) ->
        {@subreddit} = options
        @_tempBuffer = ""

    # Force a reload of the stream if the connection drops out
    _reload: ->
        logger.verbose "Reloading redditanalytics comment stream"
        @httpStream?.removeAllListeners()
        # Build our querystring.
        query = {}
        if @subreddit? then query.subreddit = @subreddit
        # Make the http request.
        @httpRequest = request.get(
            "http://redditanalytics.com/stream/",
            qs: query, timeout: 30000
        )
        # Pipe results into a stream
        @httpStream = new nodeStream.PassThrough encoding: "utf8"
        @httpRequest.pipe @httpStream
        # Handle "end" and "error" events.
        onEnd = =>
            logger.warn "Redditanalytics comment stream was closed."
            @_tempBuffer += "\n"
            # An error might be about to propogate. Short-circuit in that case.
            try
                result = JSON.parse @_tempBuffer
            catch discard
                discard # I'm real tired of your shit, coffeelint.
            # Allow the rest of `@_tempBuffer` to be read
            @httpStream.emit "readable", ""
            unless result?.error
                # Use a defer to allow other event listeners to propogate
                _.defer => @_reload()
        onError = (error) =>
            logger.warn "Redditanalytics comment stream threw: #{error.message}"
            @_tempBuffer = ""
            # We don't need both handlers on an error
            @httpRequest.removeListener "end", onEnd
            @httpRequest.end()
            # Use a delay to avoid spamming the server if we're broken
            _.delay ( => @_reload()), 30000
        @httpRequest.once("end", onEnd).once("error", onError)
        @_onReload?()

    # Kill the http connection and keep it from reloading.
    end: ->
        @httpRequest?.removeAllListeners()
        @httpStream?.removeAllListeners()
        @_onReload = null
        @httpRequest?.end()

    each: (iterator) ->
        # The `@httpStream` might get destroyed if the connection drops. We have
        # to set up our listeners again if that happens.
        boundHelper = _.bind @_each, this, iterator
        @_onReload = ->
            @httpStream.on("readable", boundHelper).on("error", iterator)
        @_reload()

    _each: (iterator) ->
        # Read from the server.
        buffer = @_tempBuffer + @httpStream.read()
        # Each object is separated by a newline.
        jsonList = buffer.split "\n"
        # Discard any partial objects.
        @_tempBuffer = jsonList.pop()
        # Call the iterator over each recovered element.
        for el in jsonList
            if el is "" then continue
            try
                decoded = JSON.parse el
            catch decoded
                decoded # Screw you too, coffeelint.
            # Redditanalytics might give us an error message
            if decoded.error?
                return @httpRequest.emit "error", new Error decoded.error
            if iterator(decoded) is false
                return @end()
        # Try to fetch more data.
        @httpStream.read 0

createCommentStream = (args...) ->
    new CommentStream args...

_.extend exports, {CommentStream, createCommentStream}
