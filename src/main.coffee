_ = require "lodash"
async = require "async"
program = require "commander"
require "js-yaml"

config = require "../config.yaml"
version = require("../package.json").version
logger = require "./logger"
Reddit = require "./reddit"
db = require "./database"

main = (config) ->
    r = new Reddit config.botname, config.owner, version
    async.waterfall [
        _.bind r.login, r, config.username, config.password
        (response, body, callback) ->
            logger.info "Logged in as #{config.username}"
            callback null
        (args..., cb) -> db.init cb
    ], (err) ->
        if err? then throw err
        # Process each new comment as it comes in
        r.commentStream().each (err, el) ->
            if error? then throw err
            db.RawComment?.createFromJson(el).done()
            db.Comment.createFromJson(el)
                .then(-> db.IndexedComment.createFromJson(el))
                .done()
        r.newStream().each (err, el) ->
            if err? then throw err
            db.Article.createFromJson el

program
    .version(version)
    .option("-u, --username [name]", "Username of bot's reddit account")
    .option("-o, --owner [name]", "Your username")
    .option("-n, --botname [name]", "Bot's name for useragent string")
    .parse(process.argv)
config = _.defaults _.clone(config),
                    _.pick(program, "username", "owner", "botname")

unless config.password?
    program.password "password: ", (password) ->
        config.password = password
        main config
else
    main config

