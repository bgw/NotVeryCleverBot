# Provide a very simple key-value table for storing information about the
# database itself.

_ = require "lodash"
async = require "async"
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

    get = (key, callback) ->
        async.waterfall [
            _.bindKey Metadata.find(where: {key}), "done"
            (dao, cb) -> cb null, dao?.value
        ], callback

    set = (key, value, callback) ->
        async.waterfall [
            _.bindKey Metadata.find(where: {key}), "done"
            (entry, cb) ->
                if entry?
                    cb null, entry.updateAttributes {value}
                else
                    cb null, Metadata.create {key, value}
        ], callback

    # Define Model
    # ------------

    exports.Metadata = Metadata = sequelize.define "Metadata",
        {key, value},
        classMethods: {get, set}
