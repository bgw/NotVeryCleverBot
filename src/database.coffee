_ = require "underscore"
Q = require "q"
Sequelize = require "sequelize"
require "js-yaml"

logger = require "./logger"
reddit = require "./reddit"
config = require("../config.yaml").database

VERSION = "0.0.1"

config = _.defaults _.clone(config),
    dialect: "sqlite"
    saveRawComments: true
    define:
        timestamps: false
        charset: "utf8"
        collate: "utf8_general_ci"
    logging: logger.silly
sequelize = new Sequelize config.name, config.username, config.password,
                          config

# Model Definitions
# -----------------

Metadata = require("./database/metadata").define sequelize

RawComment = null
if config.saveRawComments
    RawComment = require("./database/rawComment").define sequelize

Comment = require("./database/comment").define sequelize
IndexedComment = require("./database/indexedComment").define sequelize
Article = require("./database/article").define sequelize

# Associations
# ------------

# To reduce API requests, some of these associations may not always be
# satisfied. If that's the case, you'll need to make an API call using the
# supplied `parentCommentName`, `articleName`, etc. property

Article.hasMany Comment
Comment.belongsTo Article
Comment.hasOne Comment, as: "ParentComment"
IndexedComment.hasMany Comment

# Initialization and Exports
# --------------------------

models = [Metadata, Article, Comment, IndexedComment]
         .concat(if (r = RawComment)? then [r] else [])

init = ->
    Q.all(Q(m.sync().then()) for m in models)
    .then(->
        # Indices
        # -------

    ).then(->
        Metadata.get "version"
    )
    .then((oldVersion) ->
        if oldVersion?
            if oldVersion != VERSION
                throw TypeError "Database v#{oldVersion}, expected v#{VERSION}"
        else
            logger.info "No previous database exists, making new one"
            Metadata.set("version", VERSION)

            # Sequelize doesn't have a good way to at indices. WTF.
            _queryInterface = sequelize.getQueryInterface()
            addIndex = _.bind(_queryInterface.addIndex, _queryInterface)
            addIndex "Metadata", ["key"], indicesType: "UNIQUE"
            addIndex "Articles", ["name"], indicesType: "UNIQUE"
            addIndex "Comments", ["name"], indicesType: "UNIQUE"
            addIndex "Comments", ["parentCommentName"]
            addIndex "Comments", ["articleName"]
        return
    )

_.extend exports,
    Metadata: Metadata
    RawComment: RawComment
    Comment: Comment
    IndexedComment: IndexedComment
    Article: Article
    models: models
    init: init
