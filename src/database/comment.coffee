Sequelize = require "sequelize"

reddit = require "../reddit"
validators = require "./validators"
associations = require "./associations"
article = require "./article"

exports.define = (sequelize) ->

    # Columns
    # -------

    name =
        type: Sequelize.STRING
        validate: validators.nameComment
        primaryKey: true

    parentCommentName =
        type: Sequelize.STRING
        validate: validators.nameComment
        allowNull: true # null iff we're root
        defaultValue: null

    articleName =
        type: Sequelize.STRING
        validate: validators.nameArticle
        allowNull: false

    body = Sequelize.TEXT

    score =
        type: Sequelize.INTEGER
        allowNull: true # `null` if unknown (not visible when scraped)

    # Class Methods
    # -------------

    partialFromJson = (json) ->
        name: json.name,
        parentCommentName:
            if reddit.getThingType(json.parent_id) is "comment"
                json.parent_id
        articleName: json.link_id,
        body: json.body,
        score: unless json.score_hidden then json.ups - json.downs

    createFromJson = (json, callback=( -> )) ->
        Comment.create(@partialFromJson json).done callback

    # Instance Methods
    # ----------------

    getParentComment = associations.getOne ( -> Comment), ->
        where: {name: @parentCommentName}

    getChildren = associations.getMany ( -> Comment), ->
        where: {parentCommentName: @name}

    getArticle = associations.getOne ( -> article.Article), ->
        where: {name: @articleName}

    # Define Model
    # ------------

    exports.Comment = Comment = sequelize.define "Comment",
        {name, parentCommentName, articleName, body, score},
        classMethods: {partialFromJson, createFromJson}
        instanceMethods: {getParentComment, getChildren, getArticle}
