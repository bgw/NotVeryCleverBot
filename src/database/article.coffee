Q = require "q"
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

    createFromJson = (json) ->
        {Comment} = require "./comment"
        Q.all([
            Article.create
                name: json.name,
                title: json.title,
                subreddit: json.subreddit,
                body: json.selftext,
                url: json.url,
                nsfw: json.over_18
            Comment.findAll
                where: {articleName: json.name},
                attributes: []
        ])
        .spread (articleDao, commentDaos) ->
            Q.all(c.setArticle(articleDao).then() for c in (commentDaos || []))
            .then(-> articleDao)

    # Define Model
    # ------------

    exports.Article = Article = sequelize.define "Article",
        {name, title, subreddit, body, url, nsfw},
        classMethods: {createFromJson}
