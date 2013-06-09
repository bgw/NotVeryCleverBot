_ = require "lodash"
_s = require "underscore.string"

_errorCache = {}
_extendError = (type) ->
    type = _s.camelize type
    if type in _errorCache
        return _errorCache[type]
    else
        Err = (@message, @field, @extra...) ->
            @type = type
        Err.prototype = new Error()
        Err::constructor = Err
        _errorCache[type] = Err
        return Err

getError = (args) ->
    if _.isString args
        return _extendError args
    else
        [type, args...] = args
        return new _extendError(type)(args...)

_typeList = [
    "USER_REQUIRED"
    "HTTPS_REQUIRED"
    "VERIFIED_USER_REQUIRED"
    "NO_URL"
    "BAD_URL"
    "BAD_CAPTCHA"
    "BAD_USERNAME"
    "USERNAME_TAKEN"
    "USERNAME_TAKEN_DEL"
    "USER_BLOCKED"
    "NO_THING_ID"
    "TOO_MANY_THING_IDS"
    "NOT_AUTHOR"
    "NOT_USER"
    "LOGGED_IN"
    "DELETED_LINK"
    "DELETED_COMMENT"
    "DELETED_THING"
    "BAD_PASSWORD"
    "WRONG_PASSWORD"
    "BAD_PASSWORD_MATCH"
    "NO_NAME"
    "NO_EMAIL"
    "NO_EMAIL_FOR_USER"
    "NO_TO_ADDRESS"
    "NO_SUBJECT"
    "USER_DOESNT_EXIST"
    "NO_USER"
    "INVALID_PREF"
    "BAD_NUMBER"
    "BAD_STRING"
    "BAD_BID"
    "ALREADY_SUB"
    "SUBREDDIT_EXISTS"
    "SUBREDDIT_NOEXIST"
    "SUBREDDIT_NOTALLOWED"
    "SUBREDDIT_REQUIRED"
    "BAD_SR_NAME"
    "RATELIMIT"
    "QUOTA_FILLED"
    "SUBREDDIT_RATELIMIT"
    "EXPIRED"
    "DRACONIAN"
    "BANNED_IP"
    "BAD_CNAME"
    "USED_CNAME"
    "INVALID_OPTION"
    "CHEATER"
    "BAD_EMAILS"
    "NO_EMAILS"
    "TOO_MANY_EMAILS"
    "OVERSOLD"
    "BAD_DATE"
    "BAD_DATE_RANGE"
    "DATE_RANGE_TOO_LARGE"
    "BAD_FUTURE_DATE"
    "BAD_PAST_DATE"
    "BAD_ADDRESS"
    "BAD_CARD"
    "TOO_LONG"
    "NO_TEXT"
    "INVALID_CODE"
    "CLAIMED_CODE"
    "NO_SELFS"
    "NO_LINKS"
    "TOO_OLD"
    "BAD_CSS_NAME"
    "BAD_CSS"
    "BAD_REVISION"
    "TOO_MUCH_FLAIR_CSS"
    "BAD_FLAIR_TARGET"
    "OAUTH2_INVALID_CLIENT"
    "OAUTH2_INVALID_REDIRECT_URI"
    "OAUTH2_INVALID_SCOPE"
    "OAUTH2_INVALID_REFRESH_TOKEN"
    "OAUTH2_ACCESS_DENIED"
    "CONFIRM"
    "CONFLICT"
    "NO_API"
    "DOMAIN_BANNED"
    "NO_OTP_SECRET"
    "NOT_SUPPORTED"
    "BAD_IMAGE"
    "DEVELOPER_ALREADY_ADDED"
    "TOO_MANY_DEVELOPERS"
    "BAD_HASH"
    "ALREADY_MODERATOR"
    "NO_INVITE_FOUND"
    "BID_LIVE"
    "TOO_MANY_CAMPAIGNS"
    "BAD_JSONP_CALLBACK"
    "INVALID_PERMISSION_TYPE"
    "INVALID_PERMISSIONS"
]

module.exports = getError
for t in _typeList
    exports[_s.camelize t] = getError t
