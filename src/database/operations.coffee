# Attempts to provide some operations that sequelize doesn't that we'd like to
# use. Some behaviors may be slightly different between database dialects, but a
# best-effort is made to ensure consistancy.

_ = require "lodash"

queryFactories =
    mysql:
        # REPLACE works exactly like INSERT, except that if an old row in the
        # table has the same value as a new row for a PRIMARY KEY or a UNIQUE
        # index, the old row is deleted before the new row is inserted.
        replace: (daoFactory, obj, args...) ->
            callback = if _.isFunction _.last(args) then args.pop() else ( -> )
            # We may be called with multiple arguments or an array of objects
            objList = if _.isArray obj then obj else [obj].concat args
            # Rewrite objList into
            #     keys = [key1, key2]
            #     values = [[value1a, value2a], [value1b, value2b]]
            # which is the ordering MySql expects. The problem is that each
            # object may have a different iteration ordering.
            valueMapping = _(objList)
                .map(_.pairs)
                .flatten(true)
                .groupBy(_.first)
                .transform((result, value, key) ->
                    result[key] = _.map(value, _.last)
                )
                .valueOf()
            keys = _.keys valueMapping
            values = _.unzip(_.values valueMapping)
            # Shortcut definition
            quote = _.bindKey daoFactory.QueryGenerator, "quoteIdentifier"
            # Build up a (?,?,?,...) expression of the right length
            keyFields = "(#{_.times(keys.length, -> "?").join ","})"
            valueFields = _.times(values.length, -> keyFields).join ","
            # Build our query
            return daoFactory.daoFactoryManager.sequelize.query(
                "REPLACE INTO #{quote daoFactory.tableName} #{keyFields} " +
                    "VALUES #{valueFields}",
                null,
                {type: "replace", raw: true},
                keys.concat(_.flatten values, true)
            ).done callback
    sqlite:
        # For compatibility with MySQL, the parser allows the use of the single
        # keyword REPLACE as an alias for "INSERT OR REPLACE".
        replace: (args...) -> queryFactories.mysql.replace args...
    postgres:
        replace: ->
            # This'll be kinda hairy. We'll just not support Postgres for now.
            throw new Error "REPLACE not implemented in Postgres yet"

module.exports = (daoFactory) ->
    # Seriously? What the hell, sequelize?
    dialect = daoFactory.daoFactoryManager.sequelize.options.dialect
    # Build functions for the passed daoFactory
    operations = queryFactories[dialect]
    return _.transform operations, (result, value, key) ->
        result[key] = _.bind value, operations, daoFactory
