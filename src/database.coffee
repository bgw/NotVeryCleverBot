_ = require "underscore"
Q = require "q"
Sequelize = require "sequelize"
require "js-yaml"
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
    value: Sequelize.STRING
}, {
    classMethods:
        set: (key, value) ->
            Q(Metadata.find(where: {key: key}).then())
            .then (entry) ->
                if entry?
                    entry.value = value
                    return Q entry.save().then()
                else
                    return Q Metadata.create({key: key, value: value}).then()
        get: (key) ->
            Q Metadata.find(where: {key: key}).then((dao) -> dao?.value)
}

RawComment = null
if config.saveRawComments
    # All the comments we read from the API can be saved so that if we decide to
    # change the rest of the database format later (likely), we can quickly
    # rebuild. This takes a lot of disk space.
    RawComment = sequelize.define "RawComment", {
        name:
            type: Sequelize.STRING
            validate: validators.name
            primaryKey: true
        json: Sequelize.TEXT
    }, {
        classMethods:
            createFromJson: (json) ->
                Q(RawComment.create(
                    name: json.name,
                    json: JSON.stringify(json)
                ).then())
    }

Comment = sequelize.define "Comment", {
    name:
        type: Sequelize.STRING
        validate: validators.name
        primaryKey: true
    parentCommentName:
        type: Sequelize.STRING
        validate: validators.name
        allowNull: true # null iff we're root
        defaultValue: null
    articleName:
        type: Sequelize.STRING
        validate: validators.name
        allowNull: false
    body: Sequelize.TEXT
    score:
        type: Sequelize.INTEGER
        allowNull: true # `null` if unknown (not visible when scraped)
}, {
    classMethods:
        createFromJson: (json) ->
            Q.all(
                Q(Comment.create(
                    name: json.name,
                    parentCommentName:
                        if reddit.getThingType(json.parent_id) is "comment"
                            json.parent_id
                        else
                            null
                    articleName: json.link_id,
                    body: json.body,
                    score:
                        if json.score_hidden
                            null
                        else
                            json.ups - json.downs
                ).then()),
                # Find parents and children for associations
                Q(Article.find(
                    where: {name: json.link_id},
                    attributes: []
                ).then()),
                Q(Comment.find(
                    where: {name: json.parent_id}
                    attributes: []
                ).then()),
                Q(Comment.findAll(
                    where: {parentCommentName: json.name}
                    attributes: []
                ).then())
            )
            .spread((commentDao, articleDao, parentCommentDao, childrenDaos) ->
                # TODO: associations
                commentDao.setArticle articleDao
                commentDao.setParentComment parentCommentDao
                for ch in childrenDaos
                    ch.setParentComment commentDao
                return commentDao
            )
}

# Instead of storing an index of all comments, we only store a select number of
# comments meeting a certain set of criteria. It doesn't make sense to keep
# indexes of all the low scoring comments.
IndexedComment = sequelize.define "IndexedComment",
    body: Sequelize.TEXT

Article = sequelize.define "Article", {
    name:
        type: Sequelize.STRING
        validate: validators.name
        primaryKey: true
    title: Sequelize.STRING
    subreddit: Sequelize.STRING
    body: # selftext in markdown form
        type: Sequelize.TEXT
        allowNull: true
        defaultValue: null # null iff link post (not self)
    url: Sequelize.TEXT
    nsfw:
        type: Sequelize.BOOLEAN
        defaultValue: false
}, {
    classMethods:
        createFromJson: (json) ->
            Q(Article.create(
                name: json.name,
                title: json.title,
                subreddit: json.subreddit,
                body: json.selftext,
                url: json.url,
                nsfw: json.over_18
            ).then())
            .then((articleDao) ->
                for c in Comment.findAll(where: {articleName: json.name},
                                         attributes: [])
                    c.setArticle articleDao
                return articleDao
            )
}

# Associations
# ------------

# To reduce API requests, some of these associations may not always be
# satisfied. If that's the case, you'll need to make an API call using the
# supplied `parentCommentName`, `articleName`, etc. property
Article.hasMany Comment
Comment.belongsTo Article
Comment.hasOne Comment, as: "ParentComment"
IndexedComment.hasOne Comment

# Indices
# -------

# TODO: Figure out some way of doing this for `IndexedComment` (oddly there's
# not really a good way of doing this in sequelize yet)

# Initialization and Exports
# --------------------------

models = [Metadata, Article, Comment]
         .concat(if (r = RawComment)? then [r] else [])

init = ->
    Q.all(Q(m.sync().then()) for m in models)
    .then(->
        Metadata.get "version"
    )
    .then((oldVersion) ->
        if oldVersion?
            if oldVersion != VERSION
                throw TypeError "Database v#{oldVersion}, expected v#{VERSION}"
        else # new database
            Metadata.set("version", VERSION)
        return
    )

_.extend exports,
    Metadata: Metadata
    RawComment: RawComment
    Comment: Comment
    Article: Article
    models: models
    init: init
