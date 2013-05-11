# Does nothing yet, except tests API wrapper

_ = require "underscore"
require "js-yaml"
prettyjson = require "prettyjson"
config = require "../config.yaml"
version = require("../package.json").version
reddit = require "./reddit"

r = new reddit.Reddit config.botname, config.owner, version
r.login config.username, config.password, false, (error, response, body) ->
    if body.errors?.length
        console.error error
        console.error body.errors
        return
    console.log "Logged in as #{config.username}"
    r.me (error, response, data) ->
        console.log "The API says my name is #{data.name}"
    r.top {t: "all", limit: 10000}, (error, listing) ->
        if error? then return console.error error
        listing.eachAsync (el) ->
            console.log prettyjson.render el
