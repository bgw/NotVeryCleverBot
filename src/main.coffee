_ = require "underscore"
Q = require "q"
require "js-yaml"
prettyjson = require "prettyjson"

config = require "../config.yaml"
version = require("../package.json").version
logger = require "./logger"
reddit = require "./reddit"
db = require "./database"

r = new reddit.Reddit config.botname, config.owner, version
Q.ninvoke(r, "login", config.username, config.password)
.spread((response, body) ->
    logger.info "Logged in as #{config.username}"
)
.then(db.init)
.then ->
    # Process each new comment as it comes in
    r.commentStream({}).each (error, el) ->
        if error? then logger.error error
        if db.RawComment? then db.RawComment.createFromJson el
        db.Comment.createFromJson el
    r.newStream({}).each (error, el) ->
        if error? then logger.error error
        db.Article.createFromJson el
