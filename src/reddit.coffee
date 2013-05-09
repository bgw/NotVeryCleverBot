# This is a wrapper around restler to provide nice convenience functions for
# working with the Reddit API. It'll be fleshed out as needed.
#
# Primary goals are related to ensuring [all API rules and
# suggestions](https://github.com/reddit/reddit/wiki/API) are followed.

_ = require "underscore"
url = require "url"
request = require "request"
limiter = require "limiter"
baseVersion = require("../package.json")?.version

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
    # Reddit suggests only polling 30 times/minute (at most)
    @limiter = new limiter.RateLimiter 30, "minute"
    # Build our custom request functions
    @baseRequest = request.defaults
        jar: request.jar()
        json: true
        headers:
            "User-Agent": uaString
            "Client": "'; DROP TABLE clienttypes; --" # Super important
    return undefined

# Throttling
# ----------

for fname in ["get", "patch", "post", "put", "head", "del"]
    Reddit::[fname] = do (fname) -> () ->
        args = _.toArray(arguments)
        @limiter.removeTokens 1, =>
            @baseRequest[fname].apply @baseRequest, args

Reddit::request = ->
    args = _.toArray(arguments)
    @limiter.removeTokens 1, => @baseRequest.apply @, args

# Non-Static Utilities
# --------------------
#
# These functions provide general sugar for common tasks, but probably aren't
# useful on their own.

Reddit::resolve = (path) ->
    url.resolve @baseURL, path

# Individual Wrapper Functions
# ----------------------------
#
# These functions simply transform arguments and call the underlying RESTful
# function. Callbacks are always in `request` form: `(error, response, body)`.
#
# Refer to <http://www.reddit.com/dev/api> for documentation.

# Returns: `{errors: [...], data: {modhash: string, cookie: string}}`
Reddit::login = (username, password, rem, callback) ->
    # Transform arguments
    form =
        user: username
        passwd: password
        rem: !!rem
        api_type: "json"
    # Store session
    storeSession = (error, response, body) =>
        if !error? and !body.errors?.length
            {@modhash, @cookie} = body.data
    # Submit data
    @post @resolve("login"), {form: form},
          @unwrap("json", @tee(storeSession, callback))

# Returns:
#
#     comment_karma: integer
#     created: integer
#     created_utc: integer # same as created
#     has_mail: boolean
#     has_mod_mail: boolean
#     has_verified_email: boolean
#     id: string
#     is_friend: boolean
#     is_gold: boolean
#     is_mod: boolean
#     link_karma: integer
#     modhash: string
#     name: string
#     over_18: boolean
Reddit::me = (callback) ->
    @get @resolve("me.json"), @unwrap("data", callback)

exports.Reddit = Reddit

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

# In many places, the reddit API will wrap the returned JSON value. This forms a
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

_.extend Reddit::, statics
_.extend exports, statics
