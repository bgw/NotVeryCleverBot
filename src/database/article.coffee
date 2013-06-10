async = require "async"
_ = require "lodash"
Sequelize = require "sequelize"

validators = require "./validators"

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

    # Class Methods
    # -------------

    createFromJson = (json, callback) ->
        {Comment} = require "./comment"
        async.parallel [
            _.bindKey Article.create(
                name: json.name,
                title: json.title,
                subreddit: json.subreddit,
                body: json.selftext,
                url: json.url,
                nsfw: json.over_18
            ), "done"
            _.bindKey Comment.findAll(
                where: {articleName: json.name},
                attributes: []
            ), "done"
        ], (err, articleDao, commentDaos) ->
            if err? then return callback? err
            async.each (commentDaos || []),
                       ((dao, cb) -> dao.setArticle(articleDao).done cb),
                       ( -> callback? null, articleDao)

    # Define Model
    # ------------

    exports.Article = Article = sequelize.define "Article",
        {name, title, subreddit, body, url, nsfw},
        classMethods: {createFromJson}
