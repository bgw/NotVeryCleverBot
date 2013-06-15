_ = require "lodash"
async = require "async"
program = require "commander"
require "js-yaml"

config = require "../config.yaml"
version = require("../package.json").version
logger = require "./logger"
Reddit = require "./reddit"
db = require "./database"
dbOp = require "./database/operations"

logErr = (err) ->
    unless err? then return
    logger.error "exception: #{err.message}" +
                 if err.stack? then "\n#{err.stack}" else ""

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

    # Processing
    ], (err) ->
        if err? then return logErr err
        commentCargo = async.cargo (comments, callback) ->
            tasks = [
                _.partial dbOp(db.Comment).replace,
                    _.map comments, (c) -> db.Comment.partialFromJson c
                _.partial dbOp(db.IndexedComment).replace,
                    _.map comments, (c) -> db.IndexedComment.partialFromJson c
            ]
            if db.RawComment?
                tasks.push _.partial dbOp(db.RawComment).replace,
                    _.map comments, (c) -> db.RawComment.partialFromJson c
            async.parallel tasks, callback
        commentCargo.payload = 100
        # Process each new comment as it comes in
        r.commentStream().each (err, el) ->
            if err? then return logErr err
            nodetime?.metric "Reddit API", "Comments per Minute", 1, "", "inc"
            commentCargo.push el, logErr

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

