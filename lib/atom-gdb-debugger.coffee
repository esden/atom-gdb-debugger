GdbMiView = require './gdb-mi-view'
{CompositeDisposable} = require 'atom'
GDB = require './gdb'
DebugPanelView = require './debug-panel-view'
ConfigView = require './config-view'
Resizable = require './resizable'
GdbCliView = require './gdb-cli-view'
EditorIntegration = require './editor-integration'

openInPane = (view) ->
    pane = atom.workspace.getActivePane()
    pane.addItem view
    pane.activateItem view

module.exports = AtomGdbDebugger =
    subscriptions: null
    gdb: null

    activate: (state) ->
        @gdb = new GDB(state)
        window.gdb = @gdb
        for k, v of state.gdbConfig
            @gdb.config[k] = v
        @gdb.config.cwd = atom.project.getPaths()[0]
        @panelVisible = state.panelVisible
        @panelVisible ?= true
        @cliVisible = state.cliVisible

        @cliPanel = atom.workspace.addBottomPanel
            item: new Resizable 'top', state.cliSize or 150, new GdbCliView(@gdb)
            visible: false

        @panel = atom.workspace.addRightPanel
            item: new Resizable 'left', state.panelSize or 300, new DebugPanelView(@gdb)
            visible: false

        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable

        @subscriptions.add atom.commands.add 'atom-workspace',
            'atom-gdb-debugger:configure': => new ConfigView(@gdb)
            'atom-gdb-debugger:connect': => @connect()
            'atom-gdb-debugger:continue': => @cmdWrap => @gdb.exec.continue()
            'atom-gdb-debugger:step': => @cmdWrap => @gdb.exec.step()
            'atom-gdb-debugger:next': => @cmdWrap => @gdb.exec.next()
            'atom-gdb-debugger:finish': => @cmdWrap => @gdb.exec.finish()
            'atom-gdb-debugger:interrupt': => @cmdWrap => @gdb.exec.interrupt()
            'atom-gdb-debugger:toggle-panel': => @toggle(@panel, 'panelVisible')
            'atom-gdb-debugger:toggle-cli': => @toggle(@cliPanel, 'cliVisible')
            'atom-gdb-debugger:open-mi-log': => openInPane new GdbMiView(@gdb)

        @editorIntegration = new EditorIntegration(@gdb)

    cmdWrap: (cmd) ->
        cmd()
            .catch (err) =>
                atom.notifications.addError err.toString()

    connect: ->
        if @gdb.config.file == ''
            new ConfigView(@gdb)
        else
            @gdb.connect()
                .then =>
                    if @panelVisible then @panel.show()
                    if @cliVisible then @cliPanel.show()
                .catch (err) =>
                    x = atom.notifications.addError 'Error launching GDB',
                        description: err.toString()
                        buttons: [
                            text: 'Reconfigure'
                            onDidClick: =>
                                x.dismiss()
                                new ConfigView(@gdb)
                        ]

    consumeStatusBar: (statusBar) ->
        StatusView = require './status-view'
        @statusBarTile = statusBar.addLeftTile
            item: new StatusView(@gdb)
            priority: 100

    serialize: ->
          gdbConfig: @gdb.config
          panelVisible: @panelVisible
          cliVisible: @cliVisible
          panelSize: @panel.getItem().size()
          cliSize: @cliPanel.getItem().size()

    deactivate: ->
        @statusBarTile?.destroy()
        @statusBarTile = null
        @gdb.disconnect()
        @panel.destroy()
        @subscriptions.dispose()
        @atomGdbDebuggerView.destroy()

    toggle: (panel, visibleFlag) ->
        if panel.isVisible()
            panel.hide()
        else
            panel.show()
        this[visibleFlag] = panel.isVisible()
