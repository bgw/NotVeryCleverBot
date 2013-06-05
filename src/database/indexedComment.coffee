# Instead of storing an index of all comments, we only store a select number of
# comments meeting a certain set of criteria. It doesn't make sense to keep
# indexes of all the low scoring comments.

Q = require "q"
Sequelize = require "sequelize"

indexer = require "../transform/indexer"

exports.define = (sequelize) ->

    # Columns
    # -------

    body = Sequelize.TEXT

    # Class Methods
    # -------------

    # This must be called *after* the `Comment` has been created
    createFromJson = (json) ->
        {Comment} = require "./comment"
        Q.all([
            Q IndexedComment.findOrCreate
                body: indexer.rewrite(json.body)
            Q Comment.find
                where: {name: json.name}
        ])
        .spread (indexedCommentDao, commentDao) ->
            indexedCommentDao.addComment(commentDao).then(-> indexedCommentDao)

    # Define Model
    # ------------

    exports.IndexedComment = IndexedComment = sequelize.define "IndexedComment",
        {body},
        classMethods: {createFromJson}
