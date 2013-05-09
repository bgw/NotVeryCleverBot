# Does nothing yet, except tests API wrapper

_ = require "underscore"
require "js-yaml"
config = require "../config.yaml"
version = require("../package.json").version
reddit = require "./reddit"

r = new reddit.Reddit config.botname, config.owner, version
r.login(config.username, config.password).on "complete", (data) ->
    data = data.json
    if data.errors?.length
        console.error data.errors
        return
    console.log "Logged in as #{config.username}"
    r.me().on "complete", ({errors, kind, data}) ->
        console.log "The API says my name is #{data.name}"
