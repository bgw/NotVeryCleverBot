_ = require "underscore"
Q = require "q"
Sequelize = require "sequelize"
require "js-yaml"
config = require("../config.yaml").database

VERSION = "0.0.1"

config = _.defaults _.clone(config),
    dialect: "sqlite"
    saveRawComments: true
    define:
        timestamps: false
        charset: "utf8"
        collate: "utf8_general_ci"
sequelize = new Sequelize config.name, config.username, config.password,
                          config

# Model Definitions
# -----------------

validators =
    name:
        is: /t[0-9]+_[a-z0-9]+/

Metadata = sequelize.define "Metadata", {
    key:
        type: Sequelize.STRING
        primaryKey: true
        unique: true
    value:
        type: Sequelize.STRING
}, {
    classMethods:
        set: (key, value) ->
            Q(Metadata.find(where: {key: key}).then())
            .then (entry) ->
                entry.value = value
        get: (key) ->
            Q(Metadata.find(where: {key: key}).then())
}

RawComment = null
if config.saveRawComments
    # All the comments we read from the API can be saved so that if we decide to
    # change the rest of the database format later (likely), we can quickly
    # rebuild. This takes a lot of disk space.
    RawComment = sequelize.define "RawComment",
        name:
            type: Sequelize.STRING
            validate: validators.name
            primaryKey: true
        json: Sequelize.TEXT

Comment = sequelize.define "Comment",
    name:
        type: Sequelize.STRING
        validate: validators.name
        primaryKey: true
    parent: # The parent may be another comment *or* an article (check the type)
        type: Sequelize.STRING
        validate: validators.name
        allowNull: false
    body: Sequelize.TEXT
    score:
        type: Sequelize.INTEGER
        allowNull: true # `null` if unknown (not visible when scraped)

# Instead of storing an index of all comments, we only store a select number of
# comments meeting a certain set of criteria. It doesn't make sense to keep
# indexes of all the low scoring comments.
IndexedComment = sequelize.define "IndexedComment",
    body: Sequelize.TEXT

Article = sequelize.define "Article",
    name:
        type: Sequelize.STRING
        validate: validators.name
        primaryKey: true
    title: Sequelize.STRING
    subreddit: Sequelize.STRING
    body:
        type: Sequelize.TEXT
        allowNull: true
        defaultValue: null

# Associations
# ------------

Article.hasMany Comment
Comment.belongsTo Article
IndexedComment.hasOne Comment

# Indices
# -------

# TODO: Figure out some way of doing this for `IndexedComment` (oddly there's
# not really a good way of doing this in sequelize yet)

# Initialization and Exports
# --------------------------

models = [Metadata, Article, Comment]
         .concat(if (r = RawComment)? then r else [])

init = -> Q.all(Q(m.sync().then()) for m in models)

_.extend exports,
    Metadata: Metadata
    RawComment: RawComment
    Comment: Comment
    Article: Article
    models: models
    init: init
