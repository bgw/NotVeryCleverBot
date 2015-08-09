# Provide a very simple key-value table for storing information about the
# database itself.

dbOps = require "./operations"

exports.define = (knex) ->
    knex.schema.createTable "metadata", (table) ->
        table.string("key").unique().primary().index()
        table.text "value"
    exports.get = (key) ->
        knex.select().from("metadata").where({key}).then (rows) -> rows[0].value
    exports.set = (key, value) ->
        dbOps.upsert knex, knex.insert({key, value}).into("metadata")
