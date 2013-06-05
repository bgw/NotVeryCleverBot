_ = require "underscore"
_s = require "underscore.string"
winston = require "winston"
require "js-yaml"
config = require("../config.yaml").logging

winston.exitOnError = false

# Transports
# ----------

# Remove the default console transport
winston.remove winston.transports.Console

defaults = level: "info"

for transport in config
    if _.isString transport
        type = transport
        opts = {}
    else
        type = transport.type || "console"
        opts = _.clone transport
        delete opts.type

    # Apply defaults
    _.defaults opts,
        level: "info"
        handleExceptions: true
    if type is "console"
        _.defaults opts,
            colorize: true
            prettyPrint: true

    winston.add winston.transports[_s.capitalize type], opts

module.exports = winston
