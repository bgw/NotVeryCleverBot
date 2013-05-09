# This is a wrapper around restler to provide nice convenience functions for
# working with the Reddit API. It'll be fleshed out as needed.
#
# Primary goals are related to ensuring [all API rules and
# suggestions](https://github.com/reddit/reddit/wiki/API) are followed.

_ = require "underscore"
rest = require "restler"
limiter = require "limiter"
baseVersion = require("../package.json")?.version

# Core Reddit Api Wrapper
# -----------------------

constructor = (@appname, @owner, @version) ->
    # Make sure headers aren't undefined
    @defaults.headers ?= {}
    # Configure useragent as recommended by Reddit
    @appname ?= "unknown"
    @owner ?= "unknown"
    @version ?= baseVersion
    uaString = "#{@appname} by /u/#{@owner}"
    if @version?
        uaString = "#{@appname} v#{@version} by /u/#{@owner}"
    _.extend @defaults.headers, "User-Agent": uaString
    # Reddit suggests only polling 30 times/minute (at most)
    @limiter = new limiter.RateLimiter 30, "minute"
    # Session information (if logged in)
    @modhash = undefined
    @cookie = undefined
    # Super important header: needed to hack the Gibson
    _.extend @defaults.headers, "Client": "'; DROP TABLE clienttypes; --"
    # Javascript doesn't like constructors to return stuff
    return undefined

defaults =
    baseURL: "http://www.reddit.com/api/"
    parser: rest.parsers.json

# Wrappers around Reddit's api functions. Refer to
# <http://www.reddit.com/dev/api> for documentation
methods =

    # Returns: `{errors: [...], data: {modhash: string, cookie: string}}`
    login: (username, password, rem) ->
        # Transform arguments
        data =
            user: username
            passwd: password
            rem: !!rem
            api_type: "json"
        # Submit data
        r = @post "login", data: data
        # Handle newly created session
        r.on "complete", (data) =>
            data = data.json
            if data.errors?.length then return
            {@modhash, @cookie} = data.data # unpack
            _.extend @defaults.headers, "Cookie": "reddit_session=#{@cookie}"

    # Returns:
    #
    #     kind: "t2"
    #     data:
    #         comment_karma: integer
    #         created: integer
    #         created_utc: integer # same as created
    #         has_mail: boolean
    #         has_mod_mail: boolean
    #         has_verified_email: boolean
    #         id: string
    #         is_friend: boolean
    #         is_gold: boolean
    #         is_mod: boolean
    #         link_karma: integer
    #         modhash: string
    #         name: string
    #         over_18: boolean
    me: -> @get "me.json"

exports.Reddit = Reddit = rest.service constructor, defaults, methods

# Wrap network functions to throttle according to reddit limits.
# This is a hackish set of monkey-patches.
for fname in ["request", "get", "patch", "put", "post", "json", "postJson", "del"]
    # Store the old function, we'll need to call it inside our new one
    oldFunction = Reddit::[fname]
    # Write the new one
    Reddit::[fname] = do (oldFunction) -> ->
        # Quickly wrap and unwrap restler's `request` function
        # <https://github.com/danwrong/restler/blob/2c016e/lib/restler.js#L301>
        oldRequest = rest.request
        rest.request = (url, options) ->
            req = new rest.Request url, options
            req.on "error", (->)
            @limiter.removeTokens 1, req.run.bind(req)
            return req
        r = oldFunction.apply @, _.toArray(arguments)
        # Restore `request` function
        rest.request = oldRequest
        # Return the `Request` object
        return r

# Static Utility Functions
# ------------------------

exports.getThingType = getThingType = (thing) ->
    if thing[0] != "t"
        throw new RangeError "A thing should begin with 't' character"
    types = ["comment", "account", "link", "message", "subreddit"]
    return types[parseInt(thing[1], 10) - 1]
