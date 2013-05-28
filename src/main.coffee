# Does nothing yet, except tests API wrapper

_ = require "underscore"
Q = require "q"
require "js-yaml"
prettyjson = require "prettyjson"

config = require "../config.yaml"
version = require("../package.json").version
reddit = require "./reddit"
database = require "./database"

r = new reddit.Reddit config.botname, config.owner, version
Q.ninvoke(r, "login", config.username, config.password)
.spread((response, body) ->
    console.log "Logged in as #{config.username}"
    counter = 0
)
.then(database.init)
.done(->
    counter = 0
    r.commentStream({}).each (error, el) ->
        console.log "--- #{++counter}"
        console.log prettyjson.render el
)
