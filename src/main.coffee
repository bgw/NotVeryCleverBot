_ = require "underscore"
Q = require "q"
program = require "commander"
require "js-yaml"

config = require "../config.yaml"
version = require("../package.json").version
logger = require "./logger"
reddit = require "./reddit"
db = require "./database"

main = (config) ->
    r = new reddit.Reddit config.botname, config.owner, version
    Q.ninvoke(r, "login", config.username, config.password)
    .spread((response, body) ->
        logger.info "Logged in as #{config.username}"
    )
    .then(db.init)
    .done ->
        # Process each new comment as it comes in
        r.commentStream({}).each (error, el) ->
            if error? then logger.error error
            if db.RawComment?
                db.RawComment.createFromJson(el).done()
            db.Comment.createFromJson(el)
                .then(-> db.IndexedComment.createFromJson(el))
                .done()
        r.newStream({}).each (error, el) ->
            if error? then logger.error error
            db.Article.createFromJson(el).done()

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

