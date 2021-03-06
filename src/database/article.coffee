async = require "async"
_ = require "lodash"
Sequelize = require "sequelize"

validators = require "./validators"
associations = require "./associations"
comment = require "./comment"

exports.define = (sequelize) ->

    # Columns
    # -------

    name =
        type: Sequelize.STRING
        validate: validators.nameArticle
        primaryKey: true

    title = Sequelize.STRING

    subreddit = Sequelize.STRING

    body = # selftext in markdown form
        type: Sequelize.TEXT
        allowNull: true
        defaultValue: null # null iff link post (not self)

    url = Sequelize.TEXT

    nsfw =
        type: Sequelize.BOOLEAN
        defaultValue: false

    time = Sequelize.DATE

    # Class Methods
    # -------------

    partialFromJson = (json) ->
        name: json.name,
        title: json.title,
        subreddit: json.subreddit,
        body: json.selftext,
        url: json.url,
        nsfw: json.over_18
        time:
            _(new Date(0)).tap((d) -> d.setUTCSeconds json.created_utc).value()

    createFromJson = (json, callback=( -> )) ->
        Article.create(@partialFromJson json).done callback

    # Instance Methods
    # ----------------

    getComments = associations.getMany ( -> comment.Comment), ->
        where: {articleName: @name}

    # Define Model
    # ------------

    exports.Article = Article = sequelize.define "Article",
        {name, title, subreddit, body, url, nsfw, time},
        classMethods: {partialFromJson, createFromJson}
        instanceMethods: {getComments}
