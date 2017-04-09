Model = require "model"
Postmaster = require "postmaster"
FileIO = require "../os/file-io"

module.exports = (opts={}) ->
  {Window} = system.UI

  {height, menuBar, src, title, width, sandbox, pkg} = opts

  frame = document.createElement "iframe"

  if sandbox
    frame.setAttribute("sandbox", sandbox)

  if src
    frame.src = src
  else if pkg
    # TODO: Use pkg remote dependencies
    frame.src = URL.createObjectURL new Blob ["""
      <html>
        <head>
          <meta charset="utf-8">
        </head>
        <body>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/coffee-script/1.7.1/coffee-script.min.js"><\/script>
        <script>
          var ZINEOS = #{JSON.stringify system.version()};
          #{require.executePackageWrapper(pkg)}
        <\/script>
        </body>
      </html>
    """], type: "text/html; charset=utf-8"

  # Keep track of waiting for child window to load, all remote invocations are
  # queued behind a promise until the child has loaded
  # May want to move it into the postmaster library
  resolveLoaded = null
  loadedPromise = new Promise (resolve) ->
    resolveLoaded = resolve

  # Attach a postmaster to receive events from the child frame
  postmaster = Postmaster()
  postmaster.remoteTarget = -> frame.contentWindow
  Object.assign postmaster,
    childLoaded: ->
      console.log "child loaded"
      resolveLoaded()

    # Send events from the iframe app to the application
    event: ->
      application.trigger "event", arguments...

      return

    # Add application method access to client iFrame
    application: (method, args...) ->
      application[method](args...)

    # Add system method access to client iFrame
    # TODO: Security :P
    system: (method, args...) ->
      system[method](args...)

    exit: ->
      application.element.remove()

  # TODO: Extend with passed in handlers?
  handlers = Model().include(FileIO).extend
    loadFile: (blob) ->
      loadedPromise.then ->
        postmaster.invokeRemote "loadFile", blob

  application = Window
    title: title
    content: frame
    menuBar: menuBar?.element
    width: width
    height: height

  application.loadFile = handlers.loadFile

  return application
