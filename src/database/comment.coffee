Q = require "q"
Sequelize = require "sequelize"

reddit = require "../reddit"
validators = require "./validators"

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

    createFromJson = (json) ->
        {Article} = require "./article"
        Q.all([
            Comment.create
                name: json.name,
                parentCommentName:
                    if reddit.getThingType(json.parent_id) is "comment"
                        json.parent_id
                articleName: json.link_id,
                body: json.body,
                score: unless json.score_hidden then json.ups - json.downs
            # Find parents and children for associations
            Article.find
                where: {name: json.link_id},
                attributes: []
            Comment.find
                where: {name: json.parent_id}
                attributes: []
            Comment.findAll
                where: {parentCommentName: json.name}
                attributes: []
        ])
        .spread (commentDao, articleDao, parentCommentDao, childrenDaos) ->
            # Determine which operations to perform
            ops = []
            if articleDao?
                ops.push commentDao.setArticle articleDao
            if parentCommentDao?
                ops.push commentDao.setParentComment parentCommentDao
            for ch in (childrenDaos || [])
                ops.push ch.setParentComment commentDao
            # Perform them all in parallel
            Q.all(ops).then -> commentDao

    # Define Model
    # ------------

    exports.Comment = Comment = sequelize.define "Comment",
        {name, parentCommentName, articleName, body, score},
        classMethods: {createFromJson}
