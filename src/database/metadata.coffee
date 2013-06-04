# Provide a very simple key-value table for storing information about the
# database itself.

Q = require "q"
Sequelize = require "sequelize"

exports.define = (sequelize) ->

    # Columns
    # -------

    key =
        type: Sequelize.STRING
        primaryKey: true
        unique: true

    value = Sequelize.STRING

    # Class Methods
    # -------------

    get = (key) ->
        Q Metadata.find(where: {key}).then((dao) -> dao?.value)

    set = (key, value) ->
        Q(Metadata.find where: {key})
        .then (entry) ->
            if entry?
                Q entry.updateAttributes {value}
            else
                Q Metadata.create {key, value}

    # Define Model
    # ------------

    exports.Metadata = Metadata = sequelize.define "Metadata",
        {key, value},
        classMethods: {get, set}
