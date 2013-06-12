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
    # Profiling
    if config.nodetime?
        (nodetime = require("nodetime")).profile(config.nodetime)
    # Initialization
    r = new Reddit config.botname, config.owner, version
    async.series [
        # Login
        _.bind r.login, r, config.username, config.password
        (cb) ->
            logger.info "Logged in as #{config.username}"
            cb null
        # Database initialization
        db.init
    ], (err) ->
        if err? then throw err
        commentCargo = async.cargo (comments, callback) ->
            async.parallel [
                _.bindKey db.RawComment?.bulkCreate(
                    _.map comments, _.bindKey db.RawComment, "partialFromJson"
                ), "done"
                _.bindKey db.Comment.bulkCreate(
                    _.map comments, _.bindKey db.Comment, "partialFromJson"
                ), "done"
                _.bindKey db.IndexedComment.bulkCreate(
                    _.map comments,
                          _.bindKey db.IndexedComment, "partialFromJson"
                ), "done"
            ], callback
        commentCargo.payload = 100
        # Process each new comment as it comes in
        r.commentStream().each (err, el) ->
            if error? then throw err
            nodetime?.metric "Reddit API", "Comments per Minute", 1, "", "inc"
            commentCargo.push el

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

