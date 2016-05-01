# setup extend YAML `require` parser
require './util/extend'
{Decoder, Encoder} = require 'cbor'
net = require 'net'
config = require './etc/Kodiak'
logger = require('./util/logger')()

serviceRouter = koaRouter()
  .prefix "#{config.api_prefix}/#{config.version}/service"

  .get "/:serviceName", (next) ->
    # query API
    {serviceName} = @params.serviceName
    packet =
      target: 'service'
      command: 'query'
      args: {serviceName}
    generator = new Generator
    @packet = generator.generate().pack packet
    next()
  , forward

  .post "/", ->
    # registry API
    packet =
      target: 'service'
      command: 'registry'
      args: @body
    generator = new Generator
    @packet = generator.generate().pack packet
    next()
  , forward

  # .delete "/:serviceName", ->
  #   # delete API
  #   {serviceName} = @params.serviceName
  #   packet =
  #     target: 'service'
  #     command: 'delete'
  #     args: {serviceName}
  #   generator = new Generator
  #   @packet = generator.generate().pack packet
  #   next()
  # , forward

  .put "/:serviceName", ->
    # modify API
    @body.serviceName = @params.serviceName
    packet =
      target: 'service'
      command: 'modify'
      args: @body
    generator = new Generator
    @packet = generator.generate().pack packet
    next()
  , forward

pluginRouter = koaRouter()
  .prefix "#{config.api_prefix}/#{config.version}/plugin"

  .post "/", ->
    packet =
      target: 'plugin'
      command: 'registry'
      args: @body
    generator = new Generator
    @packet = generator.generate().pack packet
    next()
  , forward

  .put '/:pluginName', ->
    @body.pluginName = @params.pluginName
    packet =
      target: 'plugin'
      command: 'modify'
      args: @body
    generator = new Generator
    @packet = generator.generate().pack packet
    next()
  , forward

forward = (packet) ->
  socket = net.connect config.sock
  socket.on 'error', (err) ->
  socket.on 'end', ->
  socket.on 'close', ->
  socket.on 'connect', ->
    ds = new Decoder()
    es = new Encoder()
    es.pipe socket
      .pipe ds
      .on 'data', (packet) ->
        # res
    es.write packet

proxy = koa()
proxy.use serviceRouter.routes()
proxy.use pluginRouter.routes()
proxy.listen config.port, ->
  logger.info "[worker]", 'server start listen to:', config.port

process.on 'SIGINT', ->
process.on "SIGTERM", ->
  logger.warn "[worker]", "got signal: SIGTERM"
  process.exit 0
# handle signal - SIGXXX
# process.on 'SIGTERM',
