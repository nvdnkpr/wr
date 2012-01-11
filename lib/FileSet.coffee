#-------------------------------------------------------------------------------
# Copyright (c) 2012 Patrick Mueller
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#-------------------------------------------------------------------------------

fs           = require 'fs'
path         = require 'path'
childProcess = require 'child_process'

charm        = require 'charm'

#-------------------------------------------------------------------------------
module.exports = class FileSet

    #---------------------------------------------------------------------------
    constructor: (@files) ->
        @allFiles     = []
        @watchers     = []
        @chimeTimeout = null

    #---------------------------------------------------------------------------
    whenChangedRun: (@cmd, @opts) ->
        @opts.logError   = (->) if !@opts.logError
        @opts.logSuccess = (->) if !@opts.logSuccess
        @opts.logInfo    = (->) if !@opts.logInfo

        @expandFiles()
        if @allFiles.length == 0
            @logError "no files found to watch"
            return

        @chime()
        @watchFiles()

    #---------------------------------------------------------------------------
    fileChanged: () ->
        @clearWatchers()
        @runCommand()

    #---------------------------------------------------------------------------
    chime:  ->
        @logInfo "watching #{@allFiles.length} files, running '#{@cmd}'"
        @resetChime()

    #---------------------------------------------------------------------------
    resetChime: ->
        return if !@opts.chime

        clearTimeout(@chimeTimeout) if @chimeTimeout

        @chimeTimeout = setTimeout(
            => @chime(),
            1000 * 60 * @opts.chime
        )

    #---------------------------------------------------------------------------
    runCommand:  ->
        @opts.logInfo "running '#{@cmd}'"

        cb = (error, stdout, stderr) =>
            if not @opts.stdoutcolor
                process.stdout.write(stdout)
            else
                charm(process.stdout)
                    .push(true)
                    .foreground(@opts.stdoutcolor)
                    .write(stdout)
                    .pop(true)


            if not @opts.stderrcolor
                process.stderr.write(stderr)
            else
                charm(process.stderr)
                    .push(true)
                    .foreground(@opts.stderrcolor)
                    .write(stderr)
                    .pop(true)

            if error
                @logError   "command failed with rc:#{error.code}"
            else
                @logSuccess "command succeeded"

            @expandFiles()

            if @allFiles.length == 0
                @opts.logError("no files found to watch")
                return

            @watchFiles()
            @resetChime()

        childProcess.exec(@cmd, cb)

    #---------------------------------------------------------------------------
    expandFiles: ->
        @allFiles = []

        for file in @files
            @expandFile(file)

    #---------------------------------------------------------------------------
    expandFile: (fileName) ->
        if !path.existsSync(fileName)
            @opts.logError("File not found '#{fileName}'")
            return

        stats = fs.statSync(fileName)

        if stats.isFile()
            @allFiles.push(fileName)

        else if stats.isDirectory()
            @allFiles.push(fileName)

            entries = fs.readdirSync(fileName)

            for entry in entries
                @expandFile path.join(fileName, entry)


    #---------------------------------------------------------------------------
    watchFiles:  ->
        fileChanged = => @fileChanged()
        for file in @allFiles
            watcher = fs.watch(file, {persist: true}, fileChanged)
            @watchers.push(watcher)

    #---------------------------------------------------------------------------
    clearWatchers: () ->
        for watcher in @watchers
            watcher.close()

        @watchers = []

    #---------------------------------------------------------------------------
    logSuccess: (message) ->
        @opts.logSuccess message

    #---------------------------------------------------------------------------
    logError: (message) ->
        @opts.logError message

    #---------------------------------------------------------------------------
    logInfo: (message) ->
        @opts.logInfo message

    #---------------------------------------------------------------------------
    logVerbose: (message) ->
        return if not @opts.verbose

        @opts.logInfo message
