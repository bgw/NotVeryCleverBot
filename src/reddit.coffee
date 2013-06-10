# This is a wrapper around restler to provide nice convenience functions for
# working with the Reddit API. It'll be fleshed out as needed.
#
# Primary goals are related to ensuring [all API rules and
# suggestions](https://github.com/reddit/reddit/wiki/API) are followed.

_ = require "lodash"
resolve = require("url").resolve
request = require "request"
httperrors = require "httperrors"
limiter = require "limiter"

logger = require "./logger"
baseVersion = require("../package.json")?.version
listing = require "./reddit/listing"
stream = require "./reddit/stream"
redditError = require "./reddit/error"

# Static Utility Functions
# ------------------------
#
# These functions end up in the top-level exports *and* inside of
# `Reddit.prototype`.

statics = {}

statics.getThingType = (thing) ->
    if thing[0] != "t"
        throw new RangeError "A thing should begin with 't' character"
    types = ["comment", "account", "link", "message", "subreddit"]
    return types[(+thing[1]) - 1]

statics._getCommentsPath = ({article, subreddit}) ->
    if article?
        return "/comments/#{article}.json"
    else if subreddit?
        return "/r/#{subreddit}/comments.json"
    else
        return "/comments.json"

# In many places, the Reddit API will wrap the returned JSON value. This forms a
# new callback that unwraps it before passing
statics.unwrap = (key, callback) ->
    (error, response, body) ->
        if _.isObject(body) and {}.hasOwnProperty.call(body, key)
            callback error, response, body[key]
        else
            callback error, response, body

# Like unix's `tee` command, splits the result of one callback into multiple
statics.tee = (callbacks...) ->
    (args...) -> cb args... for cb in callbacks


# Throttling and Error Handling
# -----------------------------
#
# This provides throttling (to comply with API rules), and turns non-200 HTTP
# status codes into errors. For some applications it doesn't make sense to
# perform error handling like this, but for a JSON API it's simpler.

_transformCallback = (emitter) ->
    rewrite = (oldCallback) -> (error, response, body) ->
        if response.statusCode != 200
            error = new httperrors[response.statusCode]()
        else if body.json?.errors?.length
            error = redditError body.json.errors[0]
        oldCallback error, response, body
    # Rewrite the listeners already set up by `request`
    # TODO: Handle this better somehow (and handle `body.errors`)
    emitter.removeAllListeners "complete"
    if emitter.callback?
        emitter.callback = rewrite _.bind(emitter.callback, emitter)
        emitter.on "complete", _.partial(emitter.callback, null)


# Reddit Class Definition
# -----------------------

Reddit = (@appname, @owner, @version) ->
    @baseURL = "http://www.reddit.com/api/"
    # Configure useragent as recommended by Reddit
    @appname ?= "unknown/nodejs"
    @owner ?= "unknown"
    @version ?= baseVersion
    uaString = "#{@appname} by /u/#{@owner}"
    if @version?
        uaString = "#{@appname} v#{@version} by /u/#{@owner}"
    # Session information (if logged in)
    @modhash = undefined
    @cookie = undefined
    # Reddit suggests only polling once every two seconds (at most)
    @limiter = new limiter.RateLimiter 30, "minute"
    # Build our custom request functions
    @baseRequest = request.defaults
        jar: request.jar()
        json: true
        headers:
            "User-Agent": uaString
            "Client": "'; DROP TABLE clienttypes; --" # Super important
    return undefined

_.extend Reddit.prototype, statics

for fname in ["get", "patch", "post", "put", "head", "del"]
    Reddit::[fname] = do (fname) -> (args...) ->
        @limiter.removeTokens 1, =>
            logger.verbose "HTTP #{fname.toUpperCase()}: #{args[0]}"
            _transformCallback @baseRequest[fname](args...)
        return this

Reddit::request = (args...) ->
    @limiter.removeTokens 1, =>
        _transformCallback @baseRequest(args...)
    return this

# Non-Static Utilities
# --------------------
#
# These functions provide general sugar for common tasks, but probably aren't
# useful on their own.

Reddit::resolve = (path) ->
    resolve @baseURL, path

Reddit::subredditResolve = (subreddit, path) ->
    @resolve "#{if subreddit? then "/r/#{subreddit}/" else "/"}#{path}.json"

# Supplies a default `subreddit` key to subreddit-specific calls. Also sets a
# `@subreddit` property in the subclass.
Reddit::subreddit = (subreddit) ->
    parent = this
    SubReddit = ->
        # Functions we want to wrap
        flist = ["hot", "new", "top", "controversial"]
        flist.push("#{fname}Stream") for fname in flist
        # Special cases
        flist.push "random", "comments", "commentStream"
        # Wrap functions providing a the default subreddit
        for fname in flist
            @[fname] = (options, callback) ->
                parent[fname] _.defaults(options, subreddit: subreddit),
                              callback
        @subreddit = subreddit
        return
    SubReddit.prototype = this
    return new SubReddit()

# Individual Wrapper Functions
# ----------------------------
#
# These functions simply transform arguments and call the underlying RESTful
# function. Callbacks are always in `request` form: `(error, response, body)`.
#
# -   Refer to <http://www.reddit.com/dev/api> for method documentation.
# -   Refer to <https://github.com/reddit/reddit/wiki/JSON> for information on
#     return types

Reddit::login = (username, password, rem, callback) ->
    # Transform arguments
    if not callback? and _.isFunction rem
        callback = rem
        rem = false
    form =
        user: username
        passwd: password
        rem: !!rem
        api_type: "json"
    # Store session
    storeSession = (error, response, body) =>
        unless error? or body.errors?.length
            {@modhash, @cookie} = body.data
    # Submit data
    @post @resolve("login"), {form: form},
          @unwrap("json", @tee(storeSession, callback))

Reddit::me = (callback) ->
    @get @resolve("me.json"), @unwrap("data", callback)

# Helper functions for listing and stream based APIs
_listingStream = (isStream, fname, options) ->
    options ?= {}
    creator = if isStream then stream.createStream else listing.createListing
    creator options, (innerOptions, cb) =>
        _.defaults innerOptions, options
        if _.isFunction fname
            url = @resolve fname(innerOptions)
        else
            url = @subredditResolve innerOptions.subreddit, fname
        @get url, {qs: innerOptions}, (error, response, body) ->
            cb error, body

Reddit::_listing = _.partial _listingStream, false
Reddit::_stream = _.partial _listingStream, true

# Simple "static" listings. These paths are affected only by subreddit.
for fname in ["hot", "new", "top", "controversial"]
    Reddit::[fname] = _.partial Reddit::_listing, fname
    Reddit::["#{fname}Stream"] = _.partial Reddit::_stream, fname

# Comments have different API paths depending on article or subreddit.
Reddit::comments = _.partial Reddit::_listing, statics._getCommentsPath
Reddit::commentStream = _.partial Reddit::_stream, statics._getCommentsPath

# TODO: Special casing for `random`.
#
# `random` gives two `Listing` objects. The first is a one-element `Listing`
# with a link. The second is a `Listing` of comment replies to the parent link.
Reddit::random = ->
    throw new Error "not yet implemented"

exports = module.exports = Reddit
exports.Reddit = Reddit
_.extend exports, statics
