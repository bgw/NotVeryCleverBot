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
analytics = require "./reddit/analytics"
apiError = require "./reddit/error"

# Static Utility Functions
# ------------------------
#
# These functions end up in the top-level exports *and* inside of
# `Reddit.prototype`.

statics = {}

statics.getThingType = (thing) ->
    if not thing? or thing[0] != "t"
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

# Use the `error` field in a more logical way. HTTP status codes and values in
# `body.json.errors` should all qualify as error values. All high level
# functions will use this automatically. It's up to you to use this if you call
# a low-level function like `get` or `post` yourself.
statics.apiErrors = (oldCallback) ->
    (error, response, body) ->
        if not response?
            error ?= new Error "Could not connect to server"
        else if response.statusCode != 200
            error ?= new (httperrors[response.statusCode])()
        else if body.json?.errors?.length
            error ?= apiError body.json.errors...
        oldCallback error, response, body

# In many places, the Reddit API will wrap the returned JSON value. This forms a
# new callback that unwraps it before passing
statics.unwrap = (key, callback) ->
    (error, response, body) ->
        if _.isObject(body) and _.has(body, key)
            callback error, response, body[key]
        else
            callback error, response, body

# Like unix's `tee` command, splits the result of one callback into multiple
statics.tee = (callbacks...) ->
    (args...) -> cb args... for cb in callbacks


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
        timeout: 60000 # 60 second timeout
    return undefined

_.extend Reddit.prototype, statics

for fname in ["get", "patch", "post", "put", "head", "del"]
    Reddit::[fname] = do (fname) -> (args...) ->
        @limiter.removeTokens 1, =>
            logger.verbose "HTTP #{fname.toUpperCase()}: #{args[0]}"
            @baseRequest[fname](args...)
        return this

Reddit::request = (args...) ->
    @limiter.removeTokens 1, => @baseRequest(args...)
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
        unless error?
            {@modhash, @cookie} = body.data
    # Submit data
    @post @resolve("login"), {form: form},
          @apiErrors(@unwrap("json", @tee(storeSession, callback)))

Reddit::me = (callback) ->
    @get @resolve("me.json"), @apiErrors(@unwrap("data", callback))

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
        @get url, {qs: innerOptions}, @apiErrors (error, response, body) ->
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

# Use <http://redditanalytics.com> for the comment stream source. The
# implementation may behave slightly differently, but it can save you a lot of
# API calls.
Reddit::commentStreamAnalytics = analytics.createCommentStream

# TODO: Special casing for `random`.
#
# `random` gives two `Listing` objects. The first is a one-element `Listing`
# with a link. The second is a `Listing` of comment replies to the parent link.
Reddit::random = ->
    throw new Error "not yet implemented"

exports = module.exports = Reddit
exports.Reddit = Reddit
_.extend exports, statics
