# All the comments we read from the API can be saved so that if we decide to
# change the rest of the database format later (likely), we can quickly rebuild.
# This takes a lot of disk space.

Q = require "q"
Sequelize = require "sequelize"

validators = "./validators"

exports.define = (sequelize) ->

    # Columns
    # -------

    name =
        type: Sequelize.STRING
        validate: validators.nameComment
        primaryKey: true

    json = Sequelize.TEXT

    # Class Methods
    # -------------

    createFromJson = (json) ->
        Q RawComment.create
            name: json.name
            json: JSON.stringify json

    # Define Model
    # ------------

    exports.RawComment = RawComment = sequelize.define "RawComment",
        {name, json},
        classMethods: {createFromJson}
