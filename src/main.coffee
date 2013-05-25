# Does nothing yet, except tests API wrapper

_ = require "underscore"
require "js-yaml"
prettyjson = require "prettyjson"
config = require "../config.yaml"
version = require("../package.json").version
reddit = require "./reddit"

r = new reddit.Reddit config.botname, config.owner, version
r.login config.username, config.password, false, (error, response, body) ->
    if error
        throw error
    if body.errors?.length
        console.error body.errors
        return
    console.log "Logged in as #{config.username}"
    r.me (error, response, data) ->
        console.log "The API says my name is #{data.name}"
    counter = 0
    r.comments(subreddit: "funny", limit: 120).each (error, el) ->
        console.log "--- #{++counter}"
        console.log prettyjson.render el
