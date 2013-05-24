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
    r.commentStream({}).each (error, el) ->
        if error? then return console.error error
        #console.log prettyjson.render el
        # console.log el.created
