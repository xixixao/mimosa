jslint = require('jshint').JSHINT
_ =      require 'lodash'

logger =  require '../../util/logger'

class JSLinter

  lifecycleRegistration: (config) ->
    extensions = if config.lint.copied.javascript and config.lint.compiled.javascript
      logger.debug "Linting compiled/copied JavaScript only"
      config.extensions.javascript
    else if config.lint.copied.javascript
      logger.debug "Linting copied JavaScript only"
      ['js']
    else if config.lint.compiled.javascript
      logger.debug "Linting compiled JavaScript only"
      _.filter config.extensions.javascript, (ext) -> ext isnt 'js'
    else
      logger.debug "JavaScript linting is entirely turned off"
      []

    return [] if extensions.length is 0

    @options = config.lint.rules.javascript

    [
      {types:['startup','add','update']
      step:'afterCompile'
      callback: @_lint
      extensions:[extensions...]}
    ]

  _lint: (config, options, next) =>
    if !config.lint.vendor.javascript and options.isVendor
      logger.debug "Not linting vendor script [[ #{options.inputName} ]]"
    else
      lintok = jslint options.fileContent, @options
      unless lintok
        for e in jslint.errors
          continue unless e?
          @log options.inputFile, e.reason, e.line

    next()

  log: (fileName, message, lineNumber) ->
    message = "JavaScript Lint Error: #{message}, in file [[ #{fileName} ]]"
    if lineNumber then message += ", at line number [[ #{lineNumber} ]]"
    logger.warn message

module.exports = new JSLinter()