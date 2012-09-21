path = require 'path'
fs =   require 'fs'

wrench = require 'wrench'
_ =      require 'lodash'

requireRegister =  require '../../require/register'
fileUtils =        require '../../../util/file'
logger =           require '../../../util/logger'
AbstractCompiler = require '../compiler'

module.exports = class AbstractTemplateCompiler extends AbstractCompiler

  template:true

  constructor: (config) ->
    super(config)
    jsDir = path.join @compDir, config.watch.javascriptDir
    @templateFileName = if config.template.outputFileName[@constructor.base]
      path.join(jsDir, config.template.outputFileName[@constructor.base] + ".js")
    else
      path.join(jsDir, config.template.outputFileName + ".js")

    if @clientLibrary?
      @mimosaClientLibraryPath = path.join __dirname, "client", "#{@clientLibrary}.js"
      @clientPath = path.join jsDir, 'vendor', "#{@clientLibrary}.js"

    @notifyOnSuccess = config.growl.onSuccess.template

  # OVERRIDE THIS
  compile: (fileNames, callback) ->
    throw new Error "Method compile(fileNames, callback) must be implemented"

  created: (fileName) =>
    if @startupFinished then @_gatherFiles() else @done()

  updated: =>
    @_gatherFiles()

  removed: (fileName) =>
    @_gatherFiles true

  doneStartup: ->
    @_gatherFiles()

  _gatherFiles: (isRemove = false) ->
    logger.debug "Gathering files for templates"
    fileNames = []
    allFiles = wrench.readdirSyncRecursive(@srcDir)
      .map (file) => path.join(@srcDir, file)

    for file in allFiles
      extension = path.extname(file).substring(1)
      fileNames.push(file) if @extensions.indexOf(extension) >= 0

    if fileNames.length is 0
      if isRemove
        logger.debug "No template files left, removing [[ #{@templateFileName} ]]"
        @removeClientLibrary()
    else
      @_testForSameTemplateName(fileNames)
      @_writeClientLibrary =>
        if @_templateNeedsCompiling fileNames
          @constructor::done = =>
            @_reportStartupDone() if !@startupFinished
          @compile fileNames, @_write
        else
          @_reportStartupDone()

  _testForSameTemplateName: (fileNames) ->
    templateHash = {}
    for fileName in fileNames
      templateName = path.basename(fileName, path.extname(fileName))
      if templateHash[templateName]?
        logger.error "Files [[ #{templateHash[templateName]} ]] and [[ #{fileName} ]] result in templates of the same name " +
                     "being created.  You will want to change the name for one of them or they will collide."
      else
        templateHash[templateName] = fileName

  _templateNeedsCompiling: (fileNames) ->
    for file in fileNames
      if @fileNeedsCompiling(file, @templateFileName)
        logger.debug "Template file [[ #{@templateFileName} ]] needs compiling"
        return true

    logger.debug "Template file [[ #{@templateFileName} ]] does not need compiling"
    false

  _reportStartupDone: =>
    unless @startupFinished
      @startupDoneCallback()
      @startupFinished = true

  removeClientLibrary: ->
    if @clientPath? and fs.existsSync @clientPath
      logger.debug "Removing client library [[ #{@clientPath} ]]"
      fs.unlink @clientPath

  _writeClientLibrary: (callback) ->
    if @config.virgin or !@clientPath? or fs.existsSync @clientPath
      logger.debug "Not going to write template client library"
      return callback()

    logger.debug "Writing template client library [[ #{@mimosaClientLibraryPath} ]]"
    fs.readFile @mimosaClientLibraryPath, "ascii", (err, data) =>
      if err?
        logger.error("Cannot read client library: #{@mimosaClientLibraryPath}") if err?
        return callback()

      fileUtils.writeFile @clientPath, data, (err) =>
        @failed("Cannot write client library: #{err}") if err?
        callback()

  libraryPath: ->
    libPath = "vendor/#{@clientLibrary}"
    requireRegister.aliasForPath(libPath) ? libPath

  templatePreamble: (fileName, templateName) ->
    """
    \n//
    // Source file: [#{fileName}]
    // Template name: [#{templateName}]
    //\n
    """

  addTemplateToOutput: (fileName, templateName, source) =>
    """
    #{@templatePreamble(fileName, templateName)}
    templates['#{templateName}'] = #{source};\n
    """